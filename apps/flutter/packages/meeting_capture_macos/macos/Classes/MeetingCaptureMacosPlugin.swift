import AVFoundation
import CoreGraphics
import FlutterMacOS
import Foundation
import ScreenCaptureKit

/// Native macOS handler for the shared meeting-capture channels.
/// `probe`/`requestPermission` are real; the capture round-trip (SCStream system
/// audio + microphone → AAC/M4A) is a FIRST ATTEMPT and must be validated on a
/// real macOS 15+ host — see task #1280 (marked NEEDS-DEVICE-VALIDATION).
public class MeetingCaptureMacosPlugin: NSObject, FlutterPlugin {
  static let backendId = "macos-screencapturekit"
  private static let methodChannelName = "matome.meeting_capture/methods"
  private static let eventChannelPrefix = "matome.meeting_capture/events/"

  private let messenger: FlutterBinaryMessenger
  private var sessions: [String: MeetingCaptureSession] = [:]
  private var eventChannels: [String: FlutterEventChannel] = [:]
  private var eventHandlers: [String: MeetingEventStreamHandler] = [:]

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger)
    let instance = MeetingCaptureMacosPlugin(messenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "probe":
      probe(result: result)
    case "requestPermission":
      requestPermission(result: result)
    case "start":
      start(args: args, result: result)
    case "stop":
      stop(args: args, result: result)
    case "cancel", "dispose":
      cancel(args: args, result: result)
    case "inspect":
      // TODO(#1280) NEEDS-DEVICE-VALIDATION: validate the artifact with AVAsset
      // (codec == AAC, sample rate/channels, duration, byte size) + a decode
      // pass. Skeleton returns not-implemented for now.
      result(FlutterError(
        code: "unimplemented",
        message: "inspect not implemented on macOS yet (#1280)",
        details: nil))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func probe(result: @escaping FlutterResult) {
    let screenOk = CGPreflightScreenCaptureAccess()
    let micOk = AVCaptureDevice.default(for: .audio) != nil
    var map: [String: Any] = ["backendId": Self.backendId]
    if screenOk && micOk {
      map["supported"] = true
    } else {
      map["supported"] = false
      map["reason"] =
        !screenOk ? "screen-recording-permission-required" : "microphone-unavailable"
    }
    result(map)
  }

  private func requestPermission(result: @escaping FlutterResult) {
    AVCaptureDevice.requestAccess(for: .audio) { micGranted in
      // Prompts for Screen Recording if not yet granted; returns current state.
      let screenGranted = CGRequestScreenCaptureAccess()
      let permission = (micGranted && screenGranted) ? "granted" : "denied"
      DispatchQueue.main.async { result(["permission": permission]) }
    }
  }

  private func start(args: [String: Any], result: @escaping FlutterResult) {
    guard let sessionId = args["sessionId"] as? String,
      let stagingPath = args["stagingPath"] as? String
    else {
      result(FlutterError(
        code: "bad-args", message: "sessionId and stagingPath are required",
        details: nil))
      return
    }
    if sessions[sessionId] != nil {
      result(FlutterError(
        code: "already-active", message: "session already recording",
        details: nil))
      return
    }

    let handler = MeetingEventStreamHandler()
    let channel = FlutterEventChannel(
      name: Self.eventChannelPrefix + sessionId, binaryMessenger: messenger)
    channel.setStreamHandler(handler)
    eventChannels[sessionId] = channel
    eventHandlers[sessionId] = handler

    let request = MeetingCaptureRequest(
      sessionId: sessionId,
      stagingPath: stagingPath,
      sampleRate: args["sampleRate"] as? Int ?? 48000,
      channels: args["channels"] as? Int ?? 1,
      bitrate: args["bitrate"] as? Int ?? 96000,
      micGainDb: args["micGainDb"] as? Double ?? -6,
      systemGainDb: args["systemGainDb"] as? Double ?? -6,
      limiterCeilingDb: args["limiterCeilingDb"] as? Double ?? -1)

    let session = MeetingCaptureSession(request: request, events: handler)
    do {
      try session.start()
      sessions[sessionId] = session
      result(nil)
    } catch {
      handler.send(["type": "failed", "message": "\(error)"])
      eventChannels.removeValue(forKey: sessionId)
      eventHandlers.removeValue(forKey: sessionId)
      result(FlutterError(
        code: "start-failed", message: "\(error)", details: nil))
    }
  }

  private func stop(args: [String: Any], result: @escaping FlutterResult) {
    guard let sessionId = args["sessionId"] as? String,
      let session = sessions[sessionId]
    else {
      result(FlutterError(code: "no-session", message: "no active session", details: nil))
      return
    }
    let path = session.stop()
    teardown(sessionId)
    result(["path": path])
  }

  private func cancel(args: [String: Any], result: @escaping FlutterResult) {
    if let sessionId = args["sessionId"] as? String,
      let session = sessions[sessionId]
    {
      session.cancel()
      teardown(sessionId)
    }
    result(nil)
  }

  private func teardown(_ sessionId: String) {
    sessions.removeValue(forKey: sessionId)
    eventChannels.removeValue(forKey: sessionId)
    eventHandlers.removeValue(forKey: sessionId)
  }
}

/// Parameters parsed from the Dart `start` request.
struct MeetingCaptureRequest {
  let sessionId: String
  let stagingPath: String
  let sampleRate: Int
  let channels: Int
  let bitrate: Int
  let micGainDb: Double
  let systemGainDb: Double
  let limiterCeilingDb: Double
}

/// One meeting capture. FIRST ATTEMPT — SCStream system-audio + microphone
/// capture and the AVAssetWriter AAC/M4A encode are TODO. See task #1280.
final class MeetingCaptureSession {
  private let request: MeetingCaptureRequest
  private let events: MeetingEventStreamHandler

  init(request: MeetingCaptureRequest, events: MeetingEventStreamHandler) {
    self.request = request
    self.events = events
  }

  func start() throws {
    // TODO(#1280) NEEDS-DEVICE-VALIDATION:
    //  1. SCShareableContent.getWithCompletionHandler to pick a display.
    //  2. SCStreamConfiguration with capturesAudio = true (system audio).
    //  3. SCStream(filter:configuration:delegate:) + addStreamOutput(.audio).
    //  4. AVCaptureSession / AVAudioEngine tap for the microphone.
    //  5. Mix (system/mic gain + limiter) and encode to AAC-LC M4A via
    //     AVAssetWriter at request.bitrate/sampleRate/channels → stagingPath.
    //  6. Emit per-source level events + device-loss handling.
    // Skeleton only emits the recording state so the channel contract works.
    events.send(["type": "state", "state": "recording"])
  }

  func stop() -> String {
    // TODO(#1280): finalize the AVAssetWriter so the M4A is playable.
    events.send(["type": "state", "state": "completed"])
    return request.stagingPath
  }

  func cancel() {
    // TODO(#1280): tear down SCStream/mic; keep partial artifact recoverable.
    events.send(["type": "state", "state": "cancelled"])
  }
}
