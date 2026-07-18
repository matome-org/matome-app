/// Package-neutral meeting-capture facade: the capture contract, the shared
/// bounded process runner, and the federated platform interface. This is the
/// only meeting-capture package the app imports.
library;

export 'src/meeting_capture_backend.dart';
export 'src/meeting_capture_platform.dart';
export 'src/process_runner.dart';
