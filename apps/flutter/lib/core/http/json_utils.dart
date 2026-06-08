/// Tolerant JSON coercion helpers for hand-written models.
///
/// The lab backend is trusted but fields can be null/absent (e.g. `summary`
/// before processing), and numbers occasionally arrive as strings. These
/// helpers keep model `fromJson` constructors small and forgiving.
library;

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  return value.toString();
}

String asString(Object? value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

int asInt(Object? value, {int fallback = 0}) {
  return asIntOrNull(value) ?? fallback;
}

DateTime? asDateTimeOrNull(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
