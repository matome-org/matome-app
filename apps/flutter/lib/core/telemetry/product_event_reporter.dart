// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:dio/dio.dart';

import '../http/api_client.dart';
import '../settings/settings_store.dart';

abstract final class ProductEventKey {
  static const captureCompleted = 'product.capture_completed.v1';
  static const localSpaceAggregate = 'product.local_space_aggregate.v1';
  static const matomeAdded = 'product.matome_added.v1';
  static const matomeRemoved = 'product.matome_removed.v1';
  static const matomeArchived = 'product.matome_archived.v1';
}

enum ProductEventResult {
  recorded,
  disabled,
  skippedConsent,
  skippedLocalSpace,
  invalidPayload,
  dropped,
}

/// Best-effort path for explicitly opted-in, cataloged product events.
///
/// Event identity and payload policy are duplicated here only as an egress
/// guard; Core remains authoritative. Matome ids and user content are never
/// accepted by this client surface.
class ProductEventReporter {
  ProductEventReporter({
    required ApiClient apiClient,
    required SettingsStore settingsStore,
  }) : _apiClient = apiClient,
       _settingsStore = settingsStore;

  static const optInSettingKey = 'matome.product_events_opt_in';

  static const _payloadKeys = <String, Set<String>>{
    ProductEventKey.captureCompleted: {
      'input_kind',
      'duration_bucket',
      'size_bucket',
      'platform',
      'result',
    },
    ProductEventKey.localSpaceAggregate: {
      'period',
      'item_count_bucket',
      'byte_size_bucket',
      'platform',
    },
    ProductEventKey.matomeAdded: {},
    ProductEventKey.matomeRemoved: {},
    ProductEventKey.matomeArchived: {},
  };

  final ApiClient _apiClient;
  final SettingsStore _settingsStore;

  Future<void> setOptedIn(bool optedIn) {
    return _settingsStore.write(optInSettingKey, optedIn.toString());
  }

  Future<ProductEventResult> record(
    String catalogKey, {
    Map<String, Object?> payload = const {},
    required bool localSpace,
  }) async {
    String? consent;
    try {
      consent = await _settingsStore.read(optInSettingKey);
    } on Object {
      return ProductEventResult.dropped;
    }
    if (consent != 'true') {
      return ProductEventResult.skippedConsent;
    }
    if (localSpace && catalogKey != ProductEventKey.localSpaceAggregate) {
      return ProductEventResult.skippedLocalSpace;
    }
    if (!_validPayload(catalogKey, payload)) {
      return ProductEventResult.invalidPayload;
    }

    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/events',
        data: <String, Object?>{
          'catalog_key': catalogKey,
          'opted_in': true,
          'payload': payload,
        },
      );

      return switch (response.statusCode) {
        201 => ProductEventResult.recorded,
        202 => ProductEventResult.disabled,
        _ => ProductEventResult.dropped,
      };
    } on DioException {
      return ProductEventResult.dropped;
    }
  }

  bool _validPayload(String catalogKey, Map<String, Object?> payload) {
    final allowed = _payloadKeys[catalogKey];
    if (allowed == null || !payload.keys.every(allowed.contains)) return false;
    if (!payload.values.every(_boundedScalar)) return false;

    try {
      return utf8.encode(jsonEncode(payload)).length <= 4096;
    } on JsonUnsupportedObjectError {
      return false;
    }
  }

  bool _boundedScalar(Object? value) {
    if (value == null || value is bool || value is num) return true;
    if (value is String) return utf8.encode(value).length <= 512;
    if (value is List && value.length <= 50) {
      return value.every(_boundedScalar);
    }
    return false;
  }
}
