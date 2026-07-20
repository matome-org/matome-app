import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../http/api_client.dart';
import '../settings/settings_store.dart';

const String systemPolicyCacheKey = 'matome.system_policy.v1';

class SystemPolicyValidationException implements Exception {
  const SystemPolicyValidationException(this.rejectedKeys);

  final List<String> rejectedKeys;

  @override
  String toString() => 'Invalid system policy: ${rejectedKeys.join(', ')}';
}

class SystemPolicy {
  const SystemPolicy._({
    required this.revision,
    required this.queuePaused,
    required this.desiredObanConcurrency,
    required this.leaseDuration,
    required this.reportingInterval,
    required this.maxAttempts,
    required this.baseRetryDelay,
    required this.maxRetryDelay,
    required this.singleUploadMaxBytes,
    required this.multipartPartBytes,
    required this.maxUploadBytes,
    required this.enabledInputKinds,
    required this.processingTimeout,
    required this.minimumWireVersion,
    required this.pollInterval,
    required this.appliedRevision,
    required this._document,
  });

  factory SystemPolicy.parse(Map<String, dynamic> document) {
    final validation = _PolicyValidation(document)..validate();
    if (validation.errors.isNotEmpty) {
      throw SystemPolicyValidationException(validation.errors);
    }

    final desired = document['desired'] as Map<String, dynamic>;
    final queue = desired['queue'] as Map<String, dynamic>;
    final retry = desired['retry'] as Map<String, dynamic>;
    final uploads = desired['uploads'] as Map<String, dynamic>;
    final ai = desired['ai'] as Map<String, dynamic>;
    final clients = desired['clients'] as Map<String, dynamic>;
    final applied = document['applied'] as Map<String, dynamic>;

    return SystemPolicy._(
      revision: document['revision'] as int,
      queuePaused: queue['paused'] as bool,
      desiredObanConcurrency: queue['max_concurrency'] as int,
      leaseDuration: Duration(seconds: queue['lease_seconds'] as int),
      reportingInterval: Duration(
        seconds: queue['snapshot_interval_seconds'] as int,
      ),
      maxAttempts: retry['max_attempts'] as int,
      baseRetryDelay: Duration(seconds: retry['base_delay_seconds'] as int),
      maxRetryDelay: Duration(seconds: retry['max_delay_seconds'] as int),
      singleUploadMaxBytes: uploads['single_max_bytes'] as int,
      multipartPartBytes: uploads['multipart_part_bytes'] as int,
      maxUploadBytes: uploads['max_bytes'] as int,
      enabledInputKinds: Set<String>.unmodifiable(
        (ai['enabled_input_kinds'] as List<dynamic>).cast<String>(),
      ),
      processingTimeout: Duration(seconds: ai['job_timeout_seconds'] as int),
      minimumWireVersion: clients['minimum_wire_version'] as String,
      pollInterval: Duration(seconds: clients['poll_interval_seconds'] as int),
      appliedRevision: applied['core_revision'] as int,
      document: _copyMap(document),
    );
  }

  static final SystemPolicy fallback = SystemPolicy._(
    revision: 0,
    queuePaused: false,
    desiredObanConcurrency: 2,
    leaseDuration: const Duration(seconds: 120),
    reportingInterval: const Duration(minutes: 15),
    maxAttempts: 5,
    baseRetryDelay: const Duration(seconds: 2),
    maxRetryDelay: const Duration(minutes: 5),
    singleUploadMaxBytes: 25 * 1024 * 1024,
    multipartPartBytes: 16 * 1024 * 1024,
    maxUploadBytes: 2 * 1024 * 1024 * 1024,
    enabledInputKinds: const {'audio', 'image', 'document', 'text'},
    processingTimeout: const Duration(minutes: 30),
    minimumWireVersion: '1',
    pollInterval: const Duration(seconds: 2),
    appliedRevision: 0,
    document: const <String, dynamic>{},
  );

