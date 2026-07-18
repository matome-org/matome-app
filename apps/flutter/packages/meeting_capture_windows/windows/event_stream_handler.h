#ifndef FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_EVENT_STREAM_HANDLER_H_
#define FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_EVENT_STREAM_HANDLER_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>

#include <memory>

namespace meeting_capture_windows {

// Minimal reusable StreamHandler that caches the active sink so native capture
// code can push state/level/failure events onto the per-session EventChannel.
// (Same pattern as record_windows/event_stream_handler.h.)
template <typename T = flutter::EncodableValue>
class EventStreamHandler : public flutter::StreamHandler<T> {
 public:
  EventStreamHandler() = default;
  virtual ~EventStreamHandler() = default;

  void Success(std::unique_ptr<T> data) {
    if (sink_ && data) {
      sink_->Success(*data);
    }
  }

  void Error(const std::string& error_code, const std::string& error_message,
             std::unique_ptr<T> error_details = nullptr) {
    if (sink_) {
      sink_->Error(error_code, error_message,
                   error_details ? *error_details : T());
    }
  }

 protected:
  std::unique_ptr<flutter::StreamHandlerError<T>> OnListenInternal(
      const T* /*arguments*/,
      std::unique_ptr<flutter::EventSink<T>>&& events) override {
    sink_ = std::move(events);
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<T>> OnCancelInternal(
      const T* /*arguments*/) override {
    sink_.reset();
    return nullptr;
  }

 private:
  std::unique_ptr<flutter::EventSink<T>> sink_;
};

}  // namespace meeting_capture_windows

#endif  // FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_EVENT_STREAM_HANDLER_H_
