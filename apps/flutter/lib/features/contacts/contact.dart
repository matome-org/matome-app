import 'dart:convert';

import '../../core/http/json_utils.dart';
import '../../core/observability/app_log.dart';

/// A user's Contact, per the `/api/contacts` contract (.docs/internal/architecture.md §11 (D4), task #1377).
///
/// Hand-written with tolerant parsing: only `id`, `owner_id` and `display_name`
/// are treated as required; everything else is nullable because Core may emit
/// nulls. `metadata` is the raw JSON blob the local store persists verbatim.
class Contact {
  const Contact({
    required this.id,
    required this.ownerId,
    required this.displayName,
    this.email,
    this.phone,
    this.company,
    this.title,
    this.metadata,
    this.linkedUserId,
    this.insertedAt,
    this.updatedAt,
  });

  /// Remote (Core) numeric id — the value reconciled into `contacts.core_id`.
  final int id;

  /// Owner user id as Core reports it (numeric stringified).
  final String ownerId;
  final String displayName;

  /// Structured contact fields (#1462). Validated/normalized Core-side on
  /// write; nullable because Core may emit nulls.
  final String? email;
  final String? phone;
  final String? company;
  final String? title;

  /// Raw JSON metadata blob (notes/etc.), persisted verbatim locally.
  final String? metadata;
  final String? linkedUserId;
  final DateTime? insertedAt;
  final DateTime? updatedAt;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: asInt(json['id']),
      ownerId: asString(json['owner_id']),
      displayName: asString(json['display_name']),
      email: asStringOrNull(json['email']),
      phone: asStringOrNull(json['phone']),
      company: asStringOrNull(json['company']),
      title: asStringOrNull(json['title']),
      metadata: _metadataAsString(json['metadata']),
      linkedUserId: asStringOrNull(json['linked_user_id']),
      insertedAt: asDateTimeOrNull(json['inserted_at']),
      updatedAt: asDateTimeOrNull(json['updated_at']),
    );
  }

  /// Parses the `{ "contacts": [...] }` envelope into a typed list.
  static List<Contact> listFromEnvelope(Map<String, dynamic> json) {
    final raw = json['contacts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Contact.fromJson)
        .toList(growable: false);
  }
}

/// Core may return `metadata` either as a JSON object (decoded by Dio) or as an
/// already-stringified blob. The local `contacts.metadata` column is a TEXT
/// blob, so normalise to a string; a null/absent metadata becomes null (the
/// upsert then leaves the column at its `{}` default for a fresh row).
String? _metadataAsString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  // A decoded JSON object/array — re-encode so the TEXT column stores valid JSON
  // (a bare `toString()` of a Map is not parseable JSON).
  try {
    return jsonEncode(value);
  } catch (e, st) {
    AppLog.error(LogCat.error, 'contact metadata re-encode failed', e, st);
    return value.toString();
  }
}
