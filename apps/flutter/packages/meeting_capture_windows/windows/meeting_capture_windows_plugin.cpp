#include "meeting_capture_windows_plugin.h"

// Windows / Core Audio (WASAPI) + Media Foundation.
#include <windows.h>
// clang-format off
#include <audioclient.h>
#include <mmdeviceapi.h>
// clang-format on

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>
#include <optional>
#include <string>
#include <thread>

namespace meeting_capture_windows {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

const char kMethodChannelName[] = "matome.meeting_capture/methods";
const char kEventChannelPrefix[] = "matome.meeting_capture/events/";
const char kBackendId[] = "windows-wasapi";

// Small helpers to read typed args out of the StandardMethodCodec map.
std::optional<std::string> GetString(const EncodableMap& args,
                                     const char* key) {
  auto it = args.find(EncodableValue(std::string(key)));
  if (it == args.end()) return std::nullopt;
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::nullopt;
}

std::optional<int> GetInt(const EncodableMap& args, const char* key) {
  auto it = args.find(EncodableValue(std::string(key)));
  if (it == args.end()) return std::nullopt;
  if (const auto* value = std::get_if<int>(&it->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*value);
  }
  return std::nullopt;
}

double GetDouble(const EncodableMap& args, const char* key, double fallback) {
  auto it = args.find(EncodableValue(std::string(key)));
  if (it == args.end()) return fallback;
  if (const auto* value = std::get_if<double>(&it->second)) return *value;
  if (const auto* value = std::get_if<int>(&it->second)) return *value;
  return fallback;
}

EncodableValue StateEvent(const char* state) {
  return EncodableValue(EncodableMap{
      {EncodableValue("type"), EncodableValue("state")},
      {EncodableValue("state"), EncodableValue(std::string(state))},
  });
}

EncodableValue FailedEvent(const std::string& message) {
  return EncodableValue(EncodableMap{
      {EncodableValue("type"), EncodableValue("failed")},
      {EncodableValue("message"), EncodableValue(message)},
  });
}

}  // namespace

// Parameters parsed from the Dart `start` request.
struct CaptureRequest {
  std::string session_id;
  std::string staging_path;
  int sample_rate = 48000;
  int channels = 1;
  int bitrate = 96000;
  double mic_gain_db = -6;
  double system_gain_db = -6;
  double limiter_ceiling_db = -1;
};

// One meeting capture on a dedicated worker thread. FIRST ATTEMPT — the WASAPI
// activation is sketched but the sample pump + AAC/M4A encode are TODO and MUST
// be validated on a real Windows host. See task #1279.
class CaptureSession {
 public:
  CaptureSession(CaptureRequest request,
                 EventStreamHandler<EncodableValue>* events)
      : request_(std::move(request)), events_(events) {}

  ~CaptureSession() { Cancel(); }

  // Returns an error string on failure, std::nullopt on success.
  std::optional<std::string> Start() {
    // TODO(#1279) NEEDS-DEVICE-VALIDATION:
    //  1. CoCreateInstance(IMMDeviceEnumerator).
    //  2. GetDefaultAudioEndpoint(eRender)  -> IAudioClient in loopback mode
    //     (AUDCLNT_STREAMFLAGS_LOOPBACK) for system audio.
    //  3. GetDefaultAudioEndpoint(eCapture) -> IAudioClient for the microphone.
    //  4. Event-driven (AUDCLNT_STREAMFLAGS_EVENTCALLBACK) capture on an MTA
    //     worker thread; resample both to request_.sample_rate/channels.
    //  5. Apply system/mic gain + limiter (limiter_ceiling_db) and mix.
    //  6. Encode to AAC-LC in an MP4/M4A container via Media Foundation
    //     (IMFSinkWriter) at request_.bitrate, writing request_.staging_path.
    //  7. Emit per-source level events and detect device loss.
    // The skeleton below only manages lifecycle + state events so the channel
    // contract is exercisable; it does NOT yet record audio.
    running_ = true;
    worker_ = std::thread([this] { Run(); });
    return std::nullopt;
  }

  // Graceful stop; returns the artifact path.
  std::string Stop() {
    running_ = false;
    if (worker_.joinable()) worker_.join();
    // TODO(#1279): finalize the IMFSinkWriter so the M4A is playable.
    return request_.staging_path;
  }

  void Cancel() {
    running_ = false;
    if (worker_.joinable()) worker_.join();
    // TODO(#1279): drop the partial artifact only when finalization is unknown.
  }

