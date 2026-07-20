/// Canonical item type discriminator shared by Core PostgreSQL, OpenAPI, and
/// Flutter Drift sync/listing code.
enum MatomeItemType { file, text }

extension MatomeItemTypeWire on MatomeItemType {
  String get wireName => switch (this) {
    MatomeItemType.file => 'file',
    MatomeItemType.text => 'text',
  };
}

/// Canonical per-type dispatch. Centralises the file/text arc split so every
/// item-type branch lives in THIS file (the boundary-guard-enforced home): a
/// new item type adds one arm here, not a scattered `switch` at each call site.
/// Callers pass a builder per arm and receive the selected result.
R mapMatomeItemType<R>(
  MatomeItemType type, {
  required R Function() file,
  required R Function() text,
}) => switch (type) {
  MatomeItemType.file => file(),
  MatomeItemType.text => text(),
};

MatomeItemType matomeItemTypeFromWire(String value) {
  final type = _byWireName[value];
  if (type == null) {
    throw ArgumentError.value(value, 'value', 'Unknown Matome item type');
  }
  return type;
}

final Map<String, MatomeItemType> _byWireName = {
  for (final type in MatomeItemType.values) type.wireName: type,
};
