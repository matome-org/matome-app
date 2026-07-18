import '../../core/http/json_utils.dart';

/// Core's closed processing lifecycle for the current logical run.
enum ProcessingState {
  notRequested('not_requested'),
  notAvailable('not_available'),
  queued('queued'),
  processing('processing'),
  succeeded('succeeded'),
  partial('partial'),
  failed('failed'),
  unknown('unknown');

  const ProcessingState(this.wireName);

  final String wireName;

  static ProcessingState fromWire(Object? value) {
    final name = asStringOrNull(value);
    return ProcessingState.values.firstWhere(
      (state) => state.wireName == name,
      orElse: () => ProcessingState.unknown,
    );
  }

  bool get isInFlight => this == queued || this == processing;

  bool get isTerminal =>
      this == notAvailable ||
      this == succeeded ||
      this == partial ||
      this == failed;

  bool get hasCurrentRun => this != notRequested && this != unknown;
}

enum ProcessingOutputKind {
  transcript('transcript'),
  summary('summary'),
  title('title'),
  description('description'),
  ocrText('ocr_text'),
  extractedText('extracted_text');

  const ProcessingOutputKind(this.wireName);

  final String wireName;

  static ProcessingOutputKind? fromWire(Object? value) {
    final name = asStringOrNull(value);
    for (final kind in values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}

sealed class ProcessingOutput {
  const ProcessingOutput(this.kind);

  final ProcessingOutputKind kind;
  Map<String, dynamic> toJson();
}

class TextProcessingOutput extends ProcessingOutput {
  const TextProcessingOutput({
    required ProcessingOutputKind kind,
    required this.text,
    this.language,
    this.durationMs,
  }) : super(kind);

  final String text;
  final String? language;
  final int? durationMs;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': kind.wireName,
    'text': text,
    if (language != null) 'language': language,
    if (durationMs != null) 'duration_ms': durationMs,
  };
}

class SummaryProcessingOutput extends ProcessingOutput {
  const SummaryProcessingOutput({required this.markdown})
    : super(ProcessingOutputKind.summary);

  final String markdown;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': kind.wireName,
    'markdown': markdown,
  };
}

/// Closed, typed projection of Core's output-kind keyed map.
class ProcessingOutputs {
  const ProcessingOutputs._(this._values);
  const ProcessingOutputs.empty() : _values = const {};

  final Map<ProcessingOutputKind, ProcessingOutput> _values;

  factory ProcessingOutputs.fromJson(Object? value) {
    if (value is! Map) return const ProcessingOutputs.empty();
    final outputs = <ProcessingOutputKind, ProcessingOutput>{};
    for (final entry in value.entries) {
      final kind = ProcessingOutputKind.fromWire(entry.key);
      final payload = entry.value;
      if (kind == null || payload is! Map) continue;
      if (ProcessingOutputKind.fromWire(payload['type']) != kind) continue;
      if (kind == ProcessingOutputKind.summary) {
        final markdown = asStringOrNull(payload['markdown']);
        if (markdown != null && markdown.isNotEmpty) {
          outputs[kind] = SummaryProcessingOutput(markdown: markdown);
        }
        continue;
      }
      final text = asStringOrNull(payload['text']);
      if (text == null || text.isEmpty) continue;
      outputs[kind] = TextProcessingOutput(
        kind: kind,
        text: text,
        language: asStringOrNull(payload['language']),
        durationMs: asIntOrNull(payload['duration_ms']),
      );
    }
    return ProcessingOutputs._(Map.unmodifiable(outputs));
  }

  TextProcessingOutput? get transcript =>
      _values[ProcessingOutputKind.transcript] as TextProcessingOutput?;
  SummaryProcessingOutput? get summary =>
      _values[ProcessingOutputKind.summary] as SummaryProcessingOutput?;
  TextProcessingOutput? get title =>
      _values[ProcessingOutputKind.title] as TextProcessingOutput?;
  TextProcessingOutput? get description =>
      _values[ProcessingOutputKind.description] as TextProcessingOutput?;
  TextProcessingOutput? get ocrText =>
      _values[ProcessingOutputKind.ocrText] as TextProcessingOutput?;
  TextProcessingOutput? get extractedText =>
      _values[ProcessingOutputKind.extractedText] as TextProcessingOutput?;

  bool get isEmpty => _values.isEmpty;
  Iterable<ProcessingOutputKind> get kinds => _values.keys;

  Map<String, dynamic> toJson() => <String, dynamic>{
    for (final entry in _values.entries)
      entry.key.wireName: entry.value.toJson(),
  };
}

class ProcessingFailure {
  const ProcessingFailure({required this.code, required this.retryable});

  final String code;
  final bool retryable;

