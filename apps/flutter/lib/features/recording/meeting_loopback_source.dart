import 'dart:io';

/// Result of running an external command, narrowed to what the loopback
/// resolver needs. Mirrors `ProcessResult` so the production runner is a 1:1
/// delegate while tests inject canned stdout/exit codes (no real `pactl`).
class CommandResult {
  const CommandResult({required this.exitCode, required this.stdout});

  final int exitCode;
  final String stdout;
}

/// Runs an external command and returns its result. Injectable so the
/// PipeWire/Pulse source resolution below is unit-testable without spawning
/// `which` / `pactl`. Mirrors the codebase idiom of `Process.run` +
/// `which fmedia` in [AudioRecordingService].
typedef CommandRunner = Future<CommandResult> Function(
  String executable,
  List<String> arguments,
);

/// Production [CommandRunner] — straight delegate to [Process.run].
Future<CommandResult> defaultCommandRunner(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments);
  return CommandResult(
    exitCode: result.exitCode,
    stdout: (result.stdout as String?) ?? '',
  );
}

/// Resolves the Linux loopback (system-output) capture device for the meeting
/// recorder: the PulseAudio/PipeWire `.monitor` source of the default sink.
///
/// On a PipeWire (or PulseAudio) host every output sink exposes a matching
/// `<sink>.monitor` source that carries exactly what is being played back —
/// this is the loopback tap the meeting recorder mixes with the mic. We resolve
/// it generically (default sink → its monitor) rather than hard-coding a device
/// so it tracks whatever the user has selected as output.
///
/// Everything that touches the host is funnelled through an injected
/// [CommandRunner] so the resolution logic is unit-testable with canned
/// `pactl` output.
///
/// Linux-only by design (MVP). Windows (WASAPI loopback) and macOS (virtual
/// device / ScreenCaptureKit) are out of scope for this increment; the resolver
/// simply reports unavailable off Linux, leaving a clean seam for those backends.
class MeetingLoopbackSource {
  const MeetingLoopbackSource({
    CommandRunner runner = defaultCommandRunner,
    bool Function()? isLinux,
  })  : _run = runner,
        // ignore: prefer_initializing_formals
        _isLinux = isLinux;

  final CommandRunner _run;
  final bool Function()? _isLinux;

  bool get _onLinux {
    final probe = _isLinux;
    if (probe != null) return probe();
    try {
      return Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  /// Whether ffmpeg is on PATH. Same external-dependency probe shape the
  /// service uses for `fmedia` (`which <bin>`, exit 0 ⇒ present).
  Future<bool> hasFfmpeg() async {
    try {
      final result = await _run('which', ['ffmpeg']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Whether `pactl` (PulseAudio/PipeWire control) is on PATH — needed to
  /// resolve the default sink's monitor source.
  Future<bool> hasPactl() async {
    try {
      final result = await _run('which', ['pactl']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Whether the host can do loopback meeting capture: Linux + ffmpeg + pactl +
  /// a resolvable monitor source. Used by the capability gate so the
  /// meeting-recorder entry can disable with a precise reason off-support.
  Future<bool> isSupported() async {
    if (!_onLinux) return false;
    if (!await hasFfmpeg()) return false;
    if (!await hasPactl()) return false;
    return await resolveMonitorSource() != null;
  }

  /// Resolve the default sink's `.monitor` source name, or null when it can't
  /// be determined (no pactl, no default sink, no matching monitor).
  ///
  /// Strategy:
  ///   1. `pactl get-default-sink` → the active output sink name.
  ///   2. `pactl list short sources` → find the `<sink>.monitor` row.
  ///   3. Fallback: any `*.monitor` source (covers exotic naming) so a present
  ///      loopback tap is still usable rather than failing hard.
  Future<String?> resolveMonitorSource() async {
    if (!_onLinux) return null;

    final sources = await _listMonitorSources();
    if (sources.isEmpty) return null;

    final defaultSink = await _defaultSink();
    if (defaultSink != null) {
      final expected = '$defaultSink.monitor';
      if (sources.contains(expected)) return expected;
    }

    // Fallback: first available monitor source (deterministic — pactl lists in
    // a stable index order).
    return sources.first;
  }

  Future<String?> _defaultSink() async {
    try {
      final result = await _run('pactl', ['get-default-sink']);
      if (result.exitCode != 0) return null;
      final name = result.stdout.trim();
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// Parse `pactl list short sources` into the list of `.monitor` source names,
  /// preserving order. Each row is tab-separated: `index\tname\tdriver\t...`.
  Future<List<String>> _listMonitorSources() async {
    try {
      final result = await _run('pactl', ['list', 'short', 'sources']);
      if (result.exitCode != 0) return const [];
      return parseMonitorSources(result.stdout);
    } catch (_) {
      return const [];
    }
  }

  /// Pure parser for `pactl list short sources` output — extracts the source
  /// NAME column (index 1) for every row whose name ends in `.monitor`.
  /// Exposed for unit testing the parse independently of process spawning.
  static List<String> parseMonitorSources(String pactlShortOutput) {
    final names = <String>[];
    for (final line in pactlShortOutput.split('\n')) {
      if (line.trim().isEmpty) continue;
      final cols = line.split('\t');
      if (cols.length < 2) continue;
      final name = cols[1].trim();
      if (name.endsWith('.monitor')) names.add(name);
    }
    return names;
  }
}
