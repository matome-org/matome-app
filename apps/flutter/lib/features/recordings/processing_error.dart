import '../../i18n/strings.g.dart';

/// Persisted processing failures are deliberately limited to these app-owned
/// codes. Raw backend reasons and exception text are log-only.
const String kProcessingErrorUploadFailed = 'upload_failed';
const String kProcessingErrorFailed = 'processing_failed';
const String kProcessingErrorTimeout = 'processing_timeout';

const Set<String> kProcessingErrorCodes = <String>{
  kProcessingErrorUploadFailed,
  kProcessingErrorFailed,
  kProcessingErrorTimeout,
};

String processingErrorCodeForTerminal(String? reason) {
  return switch (reason) {
    'timeout' || 'asr_timeout' => kProcessingErrorTimeout,
    _ => kProcessingErrorFailed,
  };
}

String normalizeProcessingErrorCode(String? code) {
  return kProcessingErrorCodes.contains(code) ? code! : kProcessingErrorFailed;
}

String processingErrorMessage(String? code) {
  return switch (code) {
    kProcessingErrorTimeout => t.cardStatus.processingTimedOut,
    kProcessingErrorFailed => t.cardStatus.processingFailed,
    _ => t.cardStatus.failed,
  };
}