  factory ProcessingFailure.fromJson(Object? value) {
    if (value is! Map) {
      return const ProcessingFailure(
        code: 'processing_failed',
        retryable: true,
      );
    }
    return ProcessingFailure(
      code: asStringOrNull(value['code']) ?? 'processing_failed',
      retryable: value['retryable'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'retryable': retryable,
  };
}

class ItemProcessing {
  const ItemProcessing({
    required this.state,
    required this.runId,
    required this.attempt,
    required this.requestedOutputs,
    required this.outputs,
    this.error,
  });

  const ItemProcessing.notRequested()
    : state = ProcessingState.notRequested,
      runId = null,
      attempt = 0,
      requestedOutputs = const {},
      outputs = const ProcessingOutputs.empty(),
      error = null;

  final ProcessingState state;
  final String? runId;
  final int attempt;
  final Set<ProcessingOutputKind> requestedOutputs;
  final ProcessingOutputs outputs;
  final ProcessingFailure? error;

  bool get isTerminal => state.isTerminal;

  factory ItemProcessing.fromItemJson(Map<String, dynamic> json) {
    final requested = <ProcessingOutputKind>{};
    final rawRequested = json['processing_requested_outputs'];
    if (rawRequested is List) {
      for (final value in rawRequested) {
        final kind = ProcessingOutputKind.fromWire(value);
        if (kind != null) requested.add(kind);
      }
    }
    final state = ProcessingState.fromWire(json['processing_state']);
    return ItemProcessing(
      state: state,
      runId: asStringOrNull(json['processing_run_id']),
      attempt: asIntOrNull(json['processing_attempt']) ?? 0,
      requestedOutputs: Set.unmodifiable(requested),
      outputs: ProcessingOutputs.fromJson(json['processing_outputs']),
      error: state == ProcessingState.failed
          ? ProcessingFailure.fromJson(json['processing_error'])
          : null,
    );
  }
}

/// Legacy progress enum retained for recording-capture progress consumers.
/// Core HTTP parsing and reconciliation use [ItemProcessing] exclusively.
enum RecordingStatus { pending, processing, done, failed, unknown }

/// A Core Item projected into the existing recording/file repository boundary.
class Recording {
  const Recording({
    required this.id,
    required this.ownerId,
    required this.title,
    this.clientId,
    this.itemType = 'file',
    this.sourceRevision = 1,
    this.textBody,
    this.processing = const ItemProcessing.notRequested(),
    this.status = RecordingStatus.unknown,
    this.summary,
    this.transcript,
    this.notes,
    this.mediaType,
    this.filename,
    this.originalExtension,
    this.contentType,
    this.openPolicy,
    this.checksumSha256,
    this.storageKey,
    this.uploadState,
    this.uploadedAt,
    this.errorReason,
    this.duration,
    this.byteSize,
    this.badge,
    this.workspaceId,
    this.matomeId,
    this.insertedAt,
    this.updatedAt,
  });

  final int id;
  final String? ownerId;
  final String title;
  final String? clientId;
  final String itemType;
  final int sourceRevision;
  final String? textBody;
  final ItemProcessing processing;

  /// Capture-progress compatibility only; network code must use [processing].
  final RecordingStatus status;
  final String? summary;
  final String? transcript;
  final String? notes;
  final String? mediaType;
  final String? filename;
  final String? originalExtension;
  final String? contentType;
  final String? openPolicy;
  final String? checksumSha256;
  final String? storageKey;
  final String? uploadState;
  final DateTime? uploadedAt;
  final String? errorReason;
  final int? duration;
  final int? byteSize;
  final String? badge;
  final int? workspaceId;
  final int? matomeId;
  final DateTime? insertedAt;
  final DateTime? updatedAt;

  factory Recording.fromJson(Map<String, dynamic> json) =>
      Recording.fromItemJson(json);

  factory Recording.fromItemJson(Map<String, dynamic> json) {
    final file = json['file'] is Map<String, dynamic>
        ? json['file'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final metadata = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final processing = ItemProcessing.fromItemJson(json);
    return Recording(
      id: asInt(json['id']),
      ownerId: _ownerIdOrNull(json['owner_id']),
      title: asString(json['title'], fallback: 'Untitled'),
      clientId: asStringOrNull(json['client_id']),
      itemType: asString(json['item_type'], fallback: 'file'),
      sourceRevision: asIntOrNull(json['source_revision']) ?? 1,
      textBody: _textBody(json),
      processing: processing,
      status: _legacyStatus(processing.state),
      summary: processing.outputs.summary?.markdown,
      transcript: processing.outputs.transcript?.text,
      notes: asStringOrNull(json['notes']),
      mediaType: asStringOrNull(file['media_type']),
      filename: asStringOrNull(file['filename']),
      originalExtension: asStringOrNull(file['original_extension']),
      contentType: asStringOrNull(file['content_type']),
      openPolicy: asStringOrNull(file['open_policy']),
      checksumSha256: asStringOrNull(file['checksum_sha256']),
      storageKey: asStringOrNull(file['storage_key']),
      uploadState: asStringOrNull(file['upload_state']),
      uploadedAt: asDateTimeOrNull(file['uploaded_at']),
      errorReason: processing.error?.code,
      duration: asIntOrNull(file['duration']),
      byteSize: asIntOrNull(file['byte_size']),
      badge: asStringOrNull(metadata['badge']),
      workspaceId: asIntOrNull(json['workspace_id']),
      matomeId: asIntOrNull(json['matome_id']),
      insertedAt: asDateTimeOrNull(json['inserted_at']),
      updatedAt: asDateTimeOrNull(json['updated_at']),
    );
  }

  static String? _ownerIdOrNull(Object? value) {
    final id = asStringOrNull(value)?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  static String? _textBody(Map<String, dynamic> json) {
    final text = json['text'];
    if (text is Map) return asStringOrNull(text['body']);
    return asStringOrNull(json['body']);
  }

  static RecordingStatus _legacyStatus(ProcessingState state) =>
      switch (state) {
        ProcessingState.queued => RecordingStatus.pending,
        ProcessingState.processing => RecordingStatus.processing,
        ProcessingState.succeeded ||
        ProcessingState.partial => RecordingStatus.done,
        ProcessingState.failed ||
        ProcessingState.notAvailable => RecordingStatus.failed,
        ProcessingState.notRequested ||
        ProcessingState.unknown => RecordingStatus.unknown,
      };

  static List<Recording> listFromEnvelope(Map<String, dynamic> json) {
    final raw = json['recordings'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Recording.fromItemJson)
        .toList(growable: false);
  }

  static List<Recording> listFromItemsEnvelope(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Recording.fromItemJson)
        .toList(growable: false);
  }
}
