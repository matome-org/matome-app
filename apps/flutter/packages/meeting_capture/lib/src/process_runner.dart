import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Bounded external-process runner shared by the app composition root, the
/// platform capture implementations, and the live e2e. It escalates
/// SIGTERM→SIGKILL on timeout and caps captured output, so a wedged or noisy
/// child process can never hang the caller or exhaust memory.
class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

typedef CommandRunner =
    Future<CommandResult> Function(String executable, List<String> arguments);

Future<CommandResult> defaultCommandRunner(
  String executable,
  List<String> arguments,
) => runBoundedCommand(executable, arguments);

Future<CommandResult> runBoundedCommand(
  String executable,
  List<String> arguments, {
  Duration timeout = const Duration(seconds: 2),
  Duration terminationGrace = const Duration(seconds: 1),
  int outputLimit = 64 * 1024,
}) async {
  final process = await Process.start(executable, arguments);
  final stdout = _BoundedOutput(outputLimit);
  final stderr = _BoundedOutput(outputLimit);
  final stdoutDone = process.stdout.listen(stdout.add).asFuture<void>();
  final stderrDone = process.stderr.listen(stderr.add).asFuture<void>();
  int? exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    try {
      exitCode = await process.exitCode.timeout(terminationGrace);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      try {
        exitCode = await process.exitCode.timeout(terminationGrace);
      } on TimeoutException {
        throw TimeoutException('$executable did not terminate', timeout);
      }
    }
    throw TimeoutException('$executable timed out', timeout);
  } finally {
    try {
      await Future.wait([stdoutDone, stderrDone]).timeout(terminationGrace);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }
  return CommandResult(
    exitCode: exitCode,
    stdout: stdout.text,
    stderr: stderr.text,
  );
}

class _BoundedOutput {
  _BoundedOutput(this.limit);

  final int limit;
  final List<int> _bytes = [];

  void add(List<int> chunk) {
    final remaining = limit - _bytes.length;
    if (remaining <= 0) return;
    _bytes.addAll(chunk.take(remaining));
  }

  String get text => utf8.decode(_bytes, allowMalformed: true);
}
