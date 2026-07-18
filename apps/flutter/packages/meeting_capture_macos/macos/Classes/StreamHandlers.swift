import FlutterMacOS
import Foundation

/// Minimal FlutterStreamHandler that caches the active sink so native capture
/// code can push state/level/failure events onto the per-session EventChannel.
/// (Same pattern as record_macos/StreamHandlers.swift.)
public class MeetingEventStreamHandler: NSObject, FlutterStreamHandler {
  private let lock = NSLock()
  private var sink: FlutterEventSink?

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    lock.lock()
    defer { lock.unlock() }
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    lock.lock()
    defer { lock.unlock() }
    sink = nil
    return nil
  }

  func send(_ event: [String: Any]) {
    lock.lock()
    let current = sink
    lock.unlock()
    guard let current = current else { return }
    DispatchQueue.main.async { current(event) }
  }
}