  final int revision;
  final bool queuePaused;
  final int desiredObanConcurrency;
  final Duration leaseDuration;
  final Duration reportingInterval;
  final int maxAttempts;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final int singleUploadMaxBytes;
  final int multipartPartBytes;
  final int maxUploadBytes;
  final Set<String> enabledInputKinds;
  final Duration processingTimeout;
  final String minimumWireVersion;
  final Duration pollInterval;
  final int appliedRevision;
  final Map<String, dynamic> _document;

  Map<String, dynamic> toJson() => _copyMap(_document);
}

class SystemPolicyController extends StateNotifier<SystemPolicy> {
  SystemPolicyController(ApiClient apiClient, this._settingsStore)
    : _apiClientReader = (() => apiClient),
      super(SystemPolicy.fallback);

  SystemPolicyController.reading(this._apiClientReader, this._settingsStore)
    : super(SystemPolicy.fallback);

  final ApiClient Function() _apiClientReader;
  final SettingsStore _settingsStore;
  Future<void>? _initializing;

  Future<void> initialize() => _initializing ??= hydrate().then((_) {
    unawaited(refresh());
  });

  Future<void> hydrate() async {
    try {
      final cached = await _settingsStore.read(systemPolicyCacheKey);
      if (cached == null) return;
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) return;
      final accepted = SystemPolicy.parse(decoded);
      if (accepted.revision >= state.revision) state = accepted;
    } on Object {
      // An invalid/unavailable cache is ignored; safe fallback policy remains.
    }
  }

  Future<bool> refresh() async {
    try {
      final response = await _apiClientReader().dio.get<dynamic>(
        '/api/system-config',
      );
      if (response.statusCode != 200 || response.data is! Map) return false;

      final envelope = Map<String, dynamic>.from(response.data as Map);
      if (envelope['contract_version'] != '1' || envelope['config'] is! Map) {
        return false;
      }

      final raw = Map<String, dynamic>.from(envelope['config'] as Map);
      late final SystemPolicy accepted;
      try {
        accepted = SystemPolicy.parse(raw);
      } on SystemPolicyValidationException catch (error) {
        await _reportApplication(state.revision, error.rejectedKeys);
        return false;
      }

      if (accepted.revision < state.revision) {
        await _reportApplication(state.revision, const ['revision']);
        return false;
      }

      await _settingsStore.write(
        systemPolicyCacheKey,
        jsonEncode(accepted.toJson()),
      );
      state = accepted;
      await _reportApplication(accepted.revision, const []);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _reportApplication(
    int appliedRevision,
    List<String> rejectedKeys,
  ) async {
    try {
      await _apiClientReader().dio.post<void>(
        '/api/system-config/application',
        data: <String, dynamic>{
          'contract_version': '1',
          'applied_revision': appliedRevision,
          'rejected_keys': rejectedKeys,
        },
      );
    } on Object {
      // Reporting is best effort and never invalidates an accepted policy.
    }
  }
}

class _PolicyValidation {
  _PolicyValidation(this.document);

  static const _inputKinds = {'audio', 'image', 'document', 'text'};

  final Map<String, dynamic> document;
  final List<String> errors = [];

  void validate() {
    _exact(document, '', const {
      'schema_version',
      'revision',
      'desired',
      'applied',
    });
    _equal('schema_version', 1);
    _integer('revision', 1);

    final desired = _map('desired');
    _exact(desired, 'desired', const {
      'queue',
      'retry',
      'uploads',
      'ai',
      'clients',
    });

    final queue = _map('desired.queue');
    _exact(queue, 'desired.queue', const {
      'paused',
      'lease_seconds',
      'max_concurrency',
      'snapshot_interval_seconds',
    });
    _boolean('desired.queue.paused');
    _integer('desired.queue.lease_seconds', 15, 3600);
    _integer('desired.queue.max_concurrency', 1, 16);
    _integer('desired.queue.snapshot_interval_seconds', 60, 86400);

    final retry = _map('desired.retry');
    _exact(retry, 'desired.retry', const {
      'max_attempts',
      'base_delay_seconds',
      'max_delay_seconds',
    });
    _integer('desired.retry.max_attempts', 1, 20);
    _integer('desired.retry.base_delay_seconds', 1, 3600);
    _integer('desired.retry.max_delay_seconds', 1, 86400);
    _ordered(
      'desired.retry.base_delay_seconds',
      'desired.retry.max_delay_seconds',
    );

    final uploads = _map('desired.uploads');
    _exact(uploads, 'desired.uploads', const {
      'single_max_bytes',
      'multipart_part_bytes',
      'max_bytes',
    });
    _integer('desired.uploads.single_max_bytes', 1, 2147483648);
    _integer('desired.uploads.multipart_part_bytes', 5242880, 536870912);
    _integer('desired.uploads.max_bytes', 5242880, 2147483648);
    _ordered('desired.uploads.single_max_bytes', 'desired.uploads.max_bytes');
    _ordered(
      'desired.uploads.multipart_part_bytes',
      'desired.uploads.max_bytes',
    );

    final ai = _map('desired.ai');
    _exact(ai, 'desired.ai', const {
      'enabled_input_kinds',
      'job_timeout_seconds',
    });
    final kinds = _value('desired.ai.enabled_input_kinds');
    if (kinds is! List ||
        kinds.any((kind) => kind is! String || !_inputKinds.contains(kind)) ||
        kinds.toSet().length != kinds.length) {
      errors.add('desired.ai.enabled_input_kinds');
    }
    _integer('desired.ai.job_timeout_seconds', 30, 86400);

    final clients = _map('desired.clients');
    _exact(clients, 'desired.clients', const {
      'minimum_wire_version',
      'poll_interval_seconds',
    });
    final wireVersion = _value('desired.clients.minimum_wire_version');
    if (wireVersion is! String ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(wireVersion)) {
      errors.add('desired.clients.minimum_wire_version');
    }
    _integer('desired.clients.poll_interval_seconds', 1, 3600);

    final applied = _map('applied');
    _exact(applied, 'applied', const {'core_revision', 'core_applied_at'});
    _integer('applied.core_revision', 0);
    _ordered('applied.core_revision', 'revision');
    final appliedAt = _value('applied.core_applied_at');
    if (appliedAt != null &&
        (appliedAt is! String || DateTime.tryParse(appliedAt) == null)) {
      errors.add('applied.core_applied_at');
    }

    final unique = errors.toSet().toList()..sort();
    errors
      ..clear()
      ..addAll(unique);
  }

  void _exact(Map<String, dynamic>? value, String path, Set<String> expected) {
    if (value == null) {
      errors.add(path);
      return;
    }
    for (final key in value.keys.toSet().difference(expected)) {
      errors.add(path.isEmpty ? key : '$path.$key');
    }
    for (final key in expected.difference(value.keys.toSet())) {
      errors.add(path.isEmpty ? key : '$path.$key');
    }
  }

  Map<String, dynamic>? _map(String path) {
    final value = _value(path);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  void _equal(String path, Object expected) {
    if (_value(path) != expected) errors.add(path);
  }

  void _boolean(String path) {
    if (_value(path) is! bool) errors.add(path);
  }

  void _integer(String path, int minimum, [int? maximum]) {
    final value = _value(path);
    if (value is! int ||
        value < minimum ||
        (maximum != null && value > maximum)) {
      errors.add(path);
    }
  }

  void _ordered(String lowerPath, String upperPath) {
    final lower = _value(lowerPath);
    final upper = _value(upperPath);
    if (lower is int && upper is int && lower > upper) errors.add(lowerPath);
  }

  Object? _value(String path) {
    Object? value = document;
    for (final key in path.split('.')) {
      if (value is! Map) return null;
      value = value[key];
    }
    return value;
  }
}

Map<String, dynamic> _copyMap(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