 private:
  void Run() {
    if (events_) events_->Success(std::make_unique<EncodableValue>(
                     StateEvent("recording")));
    // TODO(#1279): real WASAPI capture loop here. Placeholder keeps the worker
    // alive until Stop()/Cancel() flips `running_`.
    while (running_.load()) {
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
  }

  CaptureRequest request_;
  EventStreamHandler<EncodableValue>* events_;  // owned by the plugin
  std::thread worker_;
  std::atomic<bool> running_{false};
};

// static
void MeetingCaptureWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<MeetingCaptureWindowsPlugin>(registrar);

  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kMethodChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

MeetingCaptureWindowsPlugin::MeetingCaptureWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

MeetingCaptureWindowsPlugin::~MeetingCaptureWindowsPlugin() = default;

flutter::EncodableValue MeetingCaptureWindowsPlugin::Probe() {
  bool supported = false;
  std::string reason = "audio-endpoints-unavailable";

  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool com_initialized = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;

  IMMDeviceEnumerator* enumerator = nullptr;
  if (SUCCEEDED(CoCreateInstance(
          __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
          __uuidof(IMMDeviceEnumerator),
          reinterpret_cast<void**>(&enumerator)))) {
    IMMDevice* render = nullptr;
    IMMDevice* capture = nullptr;
    const bool have_render = SUCCEEDED(enumerator->GetDefaultAudioEndpoint(
        eRender, eConsole, &render));
    const bool have_capture = SUCCEEDED(enumerator->GetDefaultAudioEndpoint(
        eCapture, eConsole, &capture));
    if (have_render && have_capture) {
      supported = true;
      reason.clear();
    } else if (!have_render) {
      reason = "system-endpoint-unavailable";
    } else {
      reason = "microphone-unavailable";
    }
    if (render) render->Release();
    if (capture) capture->Release();
    enumerator->Release();
  } else {
    reason = "core-audio-unavailable";
  }
  if (com_initialized && hr != RPC_E_CHANGED_MODE) CoUninitialize();

  EncodableMap map{
      {EncodableValue("supported"), EncodableValue(supported)},
      {EncodableValue("backendId"), EncodableValue(std::string(kBackendId))},
  };
  if (!supported) {
    map[EncodableValue("reason")] = EncodableValue(reason);
  }
  return EncodableValue(map);
}

void MeetingCaptureWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto& method = method_call.method_name();
  const auto* args = std::get_if<EncodableMap>(method_call.arguments());
  const EncodableMap empty;
  const EncodableMap& a = args ? *args : empty;

  if (method == "probe") {
    result->Success(Probe());
    return;
  }
  if (method == "requestPermission") {
    // Win32 desktop capture has no runtime microphone prompt; treat as granted.
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("permission"), EncodableValue("granted")}}));
    return;
  }
  if (method == "start") {
    auto session_id = GetString(a, "sessionId");
    auto staging = GetString(a, "stagingPath");
    if (!session_id || !staging) {
      result->Error("bad-args", "sessionId and stagingPath are required");
      return;
    }
    if (sessions_.count(*session_id)) {
      result->Error("already-active", "session already recording");
      return;
    }
    // Per-session EventChannel for state/level/failure.
    auto handler = new EventStreamHandler<EncodableValue>();
    auto event_channel =
        std::make_unique<flutter::EventChannel<EncodableValue>>(
            registrar_->messenger(),
            std::string(kEventChannelPrefix) + *session_id,
            &flutter::StandardMethodCodec::GetInstance());
    event_channel->SetStreamHandler(
        std::unique_ptr<flutter::StreamHandler<EncodableValue>>(handler));
    event_handlers_[*session_id] = handler;
    event_channels_[*session_id] = std::move(event_channel);

    CaptureRequest request;
    request.session_id = *session_id;
    request.staging_path = *staging;
    request.sample_rate = GetInt(a, "sampleRate").value_or(48000);
    request.channels = GetInt(a, "channels").value_or(1);
    request.bitrate = GetInt(a, "bitrate").value_or(96000);
    request.mic_gain_db = GetDouble(a, "micGainDb", -6);
    request.system_gain_db = GetDouble(a, "systemGainDb", -6);
    request.limiter_ceiling_db = GetDouble(a, "limiterCeilingDb", -1);

    auto session = std::make_unique<CaptureSession>(std::move(request), handler);
    auto error = session->Start();
    if (error) {
      handler->Success(std::make_unique<EncodableValue>(FailedEvent(*error)));
      event_channels_.erase(*session_id);
      event_handlers_.erase(*session_id);
      result->Error("start-failed", *error);
      return;
    }
    sessions_[*session_id] = std::move(session);
    result->Success();
    return;
  }
  if (method == "stop") {
    auto session_id = GetString(a, "sessionId");
    if (!session_id || !sessions_.count(*session_id)) {
      result->Error("no-session", "no active session");
      return;
    }
    std::string path = sessions_[*session_id]->Stop();
    sessions_.erase(*session_id);
    event_channels_.erase(*session_id);
    event_handlers_.erase(*session_id);
    result->Success(EncodableValue(
        EncodableMap{{EncodableValue("path"), EncodableValue(path)}}));
    return;
  }
  if (method == "cancel" || method == "dispose") {
    auto session_id = GetString(a, "sessionId");
    if (session_id && sessions_.count(*session_id)) {
      sessions_[*session_id]->Cancel();
      sessions_.erase(*session_id);
      event_channels_.erase(*session_id);
      event_handlers_.erase(*session_id);
    }
    result->Success();
    return;
  }
  if (method == "inspect") {
    // TODO(#1279) NEEDS-DEVICE-VALIDATION: validate the artifact with an
    // IMFSourceReader (codec == AAC, sample rate/channels, duration, byte size)
    // and full decode. Skeleton returns a not-implemented error for now.
    result->Error("unimplemented",
                  "inspect not implemented on Windows yet (#1279)");
    return;
  }

  result->NotImplemented();
}

}  // namespace meeting_capture_windows
