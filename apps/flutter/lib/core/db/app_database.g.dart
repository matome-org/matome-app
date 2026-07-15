// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorkspacesTable extends Workspaces
    with TableInfo<$WorkspacesTable, WorkspaceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<int> isDefault = GeneratedColumn<int>(
    'isDefault',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceTypeMeta = const VerificationMeta(
    'spaceType',
  );
  @override
  late final GeneratedColumn<String> spaceType = GeneratedColumn<String>(
    'space_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('personal'),
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLocalMeta = const VerificationMeta(
    'isLocal',
  );
  @override
  late final GeneratedColumn<int> isLocal = GeneratedColumn<int>(
    'is_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isDefault,
    createdAt,
    spaceType,
    ownerId,
    isLocal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('isDefault')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['isDefault']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('space_type')) {
      context.handle(
        _spaceTypeMeta,
        spaceType.isAcceptableOrUnknown(data['space_type']!, _spaceTypeMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('is_local')) {
      context.handle(
        _isLocalMeta,
        isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkspaceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isDefault'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      spaceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_type'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      ),
      isLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_local'],
      )!,
    );
  }

  @override
  $WorkspacesTable createAlias(String alias) {
    return $WorkspacesTable(attachedDatabase, alias);
  }
}

class WorkspaceRow extends DataClass implements Insertable<WorkspaceRow> {
  final String id;
  final String name;
  final int isDefault;
  final int createdAt;
  final String spaceType;
  final String? ownerId;
  final int isLocal;
  const WorkspaceRow({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.spaceType,
    this.ownerId,
    required this.isLocal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['isDefault'] = Variable<int>(isDefault);
    map['createdAt'] = Variable<int>(createdAt);
    map['space_type'] = Variable<String>(spaceType);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    map['is_local'] = Variable<int>(isLocal);
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      name: Value(name),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      spaceType: Value(spaceType),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      isLocal: Value(isLocal),
    );
  }

  factory WorkspaceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isDefault: serializer.fromJson<int>(json['isDefault']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      spaceType: serializer.fromJson<String>(json['spaceType']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      isLocal: serializer.fromJson<int>(json['isLocal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'isDefault': serializer.toJson<int>(isDefault),
      'createdAt': serializer.toJson<int>(createdAt),
      'spaceType': serializer.toJson<String>(spaceType),
      'ownerId': serializer.toJson<String?>(ownerId),
      'isLocal': serializer.toJson<int>(isLocal),
    };
  }

  WorkspaceRow copyWith({
    String? id,
    String? name,
    int? isDefault,
    int? createdAt,
    String? spaceType,
    Value<String?> ownerId = const Value.absent(),
    int? isLocal,
  }) => WorkspaceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    spaceType: spaceType ?? this.spaceType,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
    isLocal: isLocal ?? this.isLocal,
  );
  WorkspaceRow copyWithCompanion(WorkspacesCompanion data) {
    return WorkspaceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      spaceType: data.spaceType.present ? data.spaceType.value : this.spaceType,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('spaceType: $spaceType, ')
          ..write('ownerId: $ownerId, ')
          ..write('isLocal: $isLocal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, isDefault, createdAt, spaceType, ownerId, isLocal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.spaceType == this.spaceType &&
          other.ownerId == this.ownerId &&
          other.isLocal == this.isLocal);
}

class WorkspacesCompanion extends UpdateCompanion<WorkspaceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> isDefault;
  final Value<int> createdAt;
  final Value<String> spaceType;
  final Value<String?> ownerId;
  final Value<int> isLocal;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.spaceType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    required String id,
    required String name,
    this.isDefault = const Value.absent(),
    required int createdAt,
    this.spaceType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<WorkspaceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? isDefault,
    Expression<int>? createdAt,
    Expression<String>? spaceType,
    Expression<String>? ownerId,
    Expression<int>? isLocal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isDefault != null) 'isDefault': isDefault,
      if (createdAt != null) 'createdAt': createdAt,
      if (spaceType != null) 'space_type': spaceType,
      if (ownerId != null) 'owner_id': ownerId,
      if (isLocal != null) 'is_local': isLocal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspacesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? isDefault,
    Value<int>? createdAt,
    Value<String>? spaceType,
    Value<String?>? ownerId,
    Value<int>? isLocal,
    Value<int>? rowid,
  }) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      spaceType: spaceType ?? this.spaceType,
      ownerId: ownerId ?? this.ownerId,
      isLocal: isLocal ?? this.isLocal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDefault.present) {
      map['isDefault'] = Variable<int>(isDefault.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (spaceType.present) {
      map['space_type'] = Variable<String>(spaceType.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<int>(isLocal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('spaceType: $spaceType, ')
          ..write('ownerId: $ownerId, ')
          ..write('isLocal: $isLocal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordingDraftsTable extends RecordingDrafts
    with TableInfo<$RecordingDraftsTable, RecordingDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentsJsonMeta = const VerificationMeta(
    'segmentsJson',
  );
  @override
  late final GeneratedColumn<String> segmentsJson = GeneratedColumn<String>(
    'segments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    segmentsJson,
    durationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recording_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordingDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('segments_json')) {
      context.handle(
        _segmentsJsonMeta,
        segmentsJson.isAcceptableOrUnknown(
          data['segments_json']!,
          _segmentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentsJsonMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordingDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      segmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segments_json'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
    );
  }

  @override
  $RecordingDraftsTable createAlias(String alias) {
    return $RecordingDraftsTable(attachedDatabase, alias);
  }
}

class RecordingDraftRow extends DataClass
    implements Insertable<RecordingDraftRow> {
  final int id;
  final String createdAt;
  final String segmentsJson;
  final int durationMs;
  const RecordingDraftRow({
    required this.id,
    required this.createdAt,
    required this.segmentsJson,
    required this.durationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['segments_json'] = Variable<String>(segmentsJson);
    map['duration_ms'] = Variable<int>(durationMs);
    return map;
  }

  RecordingDraftsCompanion toCompanion(bool nullToAbsent) {
    return RecordingDraftsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      segmentsJson: Value(segmentsJson),
      durationMs: Value(durationMs),
    );
  }

  factory RecordingDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingDraftRow(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      segmentsJson: serializer.fromJson<String>(json['segmentsJson']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'segmentsJson': serializer.toJson<String>(segmentsJson),
      'durationMs': serializer.toJson<int>(durationMs),
    };
  }

  RecordingDraftRow copyWith({
    int? id,
    String? createdAt,
    String? segmentsJson,
    int? durationMs,
  }) => RecordingDraftRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    segmentsJson: segmentsJson ?? this.segmentsJson,
    durationMs: durationMs ?? this.durationMs,
  );
  RecordingDraftRow copyWithCompanion(RecordingDraftsCompanion data) {
    return RecordingDraftRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      segmentsJson: data.segmentsJson.present
          ? data.segmentsJson.value
          : this.segmentsJson,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingDraftRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('segmentsJson: $segmentsJson, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, segmentsJson, durationMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingDraftRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.segmentsJson == this.segmentsJson &&
          other.durationMs == this.durationMs);
}

class RecordingDraftsCompanion extends UpdateCompanion<RecordingDraftRow> {
  final Value<int> id;
  final Value<String> createdAt;
  final Value<String> segmentsJson;
  final Value<int> durationMs;
  const RecordingDraftsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.segmentsJson = const Value.absent(),
    this.durationMs = const Value.absent(),
  });
  RecordingDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String createdAt,
    required String segmentsJson,
    this.durationMs = const Value.absent(),
  }) : createdAt = Value(createdAt),
       segmentsJson = Value(segmentsJson);
  static Insertable<RecordingDraftRow> custom({
    Expression<int>? id,
    Expression<String>? createdAt,
    Expression<String>? segmentsJson,
    Expression<int>? durationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (segmentsJson != null) 'segments_json': segmentsJson,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  RecordingDraftsCompanion copyWith({
    Value<int>? id,
    Value<String>? createdAt,
    Value<String>? segmentsJson,
    Value<int>? durationMs,
  }) {
    return RecordingDraftsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      segmentsJson: segmentsJson ?? this.segmentsJson,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (segmentsJson.present) {
      map['segments_json'] = Variable<String>(segmentsJson.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingDraftsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('segmentsJson: $segmentsJson, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }
}

class $SpaceMembersTable extends SpaceMembers
    with TableInfo<$SpaceMembersTable, SpaceMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpaceMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('member'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, spaceId, userId, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'space_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpaceMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpaceMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpaceMemberRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $SpaceMembersTable createAlias(String alias) {
    return $SpaceMembersTable(attachedDatabase, alias);
  }
}

class SpaceMemberRow extends DataClass implements Insertable<SpaceMemberRow> {
  final String id;
  final String spaceId;
  final String userId;
  final String role;
  const SpaceMemberRow({
    required this.id,
    required this.spaceId,
    required this.userId,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    return map;
  }

  SpaceMembersCompanion toCompanion(bool nullToAbsent) {
    return SpaceMembersCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      userId: Value(userId),
      role: Value(role),
    );
  }

  factory SpaceMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpaceMemberRow(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
    };
  }

  SpaceMemberRow copyWith({
    String? id,
    String? spaceId,
    String? userId,
    String? role,
  }) => SpaceMemberRow(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
  );
  SpaceMemberRow copyWithCompanion(SpaceMembersCompanion data) {
    return SpaceMemberRow(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMemberRow(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('userId: $userId, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, spaceId, userId, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpaceMemberRow &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.userId == this.userId &&
          other.role == this.role);
}

class SpaceMembersCompanion extends UpdateCompanion<SpaceMemberRow> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> userId;
  final Value<String> role;
  final Value<int> rowid;
  const SpaceMembersCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpaceMembersCompanion.insert({
    required String id,
    required String spaceId,
    required String userId,
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       userId = Value(userId);
  static Insertable<SpaceMemberRow> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpaceMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? userId,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return SpaceMembersCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMembersCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrganizationsTable extends Organizations
    with TableInfo<$OrganizationsTable, OrganizationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrganizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'organizations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrganizationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrganizationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrganizationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OrganizationsTable createAlias(String alias) {
    return $OrganizationsTable(attachedDatabase, alias);
  }
}

class OrganizationRow extends DataClass implements Insertable<OrganizationRow> {
  final String id;
  final String name;
  final int createdAt;
  const OrganizationRow({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OrganizationsCompanion toCompanion(bool nullToAbsent) {
    return OrganizationsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory OrganizationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrganizationRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OrganizationRow copyWith({String? id, String? name, int? createdAt}) =>
      OrganizationRow(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  OrganizationRow copyWithCompanion(OrganizationsCompanion data) {
    return OrganizationRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrganizationRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class OrganizationsCompanion extends UpdateCompanion<OrganizationRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> rowid;
  const OrganizationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrganizationsCompanion.insert({
    required String id,
    required String name,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<OrganizationRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrganizationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return OrganizationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatomesTable extends Matomes with TableInfo<$MatomesTable, MatomeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatomesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _happenedAtMeta = const VerificationMeta(
    'happenedAt',
  );
  @override
  late final GeneratedColumn<int> happenedAt = GeneratedColumn<int>(
    'happened_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aggregatedSummaryMeta = const VerificationMeta(
    'aggregatedSummary',
  );
  @override
  late final GeneratedColumn<String> aggregatedSummary =
      GeneratedColumn<String>(
        'aggregated_summary',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _summaryStaleMeta = const VerificationMeta(
    'summaryStale',
  );
  @override
  late final GeneratedColumn<bool> summaryStale = GeneratedColumn<bool>(
    'summary_stale',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("summary_stale" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coreIdMeta = const VerificationMeta('coreId');
  @override
  late final GeneratedColumn<int> coreId = GeneratedColumn<int>(
    'core_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    title,
    happenedAt,
    description,
    aggregatedSummary,
    summaryStale,
    createdAt,
    coreId,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matomes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatomeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('happened_at')) {
      context.handle(
        _happenedAtMeta,
        happenedAt.isAcceptableOrUnknown(data['happened_at']!, _happenedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_happenedAtMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('aggregated_summary')) {
      context.handle(
        _aggregatedSummaryMeta,
        aggregatedSummary.isAcceptableOrUnknown(
          data['aggregated_summary']!,
          _aggregatedSummaryMeta,
        ),
      );
    }
    if (data.containsKey('summary_stale')) {
      context.handle(
        _summaryStaleMeta,
        summaryStale.isAcceptableOrUnknown(
          data['summary_stale']!,
          _summaryStaleMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('core_id')) {
      context.handle(
        _coreIdMeta,
        coreId.isAcceptableOrUnknown(data['core_id']!, _coreIdMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatomeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatomeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      happenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}happened_at'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      aggregatedSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregated_summary'],
      ),
      summaryStale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}summary_stale'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      coreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}core_id'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $MatomesTable createAlias(String alias) {
    return $MatomesTable(attachedDatabase, alias);
  }
}

class MatomeRow extends DataClass implements Insertable<MatomeRow> {
  final String id;
  final String? spaceId;
  final String title;
  final int happenedAt;
  final String? description;
  final String? aggregatedSummary;
  final bool summaryStale;
  final int createdAt;
  final int? coreId;
  final int? archivedAt;
  const MatomeRow({
    required this.id,
    this.spaceId,
    required this.title,
    required this.happenedAt,
    this.description,
    this.aggregatedSummary,
    required this.summaryStale,
    required this.createdAt,
    this.coreId,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || spaceId != null) {
      map['space_id'] = Variable<String>(spaceId);
    }
    map['title'] = Variable<String>(title);
    map['happened_at'] = Variable<int>(happenedAt);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || aggregatedSummary != null) {
      map['aggregated_summary'] = Variable<String>(aggregatedSummary);
    }
    map['summary_stale'] = Variable<bool>(summaryStale);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || coreId != null) {
      map['core_id'] = Variable<int>(coreId);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    return map;
  }

  MatomesCompanion toCompanion(bool nullToAbsent) {
    return MatomesCompanion(
      id: Value(id),
      spaceId: spaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(spaceId),
      title: Value(title),
      happenedAt: Value(happenedAt),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      aggregatedSummary: aggregatedSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(aggregatedSummary),
      summaryStale: Value(summaryStale),
      createdAt: Value(createdAt),
      coreId: coreId == null && nullToAbsent
          ? const Value.absent()
          : Value(coreId),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory MatomeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatomeRow(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String?>(json['spaceId']),
      title: serializer.fromJson<String>(json['title']),
      happenedAt: serializer.fromJson<int>(json['happenedAt']),
      description: serializer.fromJson<String?>(json['description']),
      aggregatedSummary: serializer.fromJson<String?>(
        json['aggregatedSummary'],
      ),
      summaryStale: serializer.fromJson<bool>(json['summaryStale']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      coreId: serializer.fromJson<int?>(json['coreId']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String?>(spaceId),
      'title': serializer.toJson<String>(title),
      'happenedAt': serializer.toJson<int>(happenedAt),
      'description': serializer.toJson<String?>(description),
      'aggregatedSummary': serializer.toJson<String?>(aggregatedSummary),
      'summaryStale': serializer.toJson<bool>(summaryStale),
      'createdAt': serializer.toJson<int>(createdAt),
      'coreId': serializer.toJson<int?>(coreId),
      'archivedAt': serializer.toJson<int?>(archivedAt),
    };
  }

  MatomeRow copyWith({
    String? id,
    Value<String?> spaceId = const Value.absent(),
    String? title,
    int? happenedAt,
    Value<String?> description = const Value.absent(),
    Value<String?> aggregatedSummary = const Value.absent(),
    bool? summaryStale,
    int? createdAt,
    Value<int?> coreId = const Value.absent(),
    Value<int?> archivedAt = const Value.absent(),
  }) => MatomeRow(
    id: id ?? this.id,
    spaceId: spaceId.present ? spaceId.value : this.spaceId,
    title: title ?? this.title,
    happenedAt: happenedAt ?? this.happenedAt,
    description: description.present ? description.value : this.description,
    aggregatedSummary: aggregatedSummary.present
        ? aggregatedSummary.value
        : this.aggregatedSummary,
    summaryStale: summaryStale ?? this.summaryStale,
    createdAt: createdAt ?? this.createdAt,
    coreId: coreId.present ? coreId.value : this.coreId,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  MatomeRow copyWithCompanion(MatomesCompanion data) {
    return MatomeRow(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      title: data.title.present ? data.title.value : this.title,
      happenedAt: data.happenedAt.present
          ? data.happenedAt.value
          : this.happenedAt,
      description: data.description.present
          ? data.description.value
          : this.description,
      aggregatedSummary: data.aggregatedSummary.present
          ? data.aggregatedSummary.value
          : this.aggregatedSummary,
      summaryStale: data.summaryStale.present
          ? data.summaryStale.value
          : this.summaryStale,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatomeRow(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('title: $title, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('description: $description, ')
          ..write('aggregatedSummary: $aggregatedSummary, ')
          ..write('summaryStale: $summaryStale, ')
          ..write('createdAt: $createdAt, ')
          ..write('coreId: $coreId, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    title,
    happenedAt,
    description,
    aggregatedSummary,
    summaryStale,
    createdAt,
    coreId,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatomeRow &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.title == this.title &&
          other.happenedAt == this.happenedAt &&
          other.description == this.description &&
          other.aggregatedSummary == this.aggregatedSummary &&
          other.summaryStale == this.summaryStale &&
          other.createdAt == this.createdAt &&
          other.coreId == this.coreId &&
          other.archivedAt == this.archivedAt);
}

class MatomesCompanion extends UpdateCompanion<MatomeRow> {
  final Value<String> id;
  final Value<String?> spaceId;
  final Value<String> title;
  final Value<int> happenedAt;
  final Value<String?> description;
  final Value<String?> aggregatedSummary;
  final Value<bool> summaryStale;
  final Value<int> createdAt;
  final Value<int?> coreId;
  final Value<int?> archivedAt;
  final Value<int> rowid;
  const MatomesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.title = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.description = const Value.absent(),
    this.aggregatedSummary = const Value.absent(),
    this.summaryStale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.coreId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatomesCompanion.insert({
    required String id,
    this.spaceId = const Value.absent(),
    required String title,
    required int happenedAt,
    this.description = const Value.absent(),
    this.aggregatedSummary = const Value.absent(),
    this.summaryStale = const Value.absent(),
    required int createdAt,
    this.coreId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       happenedAt = Value(happenedAt),
       createdAt = Value(createdAt);
  static Insertable<MatomeRow> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? title,
    Expression<int>? happenedAt,
    Expression<String>? description,
    Expression<String>? aggregatedSummary,
    Expression<bool>? summaryStale,
    Expression<int>? createdAt,
    Expression<int>? coreId,
    Expression<int>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (title != null) 'title': title,
      if (happenedAt != null) 'happened_at': happenedAt,
      if (description != null) 'description': description,
      if (aggregatedSummary != null) 'aggregated_summary': aggregatedSummary,
      if (summaryStale != null) 'summary_stale': summaryStale,
      if (createdAt != null) 'created_at': createdAt,
      if (coreId != null) 'core_id': coreId,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatomesCompanion copyWith({
    Value<String>? id,
    Value<String?>? spaceId,
    Value<String>? title,
    Value<int>? happenedAt,
    Value<String?>? description,
    Value<String?>? aggregatedSummary,
    Value<bool>? summaryStale,
    Value<int>? createdAt,
    Value<int?>? coreId,
    Value<int?>? archivedAt,
    Value<int>? rowid,
  }) {
    return MatomesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      title: title ?? this.title,
      happenedAt: happenedAt ?? this.happenedAt,
      description: description ?? this.description,
      aggregatedSummary: aggregatedSummary ?? this.aggregatedSummary,
      summaryStale: summaryStale ?? this.summaryStale,
      createdAt: createdAt ?? this.createdAt,
      coreId: coreId ?? this.coreId,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (happenedAt.present) {
      map['happened_at'] = Variable<int>(happenedAt.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (aggregatedSummary.present) {
      map['aggregated_summary'] = Variable<String>(aggregatedSummary.value);
    }
    if (summaryStale.present) {
      map['summary_stale'] = Variable<bool>(summaryStale.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (coreId.present) {
      map['core_id'] = Variable<int>(coreId.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatomesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('title: $title, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('description: $description, ')
          ..write('aggregatedSummary: $aggregatedSummary, ')
          ..write('summaryStale: $summaryStale, ')
          ..write('createdAt: $createdAt, ')
          ..write('coreId: $coreId, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts
    with TableInfo<$ContactsTable, ContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _linkedUserIdMeta = const VerificationMeta(
    'linkedUserId',
  );
  @override
  late final GeneratedColumn<String> linkedUserId = GeneratedColumn<String>(
    'linked_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coreIdMeta = const VerificationMeta('coreId');
  @override
  late final GeneratedColumn<int> coreId = GeneratedColumn<int>(
    'core_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    displayName,
    email,
    phone,
    company,
    title,
    metadata,
    linkedUserId,
    createdAt,
    coreId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('linked_user_id')) {
      context.handle(
        _linkedUserIdMeta,
        linkedUserId.isAcceptableOrUnknown(
          data['linked_user_id']!,
          _linkedUserIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('core_id')) {
      context.handle(
        _coreIdMeta,
        coreId.isAcceptableOrUnknown(data['core_id']!, _coreIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      linkedUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_user_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      coreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}core_id'],
      ),
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class ContactRow extends DataClass implements Insertable<ContactRow> {
  final String id;
  final String ownerId;
  final String displayName;
  final String? email;
  final String? phone;
  final String? company;
  final String? title;
  final String metadata;
  final String? linkedUserId;
  final int createdAt;
  final int? coreId;
  const ContactRow({
    required this.id,
    required this.ownerId,
    required this.displayName,
    this.email,
    this.phone,
    this.company,
    this.title,
    required this.metadata,
    this.linkedUserId,
    required this.createdAt,
    this.coreId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || company != null) {
      map['company'] = Variable<String>(company);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['metadata'] = Variable<String>(metadata);
    if (!nullToAbsent || linkedUserId != null) {
      map['linked_user_id'] = Variable<String>(linkedUserId);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || coreId != null) {
      map['core_id'] = Variable<int>(coreId);
    }
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      displayName: Value(displayName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      company: company == null && nullToAbsent
          ? const Value.absent()
          : Value(company),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      metadata: Value(metadata),
      linkedUserId: linkedUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedUserId),
      createdAt: Value(createdAt),
      coreId: coreId == null && nullToAbsent
          ? const Value.absent()
          : Value(coreId),
    );
  }

  factory ContactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactRow(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      company: serializer.fromJson<String?>(json['company']),
      title: serializer.fromJson<String?>(json['title']),
      metadata: serializer.fromJson<String>(json['metadata']),
      linkedUserId: serializer.fromJson<String?>(json['linkedUserId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      coreId: serializer.fromJson<int?>(json['coreId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'displayName': serializer.toJson<String>(displayName),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'company': serializer.toJson<String?>(company),
      'title': serializer.toJson<String?>(title),
      'metadata': serializer.toJson<String>(metadata),
      'linkedUserId': serializer.toJson<String?>(linkedUserId),
      'createdAt': serializer.toJson<int>(createdAt),
      'coreId': serializer.toJson<int?>(coreId),
    };
  }

  ContactRow copyWith({
    String? id,
    String? ownerId,
    String? displayName,
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> company = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? metadata,
    Value<String?> linkedUserId = const Value.absent(),
    int? createdAt,
    Value<int?> coreId = const Value.absent(),
  }) => ContactRow(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    displayName: displayName ?? this.displayName,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    company: company.present ? company.value : this.company,
    title: title.present ? title.value : this.title,
    metadata: metadata ?? this.metadata,
    linkedUserId: linkedUserId.present ? linkedUserId.value : this.linkedUserId,
    createdAt: createdAt ?? this.createdAt,
    coreId: coreId.present ? coreId.value : this.coreId,
  );
  ContactRow copyWithCompanion(ContactsCompanion data) {
    return ContactRow(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      company: data.company.present ? data.company.value : this.company,
      title: data.title.present ? data.title.value : this.title,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      linkedUserId: data.linkedUserId.present
          ? data.linkedUserId.value
          : this.linkedUserId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactRow(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('company: $company, ')
          ..write('title: $title, ')
          ..write('metadata: $metadata, ')
          ..write('linkedUserId: $linkedUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('coreId: $coreId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    displayName,
    email,
    phone,
    company,
    title,
    metadata,
    linkedUserId,
    createdAt,
    coreId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactRow &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.displayName == this.displayName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.company == this.company &&
          other.title == this.title &&
          other.metadata == this.metadata &&
          other.linkedUserId == this.linkedUserId &&
          other.createdAt == this.createdAt &&
          other.coreId == this.coreId);
}

class ContactsCompanion extends UpdateCompanion<ContactRow> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> displayName;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> company;
  final Value<String?> title;
  final Value<String> metadata;
  final Value<String?> linkedUserId;
  final Value<int> createdAt;
  final Value<int?> coreId;
  final Value<int> rowid;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.company = const Value.absent(),
    this.title = const Value.absent(),
    this.metadata = const Value.absent(),
    this.linkedUserId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.coreId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String id,
    required String ownerId,
    required String displayName,
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.company = const Value.absent(),
    this.title = const Value.absent(),
    this.metadata = const Value.absent(),
    this.linkedUserId = const Value.absent(),
    required int createdAt,
    this.coreId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       displayName = Value(displayName),
       createdAt = Value(createdAt);
  static Insertable<ContactRow> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? displayName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? company,
    Expression<String>? title,
    Expression<String>? metadata,
    Expression<String>? linkedUserId,
    Expression<int>? createdAt,
    Expression<int>? coreId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (company != null) 'company': company,
      if (title != null) 'title': title,
      if (metadata != null) 'metadata': metadata,
      if (linkedUserId != null) 'linked_user_id': linkedUserId,
      if (createdAt != null) 'created_at': createdAt,
      if (coreId != null) 'core_id': coreId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? displayName,
    Value<String?>? email,
    Value<String?>? phone,
    Value<String?>? company,
    Value<String?>? title,
    Value<String>? metadata,
    Value<String?>? linkedUserId,
    Value<int>? createdAt,
    Value<int?>? coreId,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      createdAt: createdAt ?? this.createdAt,
      coreId: coreId ?? this.coreId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (linkedUserId.present) {
      map['linked_user_id'] = Variable<String>(linkedUserId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (coreId.present) {
      map['core_id'] = Variable<int>(coreId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('company: $company, ')
          ..write('title: $title, ')
          ..write('metadata: $metadata, ')
          ..write('linkedUserId: $linkedUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('coreId: $coreId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatomeContactsTable extends MatomeContacts
    with TableInfo<$MatomeContactsTable, MatomeContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatomeContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matomeIdMeta = const VerificationMeta(
    'matomeId',
  );
  @override
  late final GeneratedColumn<String> matomeId = GeneratedColumn<String>(
    'matome_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('attendee'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, matomeId, contactId, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matome_contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatomeContactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('matome_id')) {
      context.handle(
        _matomeIdMeta,
        matomeId.isAcceptableOrUnknown(data['matome_id']!, _matomeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matomeIdMeta);
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {matomeId, contactId},
  ];
  @override
  MatomeContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatomeContactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matome_id'],
      )!,
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $MatomeContactsTable createAlias(String alias) {
    return $MatomeContactsTable(attachedDatabase, alias);
  }
}

class MatomeContactRow extends DataClass
    implements Insertable<MatomeContactRow> {
  final String id;
  final String matomeId;
  final String contactId;
  final String role;
  const MatomeContactRow({
    required this.id,
    required this.matomeId,
    required this.contactId,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['matome_id'] = Variable<String>(matomeId);
    map['contact_id'] = Variable<String>(contactId);
    map['role'] = Variable<String>(role);
    return map;
  }

  MatomeContactsCompanion toCompanion(bool nullToAbsent) {
    return MatomeContactsCompanion(
      id: Value(id),
      matomeId: Value(matomeId),
      contactId: Value(contactId),
      role: Value(role),
    );
  }

  factory MatomeContactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatomeContactRow(
      id: serializer.fromJson<String>(json['id']),
      matomeId: serializer.fromJson<String>(json['matomeId']),
      contactId: serializer.fromJson<String>(json['contactId']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matomeId': serializer.toJson<String>(matomeId),
      'contactId': serializer.toJson<String>(contactId),
      'role': serializer.toJson<String>(role),
    };
  }

  MatomeContactRow copyWith({
    String? id,
    String? matomeId,
    String? contactId,
    String? role,
  }) => MatomeContactRow(
    id: id ?? this.id,
    matomeId: matomeId ?? this.matomeId,
    contactId: contactId ?? this.contactId,
    role: role ?? this.role,
  );
  MatomeContactRow copyWithCompanion(MatomeContactsCompanion data) {
    return MatomeContactRow(
      id: data.id.present ? data.id.value : this.id,
      matomeId: data.matomeId.present ? data.matomeId.value : this.matomeId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatomeContactRow(')
          ..write('id: $id, ')
          ..write('matomeId: $matomeId, ')
          ..write('contactId: $contactId, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matomeId, contactId, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatomeContactRow &&
          other.id == this.id &&
          other.matomeId == this.matomeId &&
          other.contactId == this.contactId &&
          other.role == this.role);
}

class MatomeContactsCompanion extends UpdateCompanion<MatomeContactRow> {
  final Value<String> id;
  final Value<String> matomeId;
  final Value<String> contactId;
  final Value<String> role;
  final Value<int> rowid;
  const MatomeContactsCompanion({
    this.id = const Value.absent(),
    this.matomeId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatomeContactsCompanion.insert({
    required String id,
    required String matomeId,
    required String contactId,
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matomeId = Value(matomeId),
       contactId = Value(contactId);
  static Insertable<MatomeContactRow> custom({
    Expression<String>? id,
    Expression<String>? matomeId,
    Expression<String>? contactId,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matomeId != null) 'matome_id': matomeId,
      if (contactId != null) 'contact_id': contactId,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatomeContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? matomeId,
    Value<String>? contactId,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return MatomeContactsCompanion(
      id: id ?? this.id,
      matomeId: matomeId ?? this.matomeId,
      contactId: contactId ?? this.contactId,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matomeId.present) {
      map['matome_id'] = Variable<String>(matomeId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatomeContactsCompanion(')
          ..write('id: $id, ')
          ..write('matomeId: $matomeId, ')
          ..write('contactId: $contactId, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpaceContactsTable extends SpaceContacts
    with TableInfo<$SpaceContactsTable, SpaceContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpaceContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, spaceId, contactId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'space_contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpaceContactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {spaceId, contactId},
  ];
  @override
  SpaceContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpaceContactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      )!,
    );
  }

  @override
  $SpaceContactsTable createAlias(String alias) {
    return $SpaceContactsTable(attachedDatabase, alias);
  }
}

class SpaceContactRow extends DataClass implements Insertable<SpaceContactRow> {
  final String id;
  final String spaceId;
  final String contactId;
  const SpaceContactRow({
    required this.id,
    required this.spaceId,
    required this.contactId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['contact_id'] = Variable<String>(contactId);
    return map;
  }

  SpaceContactsCompanion toCompanion(bool nullToAbsent) {
    return SpaceContactsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      contactId: Value(contactId),
    );
  }

  factory SpaceContactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpaceContactRow(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      contactId: serializer.fromJson<String>(json['contactId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'contactId': serializer.toJson<String>(contactId),
    };
  }

  SpaceContactRow copyWith({String? id, String? spaceId, String? contactId}) =>
      SpaceContactRow(
        id: id ?? this.id,
        spaceId: spaceId ?? this.spaceId,
        contactId: contactId ?? this.contactId,
      );
  SpaceContactRow copyWithCompanion(SpaceContactsCompanion data) {
    return SpaceContactRow(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpaceContactRow(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('contactId: $contactId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, spaceId, contactId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpaceContactRow &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.contactId == this.contactId);
}

class SpaceContactsCompanion extends UpdateCompanion<SpaceContactRow> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> contactId;
  final Value<int> rowid;
  const SpaceContactsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpaceContactsCompanion.insert({
    required String id,
    required String spaceId,
    required String contactId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       contactId = Value(contactId);
  static Insertable<SpaceContactRow> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? contactId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (contactId != null) 'contact_id': contactId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpaceContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? contactId,
    Value<int>? rowid,
  }) {
    return SpaceContactsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      contactId: contactId ?? this.contactId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpaceContactsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('contactId: $contactId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatomeSharesTable extends MatomeShares
    with TableInfo<$MatomeSharesTable, MatomeShareRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatomeSharesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matomeIdMeta = const VerificationMeta(
    'matomeId',
  );
  @override
  late final GeneratedColumn<String> matomeId = GeneratedColumn<String>(
    'matome_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sharedWithUserIdMeta = const VerificationMeta(
    'sharedWithUserId',
  );
  @override
  late final GeneratedColumn<String> sharedWithUserId = GeneratedColumn<String>(
    'shared_with_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  @override
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('read'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matomeId,
    sharedWithUserId,
    permission,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matome_shares';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatomeShareRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('matome_id')) {
      context.handle(
        _matomeIdMeta,
        matomeId.isAcceptableOrUnknown(data['matome_id']!, _matomeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matomeIdMeta);
    }
    if (data.containsKey('shared_with_user_id')) {
      context.handle(
        _sharedWithUserIdMeta,
        sharedWithUserId.isAcceptableOrUnknown(
          data['shared_with_user_id']!,
          _sharedWithUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sharedWithUserIdMeta);
    }
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatomeShareRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatomeShareRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matome_id'],
      )!,
      sharedWithUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shared_with_user_id'],
      )!,
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      )!,
    );
  }

  @override
  $MatomeSharesTable createAlias(String alias) {
    return $MatomeSharesTable(attachedDatabase, alias);
  }
}

class MatomeShareRow extends DataClass implements Insertable<MatomeShareRow> {
  final String id;
  final String matomeId;
  final String sharedWithUserId;
  final String permission;
  const MatomeShareRow({
    required this.id,
    required this.matomeId,
    required this.sharedWithUserId,
    required this.permission,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['matome_id'] = Variable<String>(matomeId);
    map['shared_with_user_id'] = Variable<String>(sharedWithUserId);
    map['permission'] = Variable<String>(permission);
    return map;
  }

  MatomeSharesCompanion toCompanion(bool nullToAbsent) {
    return MatomeSharesCompanion(
      id: Value(id),
      matomeId: Value(matomeId),
      sharedWithUserId: Value(sharedWithUserId),
      permission: Value(permission),
    );
  }

  factory MatomeShareRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatomeShareRow(
      id: serializer.fromJson<String>(json['id']),
      matomeId: serializer.fromJson<String>(json['matomeId']),
      sharedWithUserId: serializer.fromJson<String>(json['sharedWithUserId']),
      permission: serializer.fromJson<String>(json['permission']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matomeId': serializer.toJson<String>(matomeId),
      'sharedWithUserId': serializer.toJson<String>(sharedWithUserId),
      'permission': serializer.toJson<String>(permission),
    };
  }

  MatomeShareRow copyWith({
    String? id,
    String? matomeId,
    String? sharedWithUserId,
    String? permission,
  }) => MatomeShareRow(
    id: id ?? this.id,
    matomeId: matomeId ?? this.matomeId,
    sharedWithUserId: sharedWithUserId ?? this.sharedWithUserId,
    permission: permission ?? this.permission,
  );
  MatomeShareRow copyWithCompanion(MatomeSharesCompanion data) {
    return MatomeShareRow(
      id: data.id.present ? data.id.value : this.id,
      matomeId: data.matomeId.present ? data.matomeId.value : this.matomeId,
      sharedWithUserId: data.sharedWithUserId.present
          ? data.sharedWithUserId.value
          : this.sharedWithUserId,
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatomeShareRow(')
          ..write('id: $id, ')
          ..write('matomeId: $matomeId, ')
          ..write('sharedWithUserId: $sharedWithUserId, ')
          ..write('permission: $permission')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matomeId, sharedWithUserId, permission);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatomeShareRow &&
          other.id == this.id &&
          other.matomeId == this.matomeId &&
          other.sharedWithUserId == this.sharedWithUserId &&
          other.permission == this.permission);
}

class MatomeSharesCompanion extends UpdateCompanion<MatomeShareRow> {
  final Value<String> id;
  final Value<String> matomeId;
  final Value<String> sharedWithUserId;
  final Value<String> permission;
  final Value<int> rowid;
  const MatomeSharesCompanion({
    this.id = const Value.absent(),
    this.matomeId = const Value.absent(),
    this.sharedWithUserId = const Value.absent(),
    this.permission = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatomeSharesCompanion.insert({
    required String id,
    required String matomeId,
    required String sharedWithUserId,
    this.permission = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matomeId = Value(matomeId),
       sharedWithUserId = Value(sharedWithUserId);
  static Insertable<MatomeShareRow> custom({
    Expression<String>? id,
    Expression<String>? matomeId,
    Expression<String>? sharedWithUserId,
    Expression<String>? permission,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matomeId != null) 'matome_id': matomeId,
      if (sharedWithUserId != null) 'shared_with_user_id': sharedWithUserId,
      if (permission != null) 'permission': permission,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatomeSharesCompanion copyWith({
    Value<String>? id,
    Value<String>? matomeId,
    Value<String>? sharedWithUserId,
    Value<String>? permission,
    Value<int>? rowid,
  }) {
    return MatomeSharesCompanion(
      id: id ?? this.id,
      matomeId: matomeId ?? this.matomeId,
      sharedWithUserId: sharedWithUserId ?? this.sharedWithUserId,
      permission: permission ?? this.permission,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matomeId.present) {
      map['matome_id'] = Variable<String>(matomeId.value);
    }
    if (sharedWithUserId.present) {
      map['shared_with_user_id'] = Variable<String>(sharedWithUserId.value);
    }
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatomeSharesCompanion(')
          ..write('id: $id, ')
          ..write('matomeId: $matomeId, ')
          ..write('sharedWithUserId: $sharedWithUserId, ')
          ..write('permission: $permission, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileBlobsTable extends FileBlobs
    with TableInfo<$FileBlobsTable, FileBlobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coreIdMeta = const VerificationMeta('coreId');
  @override
  late final GeneratedColumn<int> coreId = GeneratedColumn<int>(
    'core_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _checksumSha256Meta = const VerificationMeta(
    'checksumSha256',
  );
  @override
  late final GeneratedColumn<String> checksumSha256 = GeneratedColumn<String>(
    'checksum_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _uploadGenerationMeta = const VerificationMeta(
    'uploadGeneration',
  );
  @override
  late final GeneratedColumn<int> uploadGeneration = GeneratedColumn<int>(
    'upload_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _uploadedAtMeta = const VerificationMeta(
    'uploadedAt',
  );
  @override
  late final GeneratedColumn<int> uploadedAt = GeneratedColumn<int>(
    'uploaded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _multipartContextMeta = const VerificationMeta(
    'multipartContext',
  );
  @override
  late final GeneratedColumn<String> multipartContext = GeneratedColumn<String>(
    'multipart_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wrappedFekMeta = const VerificationMeta(
    'wrappedFek',
  );
  @override
  late final GeneratedColumn<String> wrappedFek = GeneratedColumn<String>(
    'wrapped_fek',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNoncePrefixMeta = const VerificationMeta(
    'fileNoncePrefix',
  );
  @override
  late final GeneratedColumn<String> fileNoncePrefix = GeneratedColumn<String>(
    'file_nonce_prefix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    coreId,
    storageKey,
    filename,
    contentType,
    byteSize,
    checksumSha256,
    mediaType,
    duration,
    uploadState,
    uploadGeneration,
    uploadedAt,
    multipartContext,
    localPath,
    wrappedFek,
    fileNoncePrefix,
    isDirty,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileBlobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('core_id')) {
      context.handle(
        _coreIdMeta,
        coreId.isAcceptableOrUnknown(data['core_id']!, _coreIdMeta),
      );
    }
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('checksum_sha256')) {
      context.handle(
        _checksumSha256Meta,
        checksumSha256.isAcceptableOrUnknown(
          data['checksum_sha256']!,
          _checksumSha256Meta,
        ),
      );
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('upload_generation')) {
      context.handle(
        _uploadGenerationMeta,
        uploadGeneration.isAcceptableOrUnknown(
          data['upload_generation']!,
          _uploadGenerationMeta,
        ),
      );
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
        _uploadedAtMeta,
        uploadedAt.isAcceptableOrUnknown(data['uploaded_at']!, _uploadedAtMeta),
      );
    }
    if (data.containsKey('multipart_context')) {
      context.handle(
        _multipartContextMeta,
        multipartContext.isAcceptableOrUnknown(
          data['multipart_context']!,
          _multipartContextMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('wrapped_fek')) {
      context.handle(
        _wrappedFekMeta,
        wrappedFek.isAcceptableOrUnknown(data['wrapped_fek']!, _wrappedFekMeta),
      );
    }
    if (data.containsKey('file_nonce_prefix')) {
      context.handle(
        _fileNoncePrefixMeta,
        fileNoncePrefix.isAcceptableOrUnknown(
          data['file_nonce_prefix']!,
          _fileNoncePrefixMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileBlobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileBlobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      coreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}core_id'],
      ),
      storageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_key'],
      ),
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      checksumSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum_sha256'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      uploadGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upload_generation'],
      )!,
      uploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded_at'],
      ),
      multipartContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}multipart_context'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      wrappedFek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrapped_fek'],
      ),
      fileNoncePrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_nonce_prefix'],
      ),
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FileBlobsTable createAlias(String alias) {
    return $FileBlobsTable(attachedDatabase, alias);
  }
}

class FileBlobRow extends DataClass implements Insertable<FileBlobRow> {
  final String id;
  final int? coreId;
  final String? storageKey;
  final String? filename;
  final String? contentType;
  final int byteSize;
  final String? checksumSha256;
  final String mediaType;
  final int? duration;
  final String uploadState;
  final int uploadGeneration;
  final int? uploadedAt;
  final String? multipartContext;
  final String? localPath;
  final String? wrappedFek;
  final String? fileNoncePrefix;
  final bool isDirty;
  final int createdAt;
  final int updatedAt;
  const FileBlobRow({
    required this.id,
    this.coreId,
    this.storageKey,
    this.filename,
    this.contentType,
    required this.byteSize,
    this.checksumSha256,
    required this.mediaType,
    this.duration,
    required this.uploadState,
    required this.uploadGeneration,
    this.uploadedAt,
    this.multipartContext,
    this.localPath,
    this.wrappedFek,
    this.fileNoncePrefix,
    required this.isDirty,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || coreId != null) {
      map['core_id'] = Variable<int>(coreId);
    }
    if (!nullToAbsent || storageKey != null) {
      map['storage_key'] = Variable<String>(storageKey);
    }
    if (!nullToAbsent || filename != null) {
      map['filename'] = Variable<String>(filename);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || checksumSha256 != null) {
      map['checksum_sha256'] = Variable<String>(checksumSha256);
    }
    map['media_type'] = Variable<String>(mediaType);
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    map['upload_state'] = Variable<String>(uploadState);
    map['upload_generation'] = Variable<int>(uploadGeneration);
    if (!nullToAbsent || uploadedAt != null) {
      map['uploaded_at'] = Variable<int>(uploadedAt);
    }
    if (!nullToAbsent || multipartContext != null) {
      map['multipart_context'] = Variable<String>(multipartContext);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || wrappedFek != null) {
      map['wrapped_fek'] = Variable<String>(wrappedFek);
    }
    if (!nullToAbsent || fileNoncePrefix != null) {
      map['file_nonce_prefix'] = Variable<String>(fileNoncePrefix);
    }
    map['is_dirty'] = Variable<bool>(isDirty);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  FileBlobsCompanion toCompanion(bool nullToAbsent) {
    return FileBlobsCompanion(
      id: Value(id),
      coreId: coreId == null && nullToAbsent
          ? const Value.absent()
          : Value(coreId),
      storageKey: storageKey == null && nullToAbsent
          ? const Value.absent()
          : Value(storageKey),
      filename: filename == null && nullToAbsent
          ? const Value.absent()
          : Value(filename),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      byteSize: Value(byteSize),
      checksumSha256: checksumSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(checksumSha256),
      mediaType: Value(mediaType),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      uploadState: Value(uploadState),
      uploadGeneration: Value(uploadGeneration),
      uploadedAt: uploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAt),
      multipartContext: multipartContext == null && nullToAbsent
          ? const Value.absent()
          : Value(multipartContext),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      wrappedFek: wrappedFek == null && nullToAbsent
          ? const Value.absent()
          : Value(wrappedFek),
      fileNoncePrefix: fileNoncePrefix == null && nullToAbsent
          ? const Value.absent()
          : Value(fileNoncePrefix),
      isDirty: Value(isDirty),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FileBlobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileBlobRow(
      id: serializer.fromJson<String>(json['id']),
      coreId: serializer.fromJson<int?>(json['coreId']),
      storageKey: serializer.fromJson<String?>(json['storageKey']),
      filename: serializer.fromJson<String?>(json['filename']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      checksumSha256: serializer.fromJson<String?>(json['checksumSha256']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      duration: serializer.fromJson<int?>(json['duration']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      uploadGeneration: serializer.fromJson<int>(json['uploadGeneration']),
      uploadedAt: serializer.fromJson<int?>(json['uploadedAt']),
      multipartContext: serializer.fromJson<String?>(json['multipartContext']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      wrappedFek: serializer.fromJson<String?>(json['wrappedFek']),
      fileNoncePrefix: serializer.fromJson<String?>(json['fileNoncePrefix']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'coreId': serializer.toJson<int?>(coreId),
      'storageKey': serializer.toJson<String?>(storageKey),
      'filename': serializer.toJson<String?>(filename),
      'contentType': serializer.toJson<String?>(contentType),
      'byteSize': serializer.toJson<int>(byteSize),
      'checksumSha256': serializer.toJson<String?>(checksumSha256),
      'mediaType': serializer.toJson<String>(mediaType),
      'duration': serializer.toJson<int?>(duration),
      'uploadState': serializer.toJson<String>(uploadState),
      'uploadGeneration': serializer.toJson<int>(uploadGeneration),
      'uploadedAt': serializer.toJson<int?>(uploadedAt),
      'multipartContext': serializer.toJson<String?>(multipartContext),
      'localPath': serializer.toJson<String?>(localPath),
      'wrappedFek': serializer.toJson<String?>(wrappedFek),
      'fileNoncePrefix': serializer.toJson<String?>(fileNoncePrefix),
      'isDirty': serializer.toJson<bool>(isDirty),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  FileBlobRow copyWith({
    String? id,
    Value<int?> coreId = const Value.absent(),
    Value<String?> storageKey = const Value.absent(),
    Value<String?> filename = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    int? byteSize,
    Value<String?> checksumSha256 = const Value.absent(),
    String? mediaType,
    Value<int?> duration = const Value.absent(),
    String? uploadState,
    int? uploadGeneration,
    Value<int?> uploadedAt = const Value.absent(),
    Value<String?> multipartContext = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> wrappedFek = const Value.absent(),
    Value<String?> fileNoncePrefix = const Value.absent(),
    bool? isDirty,
    int? createdAt,
    int? updatedAt,
  }) => FileBlobRow(
    id: id ?? this.id,
    coreId: coreId.present ? coreId.value : this.coreId,
    storageKey: storageKey.present ? storageKey.value : this.storageKey,
    filename: filename.present ? filename.value : this.filename,
    contentType: contentType.present ? contentType.value : this.contentType,
    byteSize: byteSize ?? this.byteSize,
    checksumSha256: checksumSha256.present
        ? checksumSha256.value
        : this.checksumSha256,
    mediaType: mediaType ?? this.mediaType,
    duration: duration.present ? duration.value : this.duration,
    uploadState: uploadState ?? this.uploadState,
    uploadGeneration: uploadGeneration ?? this.uploadGeneration,
    uploadedAt: uploadedAt.present ? uploadedAt.value : this.uploadedAt,
    multipartContext: multipartContext.present
        ? multipartContext.value
        : this.multipartContext,
    localPath: localPath.present ? localPath.value : this.localPath,
    wrappedFek: wrappedFek.present ? wrappedFek.value : this.wrappedFek,
    fileNoncePrefix: fileNoncePrefix.present
        ? fileNoncePrefix.value
        : this.fileNoncePrefix,
    isDirty: isDirty ?? this.isDirty,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FileBlobRow copyWithCompanion(FileBlobsCompanion data) {
    return FileBlobRow(
      id: data.id.present ? data.id.value : this.id,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
      storageKey: data.storageKey.present
          ? data.storageKey.value
          : this.storageKey,
      filename: data.filename.present ? data.filename.value : this.filename,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      checksumSha256: data.checksumSha256.present
          ? data.checksumSha256.value
          : this.checksumSha256,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      duration: data.duration.present ? data.duration.value : this.duration,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      uploadGeneration: data.uploadGeneration.present
          ? data.uploadGeneration.value
          : this.uploadGeneration,
      uploadedAt: data.uploadedAt.present
          ? data.uploadedAt.value
          : this.uploadedAt,
      multipartContext: data.multipartContext.present
          ? data.multipartContext.value
          : this.multipartContext,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      wrappedFek: data.wrappedFek.present
          ? data.wrappedFek.value
          : this.wrappedFek,
      fileNoncePrefix: data.fileNoncePrefix.present
          ? data.fileNoncePrefix.value
          : this.fileNoncePrefix,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileBlobRow(')
          ..write('id: $id, ')
          ..write('coreId: $coreId, ')
          ..write('storageKey: $storageKey, ')
          ..write('filename: $filename, ')
          ..write('contentType: $contentType, ')
          ..write('byteSize: $byteSize, ')
          ..write('checksumSha256: $checksumSha256, ')
          ..write('mediaType: $mediaType, ')
          ..write('duration: $duration, ')
          ..write('uploadState: $uploadState, ')
          ..write('uploadGeneration: $uploadGeneration, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('multipartContext: $multipartContext, ')
          ..write('localPath: $localPath, ')
          ..write('wrappedFek: $wrappedFek, ')
          ..write('fileNoncePrefix: $fileNoncePrefix, ')
          ..write('isDirty: $isDirty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    coreId,
    storageKey,
    filename,
    contentType,
    byteSize,
    checksumSha256,
    mediaType,
    duration,
    uploadState,
    uploadGeneration,
    uploadedAt,
    multipartContext,
    localPath,
    wrappedFek,
    fileNoncePrefix,
    isDirty,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileBlobRow &&
          other.id == this.id &&
          other.coreId == this.coreId &&
          other.storageKey == this.storageKey &&
          other.filename == this.filename &&
          other.contentType == this.contentType &&
          other.byteSize == this.byteSize &&
          other.checksumSha256 == this.checksumSha256 &&
          other.mediaType == this.mediaType &&
          other.duration == this.duration &&
          other.uploadState == this.uploadState &&
          other.uploadGeneration == this.uploadGeneration &&
          other.uploadedAt == this.uploadedAt &&
          other.multipartContext == this.multipartContext &&
          other.localPath == this.localPath &&
          other.wrappedFek == this.wrappedFek &&
          other.fileNoncePrefix == this.fileNoncePrefix &&
          other.isDirty == this.isDirty &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FileBlobsCompanion extends UpdateCompanion<FileBlobRow> {
  final Value<String> id;
  final Value<int?> coreId;
  final Value<String?> storageKey;
  final Value<String?> filename;
  final Value<String?> contentType;
  final Value<int> byteSize;
  final Value<String?> checksumSha256;
  final Value<String> mediaType;
  final Value<int?> duration;
  final Value<String> uploadState;
  final Value<int> uploadGeneration;
  final Value<int?> uploadedAt;
  final Value<String?> multipartContext;
  final Value<String?> localPath;
  final Value<String?> wrappedFek;
  final Value<String?> fileNoncePrefix;
  final Value<bool> isDirty;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const FileBlobsCompanion({
    this.id = const Value.absent(),
    this.coreId = const Value.absent(),
    this.storageKey = const Value.absent(),
    this.filename = const Value.absent(),
    this.contentType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.checksumSha256 = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.duration = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.uploadGeneration = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.multipartContext = const Value.absent(),
    this.localPath = const Value.absent(),
    this.wrappedFek = const Value.absent(),
    this.fileNoncePrefix = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileBlobsCompanion.insert({
    required String id,
    this.coreId = const Value.absent(),
    this.storageKey = const Value.absent(),
    this.filename = const Value.absent(),
    this.contentType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.checksumSha256 = const Value.absent(),
    required String mediaType,
    this.duration = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.uploadGeneration = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.multipartContext = const Value.absent(),
    this.localPath = const Value.absent(),
    this.wrappedFek = const Value.absent(),
    this.fileNoncePrefix = const Value.absent(),
    this.isDirty = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mediaType = Value(mediaType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FileBlobRow> custom({
    Expression<String>? id,
    Expression<int>? coreId,
    Expression<String>? storageKey,
    Expression<String>? filename,
    Expression<String>? contentType,
    Expression<int>? byteSize,
    Expression<String>? checksumSha256,
    Expression<String>? mediaType,
    Expression<int>? duration,
    Expression<String>? uploadState,
    Expression<int>? uploadGeneration,
    Expression<int>? uploadedAt,
    Expression<String>? multipartContext,
    Expression<String>? localPath,
    Expression<String>? wrappedFek,
    Expression<String>? fileNoncePrefix,
    Expression<bool>? isDirty,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coreId != null) 'core_id': coreId,
      if (storageKey != null) 'storage_key': storageKey,
      if (filename != null) 'filename': filename,
      if (contentType != null) 'content_type': contentType,
      if (byteSize != null) 'byte_size': byteSize,
      if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
      if (mediaType != null) 'media_type': mediaType,
      if (duration != null) 'duration': duration,
      if (uploadState != null) 'upload_state': uploadState,
      if (uploadGeneration != null) 'upload_generation': uploadGeneration,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (multipartContext != null) 'multipart_context': multipartContext,
      if (localPath != null) 'local_path': localPath,
      if (wrappedFek != null) 'wrapped_fek': wrappedFek,
      if (fileNoncePrefix != null) 'file_nonce_prefix': fileNoncePrefix,
      if (isDirty != null) 'is_dirty': isDirty,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileBlobsCompanion copyWith({
    Value<String>? id,
    Value<int?>? coreId,
    Value<String?>? storageKey,
    Value<String?>? filename,
    Value<String?>? contentType,
    Value<int>? byteSize,
    Value<String?>? checksumSha256,
    Value<String>? mediaType,
    Value<int?>? duration,
    Value<String>? uploadState,
    Value<int>? uploadGeneration,
    Value<int?>? uploadedAt,
    Value<String?>? multipartContext,
    Value<String?>? localPath,
    Value<String?>? wrappedFek,
    Value<String?>? fileNoncePrefix,
    Value<bool>? isDirty,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return FileBlobsCompanion(
      id: id ?? this.id,
      coreId: coreId ?? this.coreId,
      storageKey: storageKey ?? this.storageKey,
      filename: filename ?? this.filename,
      contentType: contentType ?? this.contentType,
      byteSize: byteSize ?? this.byteSize,
      checksumSha256: checksumSha256 ?? this.checksumSha256,
      mediaType: mediaType ?? this.mediaType,
      duration: duration ?? this.duration,
      uploadState: uploadState ?? this.uploadState,
      uploadGeneration: uploadGeneration ?? this.uploadGeneration,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      multipartContext: multipartContext ?? this.multipartContext,
      localPath: localPath ?? this.localPath,
      wrappedFek: wrappedFek ?? this.wrappedFek,
      fileNoncePrefix: fileNoncePrefix ?? this.fileNoncePrefix,
      isDirty: isDirty ?? this.isDirty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (coreId.present) {
      map['core_id'] = Variable<int>(coreId.value);
    }
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (checksumSha256.present) {
      map['checksum_sha256'] = Variable<String>(checksumSha256.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (uploadGeneration.present) {
      map['upload_generation'] = Variable<int>(uploadGeneration.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<int>(uploadedAt.value);
    }
    if (multipartContext.present) {
      map['multipart_context'] = Variable<String>(multipartContext.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (wrappedFek.present) {
      map['wrapped_fek'] = Variable<String>(wrappedFek.value);
    }
    if (fileNoncePrefix.present) {
      map['file_nonce_prefix'] = Variable<String>(fileNoncePrefix.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileBlobsCompanion(')
          ..write('id: $id, ')
          ..write('coreId: $coreId, ')
          ..write('storageKey: $storageKey, ')
          ..write('filename: $filename, ')
          ..write('contentType: $contentType, ')
          ..write('byteSize: $byteSize, ')
          ..write('checksumSha256: $checksumSha256, ')
          ..write('mediaType: $mediaType, ')
          ..write('duration: $duration, ')
          ..write('uploadState: $uploadState, ')
          ..write('uploadGeneration: $uploadGeneration, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('multipartContext: $multipartContext, ')
          ..write('localPath: $localPath, ')
          ..write('wrappedFek: $wrappedFek, ')
          ..write('fileNoncePrefix: $fileNoncePrefix, ')
          ..write('isDirty: $isDirty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TextContentsTable extends TextContents
    with TableInfo<$TextContentsTable, TextContentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextContentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coreIdMeta = const VerificationMeta('coreId');
  @override
  late final GeneratedColumn<int> coreId = GeneratedColumn<int>(
    'core_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    coreId,
    body,
    isDirty,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_contents';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextContentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('core_id')) {
      context.handle(
        _coreIdMeta,
        coreId.isAcceptableOrUnknown(data['core_id']!, _coreIdMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TextContentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextContentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      coreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}core_id'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TextContentsTable createAlias(String alias) {
    return $TextContentsTable(attachedDatabase, alias);
  }
}

class TextContentRow extends DataClass implements Insertable<TextContentRow> {
  final String id;
  final int? coreId;
  final String body;
  final bool isDirty;
  final int createdAt;
  final int updatedAt;
  const TextContentRow({
    required this.id,
    this.coreId,
    required this.body,
    required this.isDirty,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || coreId != null) {
      map['core_id'] = Variable<int>(coreId);
    }
    map['body'] = Variable<String>(body);
    map['is_dirty'] = Variable<bool>(isDirty);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TextContentsCompanion toCompanion(bool nullToAbsent) {
    return TextContentsCompanion(
      id: Value(id),
      coreId: coreId == null && nullToAbsent
          ? const Value.absent()
          : Value(coreId),
      body: Value(body),
      isDirty: Value(isDirty),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TextContentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextContentRow(
      id: serializer.fromJson<String>(json['id']),
      coreId: serializer.fromJson<int?>(json['coreId']),
      body: serializer.fromJson<String>(json['body']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'coreId': serializer.toJson<int?>(coreId),
      'body': serializer.toJson<String>(body),
      'isDirty': serializer.toJson<bool>(isDirty),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TextContentRow copyWith({
    String? id,
    Value<int?> coreId = const Value.absent(),
    String? body,
    bool? isDirty,
    int? createdAt,
    int? updatedAt,
  }) => TextContentRow(
    id: id ?? this.id,
    coreId: coreId.present ? coreId.value : this.coreId,
    body: body ?? this.body,
    isDirty: isDirty ?? this.isDirty,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TextContentRow copyWithCompanion(TextContentsCompanion data) {
    return TextContentRow(
      id: data.id.present ? data.id.value : this.id,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
      body: data.body.present ? data.body.value : this.body,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextContentRow(')
          ..write('id: $id, ')
          ..write('coreId: $coreId, ')
          ..write('body: $body, ')
          ..write('isDirty: $isDirty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, coreId, body, isDirty, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextContentRow &&
          other.id == this.id &&
          other.coreId == this.coreId &&
          other.body == this.body &&
          other.isDirty == this.isDirty &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TextContentsCompanion extends UpdateCompanion<TextContentRow> {
  final Value<String> id;
  final Value<int?> coreId;
  final Value<String> body;
  final Value<bool> isDirty;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TextContentsCompanion({
    this.id = const Value.absent(),
    this.coreId = const Value.absent(),
    this.body = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextContentsCompanion.insert({
    required String id,
    this.coreId = const Value.absent(),
    required String body,
    this.isDirty = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TextContentRow> custom({
    Expression<String>? id,
    Expression<int>? coreId,
    Expression<String>? body,
    Expression<bool>? isDirty,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coreId != null) 'core_id': coreId,
      if (body != null) 'body': body,
      if (isDirty != null) 'is_dirty': isDirty,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextContentsCompanion copyWith({
    Value<String>? id,
    Value<int?>? coreId,
    Value<String>? body,
    Value<bool>? isDirty,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TextContentsCompanion(
      id: id ?? this.id,
      coreId: coreId ?? this.coreId,
      body: body ?? this.body,
      isDirty: isDirty ?? this.isDirty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (coreId.present) {
      map['core_id'] = Variable<int>(coreId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextContentsCompanion(')
          ..write('id: $id, ')
          ..write('coreId: $coreId, ')
          ..write('body: $body, ')
          ..write('isDirty: $isDirty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coreIdMeta = const VerificationMeta('coreId');
  @override
  late final GeneratedColumn<int> coreId = GeneratedColumn<int>(
    'core_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientFingerprintMeta = const VerificationMeta(
    'clientFingerprint',
  );
  @override
  late final GeneratedColumn<String> clientFingerprint =
      GeneratedColumn<String>(
        'client_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matomeIdMeta = const VerificationMeta(
    'matomeId',
  );
  @override
  late final GeneratedColumn<String> matomeId = GeneratedColumn<String>(
    'matome_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Untitled'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _processingStateMeta = const VerificationMeta(
    'processingState',
  );
  @override
  late final GeneratedColumn<String> processingState = GeneratedColumn<String>(
    'processing_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_requested'),
  );
  static const VerificationMeta _processingRunIdMeta = const VerificationMeta(
    'processingRunId',
  );
  @override
  late final GeneratedColumn<String> processingRunId = GeneratedColumn<String>(
    'processing_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<int> sourceRevision = GeneratedColumn<int>(
    'source_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _processingConfigRevisionMeta =
      const VerificationMeta('processingConfigRevision');
  @override
  late final GeneratedColumn<int> processingConfigRevision =
      GeneratedColumn<int>(
        'processing_config_revision',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _processingOutputsMeta = const VerificationMeta(
    'processingOutputs',
  );
  @override
  late final GeneratedColumn<String> processingOutputs =
      GeneratedColumn<String>(
        'processing_outputs',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _processingErrorMeta = const VerificationMeta(
    'processingError',
  );
  @override
  late final GeneratedColumn<String> processingError = GeneratedColumn<String>(
    'processing_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _processingErrorCodeMeta =
      const VerificationMeta('processingErrorCode');
  @override
  late final GeneratedColumn<String> processingErrorCode =
      GeneratedColumn<String>(
        'processing_error_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fileBlobIdMeta = const VerificationMeta(
    'fileBlobId',
  );
  @override
  late final GeneratedColumn<String> fileBlobId = GeneratedColumn<String>(
    'file_blob_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textContentIdMeta = const VerificationMeta(
    'textContentId',
  );
  @override
  late final GeneratedColumn<String> textContentId = GeneratedColumn<String>(
    'text_content_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_saved'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    coreId,
    ownerId,
    clientId,
    clientFingerprint,
    workspaceId,
    matomeId,
    position,
    itemType,
    title,
    notes,
    metadata,
    processingState,
    processingRunId,
    sourceRevision,
    processingConfigRevision,
    processingOutputs,
    processingError,
    processingErrorCode,
    fileBlobId,
    textContentId,
    isDirty,
    syncState,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('core_id')) {
      context.handle(
        _coreIdMeta,
        coreId.isAcceptableOrUnknown(data['core_id']!, _coreIdMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('client_fingerprint')) {
      context.handle(
        _clientFingerprintMeta,
        clientFingerprint.isAcceptableOrUnknown(
          data['client_fingerprint']!,
          _clientFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    }
    if (data.containsKey('matome_id')) {
      context.handle(
        _matomeIdMeta,
        matomeId.isAcceptableOrUnknown(data['matome_id']!, _matomeIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('processing_state')) {
      context.handle(
        _processingStateMeta,
        processingState.isAcceptableOrUnknown(
          data['processing_state']!,
          _processingStateMeta,
        ),
      );
    }
    if (data.containsKey('processing_run_id')) {
      context.handle(
        _processingRunIdMeta,
        processingRunId.isAcceptableOrUnknown(
          data['processing_run_id']!,
          _processingRunIdMeta,
        ),
      );
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('processing_config_revision')) {
      context.handle(
        _processingConfigRevisionMeta,
        processingConfigRevision.isAcceptableOrUnknown(
          data['processing_config_revision']!,
          _processingConfigRevisionMeta,
        ),
      );
    }
    if (data.containsKey('processing_outputs')) {
      context.handle(
        _processingOutputsMeta,
        processingOutputs.isAcceptableOrUnknown(
          data['processing_outputs']!,
          _processingOutputsMeta,
        ),
      );
    }
    if (data.containsKey('processing_error')) {
      context.handle(
        _processingErrorMeta,
        processingError.isAcceptableOrUnknown(
          data['processing_error']!,
          _processingErrorMeta,
        ),
      );
    }
    if (data.containsKey('processing_error_code')) {
      context.handle(
        _processingErrorCodeMeta,
        processingErrorCode.isAcceptableOrUnknown(
          data['processing_error_code']!,
          _processingErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('file_blob_id')) {
      context.handle(
        _fileBlobIdMeta,
        fileBlobId.isAcceptableOrUnknown(
          data['file_blob_id']!,
          _fileBlobIdMeta,
        ),
      );
    }
    if (data.containsKey('text_content_id')) {
      context.handle(
        _textContentIdMeta,
        textContentId.isAcceptableOrUnknown(
          data['text_content_id']!,
          _textContentIdMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ownerId, matomeId, position},
    {ownerId, clientId},
  ];
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      coreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}core_id'],
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      clientFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_fingerprint'],
      ),
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      ),
      matomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matome_id'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      processingState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_state'],
      )!,
      processingRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_run_id'],
      ),
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_revision'],
      )!,
      processingConfigRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processing_config_revision'],
      ),
      processingOutputs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_outputs'],
      )!,
      processingError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_error'],
      ),
      processingErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_error_code'],
      ),
      fileBlobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_blob_id'],
      ),
      textContentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content_id'],
      ),
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final int? coreId;
  final String ownerId;
  final String clientId;
  final String? clientFingerprint;
  final String? workspaceId;
  final String? matomeId;
  final int? position;
  final String itemType;
  final String title;
  final String? notes;
  final String metadata;
  final String processingState;
  final String? processingRunId;
  final int sourceRevision;
  final int? processingConfigRevision;
  final String processingOutputs;
  final String? processingError;
  final String? processingErrorCode;
  final String? fileBlobId;
  final String? textContentId;
  final bool isDirty;
  final String syncState;
  final int createdAt;
  final int updatedAt;
  const ItemRow({
    required this.id,
    this.coreId,
    required this.ownerId,
    required this.clientId,
    this.clientFingerprint,
    this.workspaceId,
    this.matomeId,
    this.position,
    required this.itemType,
    required this.title,
    this.notes,
    required this.metadata,
    required this.processingState,
    this.processingRunId,
    required this.sourceRevision,
    this.processingConfigRevision,
    required this.processingOutputs,
    this.processingError,
    this.processingErrorCode,
    this.fileBlobId,
    this.textContentId,
    required this.isDirty,
    required this.syncState,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || coreId != null) {
      map['core_id'] = Variable<int>(coreId);
    }
    map['owner_id'] = Variable<String>(ownerId);
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || clientFingerprint != null) {
      map['client_fingerprint'] = Variable<String>(clientFingerprint);
    }
    if (!nullToAbsent || workspaceId != null) {
      map['workspace_id'] = Variable<String>(workspaceId);
    }
    if (!nullToAbsent || matomeId != null) {
      map['matome_id'] = Variable<String>(matomeId);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    map['item_type'] = Variable<String>(itemType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['metadata'] = Variable<String>(metadata);
    map['processing_state'] = Variable<String>(processingState);
    if (!nullToAbsent || processingRunId != null) {
      map['processing_run_id'] = Variable<String>(processingRunId);
    }
    map['source_revision'] = Variable<int>(sourceRevision);
    if (!nullToAbsent || processingConfigRevision != null) {
      map['processing_config_revision'] = Variable<int>(
        processingConfigRevision,
      );
    }
    map['processing_outputs'] = Variable<String>(processingOutputs);
    if (!nullToAbsent || processingError != null) {
      map['processing_error'] = Variable<String>(processingError);
    }
    if (!nullToAbsent || processingErrorCode != null) {
      map['processing_error_code'] = Variable<String>(processingErrorCode);
    }
    if (!nullToAbsent || fileBlobId != null) {
      map['file_blob_id'] = Variable<String>(fileBlobId);
    }
    if (!nullToAbsent || textContentId != null) {
      map['text_content_id'] = Variable<String>(textContentId);
    }
    map['is_dirty'] = Variable<bool>(isDirty);
    map['sync_state'] = Variable<String>(syncState);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      coreId: coreId == null && nullToAbsent
          ? const Value.absent()
          : Value(coreId),
      ownerId: Value(ownerId),
      clientId: Value(clientId),
      clientFingerprint: clientFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(clientFingerprint),
      workspaceId: workspaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(workspaceId),
      matomeId: matomeId == null && nullToAbsent
          ? const Value.absent()
          : Value(matomeId),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      itemType: Value(itemType),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      metadata: Value(metadata),
      processingState: Value(processingState),
      processingRunId: processingRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(processingRunId),
      sourceRevision: Value(sourceRevision),
      processingConfigRevision: processingConfigRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(processingConfigRevision),
      processingOutputs: Value(processingOutputs),
      processingError: processingError == null && nullToAbsent
          ? const Value.absent()
          : Value(processingError),
      processingErrorCode: processingErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(processingErrorCode),
      fileBlobId: fileBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(fileBlobId),
      textContentId: textContentId == null && nullToAbsent
          ? const Value.absent()
          : Value(textContentId),
      isDirty: Value(isDirty),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      coreId: serializer.fromJson<int?>(json['coreId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      clientId: serializer.fromJson<String>(json['clientId']),
      clientFingerprint: serializer.fromJson<String?>(
        json['clientFingerprint'],
      ),
      workspaceId: serializer.fromJson<String?>(json['workspaceId']),
      matomeId: serializer.fromJson<String?>(json['matomeId']),
      position: serializer.fromJson<int?>(json['position']),
      itemType: serializer.fromJson<String>(json['itemType']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      metadata: serializer.fromJson<String>(json['metadata']),
      processingState: serializer.fromJson<String>(json['processingState']),
      processingRunId: serializer.fromJson<String?>(json['processingRunId']),
      sourceRevision: serializer.fromJson<int>(json['sourceRevision']),
      processingConfigRevision: serializer.fromJson<int?>(
        json['processingConfigRevision'],
      ),
      processingOutputs: serializer.fromJson<String>(json['processingOutputs']),
      processingError: serializer.fromJson<String?>(json['processingError']),
      processingErrorCode: serializer.fromJson<String?>(
        json['processingErrorCode'],
      ),
      fileBlobId: serializer.fromJson<String?>(json['fileBlobId']),
      textContentId: serializer.fromJson<String?>(json['textContentId']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'coreId': serializer.toJson<int?>(coreId),
      'ownerId': serializer.toJson<String>(ownerId),
      'clientId': serializer.toJson<String>(clientId),
      'clientFingerprint': serializer.toJson<String?>(clientFingerprint),
      'workspaceId': serializer.toJson<String?>(workspaceId),
      'matomeId': serializer.toJson<String?>(matomeId),
      'position': serializer.toJson<int?>(position),
      'itemType': serializer.toJson<String>(itemType),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'metadata': serializer.toJson<String>(metadata),
      'processingState': serializer.toJson<String>(processingState),
      'processingRunId': serializer.toJson<String?>(processingRunId),
      'sourceRevision': serializer.toJson<int>(sourceRevision),
      'processingConfigRevision': serializer.toJson<int?>(
        processingConfigRevision,
      ),
      'processingOutputs': serializer.toJson<String>(processingOutputs),
      'processingError': serializer.toJson<String?>(processingError),
      'processingErrorCode': serializer.toJson<String?>(processingErrorCode),
      'fileBlobId': serializer.toJson<String?>(fileBlobId),
      'textContentId': serializer.toJson<String?>(textContentId),
      'isDirty': serializer.toJson<bool>(isDirty),
      'syncState': serializer.toJson<String>(syncState),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ItemRow copyWith({
    String? id,
    Value<int?> coreId = const Value.absent(),
    String? ownerId,
    String? clientId,
    Value<String?> clientFingerprint = const Value.absent(),
    Value<String?> workspaceId = const Value.absent(),
    Value<String?> matomeId = const Value.absent(),
    Value<int?> position = const Value.absent(),
    String? itemType,
    String? title,
    Value<String?> notes = const Value.absent(),
    String? metadata,
    String? processingState,
    Value<String?> processingRunId = const Value.absent(),
    int? sourceRevision,
    Value<int?> processingConfigRevision = const Value.absent(),
    String? processingOutputs,
    Value<String?> processingError = const Value.absent(),
    Value<String?> processingErrorCode = const Value.absent(),
    Value<String?> fileBlobId = const Value.absent(),
    Value<String?> textContentId = const Value.absent(),
    bool? isDirty,
    String? syncState,
    int? createdAt,
    int? updatedAt,
  }) => ItemRow(
    id: id ?? this.id,
    coreId: coreId.present ? coreId.value : this.coreId,
    ownerId: ownerId ?? this.ownerId,
    clientId: clientId ?? this.clientId,
    clientFingerprint: clientFingerprint.present
        ? clientFingerprint.value
        : this.clientFingerprint,
    workspaceId: workspaceId.present ? workspaceId.value : this.workspaceId,
    matomeId: matomeId.present ? matomeId.value : this.matomeId,
    position: position.present ? position.value : this.position,
    itemType: itemType ?? this.itemType,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    metadata: metadata ?? this.metadata,
    processingState: processingState ?? this.processingState,
    processingRunId: processingRunId.present
        ? processingRunId.value
        : this.processingRunId,
    sourceRevision: sourceRevision ?? this.sourceRevision,
    processingConfigRevision: processingConfigRevision.present
        ? processingConfigRevision.value
        : this.processingConfigRevision,
    processingOutputs: processingOutputs ?? this.processingOutputs,
    processingError: processingError.present
        ? processingError.value
        : this.processingError,
    processingErrorCode: processingErrorCode.present
        ? processingErrorCode.value
        : this.processingErrorCode,
    fileBlobId: fileBlobId.present ? fileBlobId.value : this.fileBlobId,
    textContentId: textContentId.present
        ? textContentId.value
        : this.textContentId,
    isDirty: isDirty ?? this.isDirty,
    syncState: syncState ?? this.syncState,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      clientFingerprint: data.clientFingerprint.present
          ? data.clientFingerprint.value
          : this.clientFingerprint,
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      matomeId: data.matomeId.present ? data.matomeId.value : this.matomeId,
      position: data.position.present ? data.position.value : this.position,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      processingState: data.processingState.present
          ? data.processingState.value
          : this.processingState,
      processingRunId: data.processingRunId.present
          ? data.processingRunId.value
          : this.processingRunId,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      processingConfigRevision: data.processingConfigRevision.present
          ? data.processingConfigRevision.value
          : this.processingConfigRevision,
      processingOutputs: data.processingOutputs.present
          ? data.processingOutputs.value
          : this.processingOutputs,
      processingError: data.processingError.present
          ? data.processingError.value
          : this.processingError,
      processingErrorCode: data.processingErrorCode.present
          ? data.processingErrorCode.value
          : this.processingErrorCode,
      fileBlobId: data.fileBlobId.present
          ? data.fileBlobId.value
          : this.fileBlobId,
      textContentId: data.textContentId.present
          ? data.textContentId.value
          : this.textContentId,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('coreId: $coreId, ')
          ..write('ownerId: $ownerId, ')
          ..write('clientId: $clientId, ')
          ..write('clientFingerprint: $clientFingerprint, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('matomeId: $matomeId, ')
          ..write('position: $position, ')
          ..write('itemType: $itemType, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('metadata: $metadata, ')
          ..write('processingState: $processingState, ')
          ..write('processingRunId: $processingRunId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('processingConfigRevision: $processingConfigRevision, ')
          ..write('processingOutputs: $processingOutputs, ')
          ..write('processingError: $processingError, ')
          ..write('processingErrorCode: $processingErrorCode, ')
          ..write('fileBlobId: $fileBlobId, ')
          ..write('textContentId: $textContentId, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    coreId,
    ownerId,
    clientId,
    clientFingerprint,
    workspaceId,
    matomeId,
    position,
    itemType,
    title,
    notes,
    metadata,
    processingState,
    processingRunId,
    sourceRevision,
    processingConfigRevision,
    processingOutputs,
    processingError,
    processingErrorCode,
    fileBlobId,
    textContentId,
    isDirty,
    syncState,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.coreId == this.coreId &&
          other.ownerId == this.ownerId &&
          other.clientId == this.clientId &&
          other.clientFingerprint == this.clientFingerprint &&
          other.workspaceId == this.workspaceId &&
          other.matomeId == this.matomeId &&
          other.position == this.position &&
          other.itemType == this.itemType &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.metadata == this.metadata &&
          other.processingState == this.processingState &&
          other.processingRunId == this.processingRunId &&
          other.sourceRevision == this.sourceRevision &&
          other.processingConfigRevision == this.processingConfigRevision &&
          other.processingOutputs == this.processingOutputs &&
          other.processingError == this.processingError &&
          other.processingErrorCode == this.processingErrorCode &&
          other.fileBlobId == this.fileBlobId &&
          other.textContentId == this.textContentId &&
          other.isDirty == this.isDirty &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<int?> coreId;
  final Value<String> ownerId;
  final Value<String> clientId;
  final Value<String?> clientFingerprint;
  final Value<String?> workspaceId;
  final Value<String?> matomeId;
  final Value<int?> position;
  final Value<String> itemType;
  final Value<String> title;
  final Value<String?> notes;
  final Value<String> metadata;
  final Value<String> processingState;
  final Value<String?> processingRunId;
  final Value<int> sourceRevision;
  final Value<int?> processingConfigRevision;
  final Value<String> processingOutputs;
  final Value<String?> processingError;
  final Value<String?> processingErrorCode;
  final Value<String?> fileBlobId;
  final Value<String?> textContentId;
  final Value<bool> isDirty;
  final Value<String> syncState;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.coreId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.clientFingerprint = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.matomeId = const Value.absent(),
    this.position = const Value.absent(),
    this.itemType = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.metadata = const Value.absent(),
    this.processingState = const Value.absent(),
    this.processingRunId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.processingConfigRevision = const Value.absent(),
    this.processingOutputs = const Value.absent(),
    this.processingError = const Value.absent(),
    this.processingErrorCode = const Value.absent(),
    this.fileBlobId = const Value.absent(),
    this.textContentId = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    this.coreId = const Value.absent(),
    required String ownerId,
    required String clientId,
    this.clientFingerprint = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.matomeId = const Value.absent(),
    this.position = const Value.absent(),
    required String itemType,
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.metadata = const Value.absent(),
    this.processingState = const Value.absent(),
    this.processingRunId = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.processingConfigRevision = const Value.absent(),
    this.processingOutputs = const Value.absent(),
    this.processingError = const Value.absent(),
    this.processingErrorCode = const Value.absent(),
    this.fileBlobId = const Value.absent(),
    this.textContentId = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncState = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       clientId = Value(clientId),
       itemType = Value(itemType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<int>? coreId,
    Expression<String>? ownerId,
    Expression<String>? clientId,
    Expression<String>? clientFingerprint,
    Expression<String>? workspaceId,
    Expression<String>? matomeId,
    Expression<int>? position,
    Expression<String>? itemType,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? metadata,
    Expression<String>? processingState,
    Expression<String>? processingRunId,
    Expression<int>? sourceRevision,
    Expression<int>? processingConfigRevision,
    Expression<String>? processingOutputs,
    Expression<String>? processingError,
    Expression<String>? processingErrorCode,
    Expression<String>? fileBlobId,
    Expression<String>? textContentId,
    Expression<bool>? isDirty,
    Expression<String>? syncState,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coreId != null) 'core_id': coreId,
      if (ownerId != null) 'owner_id': ownerId,
      if (clientId != null) 'client_id': clientId,
      if (clientFingerprint != null) 'client_fingerprint': clientFingerprint,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (matomeId != null) 'matome_id': matomeId,
      if (position != null) 'position': position,
      if (itemType != null) 'item_type': itemType,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (metadata != null) 'metadata': metadata,
      if (processingState != null) 'processing_state': processingState,
      if (processingRunId != null) 'processing_run_id': processingRunId,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (processingConfigRevision != null)
        'processing_config_revision': processingConfigRevision,
      if (processingOutputs != null) 'processing_outputs': processingOutputs,
      if (processingError != null) 'processing_error': processingError,
      if (processingErrorCode != null)
        'processing_error_code': processingErrorCode,
      if (fileBlobId != null) 'file_blob_id': fileBlobId,
      if (textContentId != null) 'text_content_id': textContentId,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<int?>? coreId,
    Value<String>? ownerId,
    Value<String>? clientId,
    Value<String?>? clientFingerprint,
    Value<String?>? workspaceId,
    Value<String?>? matomeId,
    Value<int?>? position,
    Value<String>? itemType,
    Value<String>? title,
    Value<String?>? notes,
    Value<String>? metadata,
    Value<String>? processingState,
    Value<String?>? processingRunId,
    Value<int>? sourceRevision,
    Value<int?>? processingConfigRevision,
    Value<String>? processingOutputs,
    Value<String?>? processingError,
    Value<String?>? processingErrorCode,
    Value<String?>? fileBlobId,
    Value<String?>? textContentId,
    Value<bool>? isDirty,
    Value<String>? syncState,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      coreId: coreId ?? this.coreId,
      ownerId: ownerId ?? this.ownerId,
      clientId: clientId ?? this.clientId,
      clientFingerprint: clientFingerprint ?? this.clientFingerprint,
      workspaceId: workspaceId ?? this.workspaceId,
      matomeId: matomeId ?? this.matomeId,
      position: position ?? this.position,
      itemType: itemType ?? this.itemType,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      processingState: processingState ?? this.processingState,
      processingRunId: processingRunId ?? this.processingRunId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      processingConfigRevision:
          processingConfigRevision ?? this.processingConfigRevision,
      processingOutputs: processingOutputs ?? this.processingOutputs,
      processingError: processingError ?? this.processingError,
      processingErrorCode: processingErrorCode ?? this.processingErrorCode,
      fileBlobId: fileBlobId ?? this.fileBlobId,
      textContentId: textContentId ?? this.textContentId,
      isDirty: isDirty ?? this.isDirty,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (coreId.present) {
      map['core_id'] = Variable<int>(coreId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (clientFingerprint.present) {
      map['client_fingerprint'] = Variable<String>(clientFingerprint.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (matomeId.present) {
      map['matome_id'] = Variable<String>(matomeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (processingState.present) {
      map['processing_state'] = Variable<String>(processingState.value);
    }
    if (processingRunId.present) {
      map['processing_run_id'] = Variable<String>(processingRunId.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<int>(sourceRevision.value);
    }
    if (processingConfigRevision.present) {
      map['processing_config_revision'] = Variable<int>(
        processingConfigRevision.value,
      );
    }
    if (processingOutputs.present) {
      map['processing_outputs'] = Variable<String>(processingOutputs.value);
    }
    if (processingError.present) {
      map['processing_error'] = Variable<String>(processingError.value);
    }
    if (processingErrorCode.present) {
      map['processing_error_code'] = Variable<String>(
        processingErrorCode.value,
      );
    }
    if (fileBlobId.present) {
      map['file_blob_id'] = Variable<String>(fileBlobId.value);
    }
    if (textContentId.present) {
      map['text_content_id'] = Variable<String>(textContentId.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('coreId: $coreId, ')
          ..write('ownerId: $ownerId, ')
          ..write('clientId: $clientId, ')
          ..write('clientFingerprint: $clientFingerprint, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('matomeId: $matomeId, ')
          ..write('position: $position, ')
          ..write('itemType: $itemType, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('metadata: $metadata, ')
          ..write('processingState: $processingState, ')
          ..write('processingRunId: $processingRunId, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('processingConfigRevision: $processingConfigRevision, ')
          ..write('processingOutputs: $processingOutputs, ')
          ..write('processingError: $processingError, ')
          ..write('processingErrorCode: $processingErrorCode, ')
          ..write('fileBlobId: $fileBlobId, ')
          ..write('textContentId: $textContentId, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemContactsTable extends ItemContacts
    with TableInfo<$ItemContactsTable, ItemContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, itemId, contactId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemContactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {itemId, contactId},
  ];
  @override
  ItemContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemContactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      )!,
    );
  }

  @override
  $ItemContactsTable createAlias(String alias) {
    return $ItemContactsTable(attachedDatabase, alias);
  }
}

class ItemContactRow extends DataClass implements Insertable<ItemContactRow> {
  final String id;
  final String itemId;
  final String contactId;
  const ItemContactRow({
    required this.id,
    required this.itemId,
    required this.contactId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['contact_id'] = Variable<String>(contactId);
    return map;
  }

  ItemContactsCompanion toCompanion(bool nullToAbsent) {
    return ItemContactsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      contactId: Value(contactId),
    );
  }

  factory ItemContactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemContactRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      contactId: serializer.fromJson<String>(json['contactId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'contactId': serializer.toJson<String>(contactId),
    };
  }

  ItemContactRow copyWith({String? id, String? itemId, String? contactId}) =>
      ItemContactRow(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        contactId: contactId ?? this.contactId,
      );
  ItemContactRow copyWithCompanion(ItemContactsCompanion data) {
    return ItemContactRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemContactRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('contactId: $contactId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, contactId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemContactRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.contactId == this.contactId);
}

class ItemContactsCompanion extends UpdateCompanion<ItemContactRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> contactId;
  final Value<int> rowid;
  const ItemContactsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemContactsCompanion.insert({
    required String id,
    required String itemId,
    required String contactId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       contactId = Value(contactId);
  static Insertable<ItemContactRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? contactId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (contactId != null) 'contact_id': contactId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? contactId,
    Value<int>? rowid,
  }) {
    return ItemContactsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      contactId: contactId ?? this.contactId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemContactsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('contactId: $contactId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorkspacesTable workspaces = $WorkspacesTable(this);
  late final $RecordingDraftsTable recordingDrafts = $RecordingDraftsTable(
    this,
  );
  late final $SpaceMembersTable spaceMembers = $SpaceMembersTable(this);
  late final $OrganizationsTable organizations = $OrganizationsTable(this);
  late final $MatomesTable matomes = $MatomesTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $MatomeContactsTable matomeContacts = $MatomeContactsTable(this);
  late final $SpaceContactsTable spaceContacts = $SpaceContactsTable(this);
  late final $MatomeSharesTable matomeShares = $MatomeSharesTable(this);
  late final $FileBlobsTable fileBlobs = $FileBlobsTable(this);
  late final $TextContentsTable textContents = $TextContentsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $ItemContactsTable itemContacts = $ItemContactsTable(this);
  late final WorkspacesDao workspacesDao = WorkspacesDao(this as AppDatabase);
  late final RecordingDraftsDao recordingDraftsDao = RecordingDraftsDao(
    this as AppDatabase,
  );
  late final SpacesDao spacesDao = SpacesDao(this as AppDatabase);
  late final MatomesDao matomesDao = MatomesDao(this as AppDatabase);
  late final ContactsDao contactsDao = ContactsDao(this as AppDatabase);
  late final ItemsDao itemsDao = ItemsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workspaces,
    recordingDrafts,
    spaceMembers,
    organizations,
    matomes,
    contacts,
    matomeContacts,
    spaceContacts,
    matomeShares,
    fileBlobs,
    textContents,
    items,
    itemContacts,
  ];
}

typedef $$WorkspacesTableCreateCompanionBuilder =
    WorkspacesCompanion Function({
      required String id,
      required String name,
      Value<int> isDefault,
      required int createdAt,
      Value<String> spaceType,
      Value<String?> ownerId,
      Value<int> isLocal,
      Value<int> rowid,
    });
typedef $$WorkspacesTableUpdateCompanionBuilder =
    WorkspacesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> isDefault,
      Value<int> createdAt,
      Value<String> spaceType,
      Value<String?> ownerId,
      Value<int> isLocal,
      Value<int> rowid,
    });

class $$WorkspacesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceType => $composableBuilder(
    column: $table.spaceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkspacesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceType => $composableBuilder(
    column: $table.spaceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspacesTable> {
  $$WorkspacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get spaceType =>
      $composableBuilder(column: $table.spaceType, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);
}

class $$WorkspacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkspacesTable,
          WorkspaceRow,
          $$WorkspacesTableFilterComposer,
          $$WorkspacesTableOrderingComposer,
          $$WorkspacesTableAnnotationComposer,
          $$WorkspacesTableCreateCompanionBuilder,
          $$WorkspacesTableUpdateCompanionBuilder,
          (
            WorkspaceRow,
            BaseReferences<_$AppDatabase, $WorkspacesTable, WorkspaceRow>,
          ),
          WorkspaceRow,
          PrefetchHooks Function()
        > {
  $$WorkspacesTableTableManager(_$AppDatabase db, $WorkspacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> isDefault = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> spaceType = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<int> isLocal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                spaceType: spaceType,
                ownerId: ownerId,
                isLocal: isLocal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> isDefault = const Value.absent(),
                required int createdAt,
                Value<String> spaceType = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<int> isLocal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion.insert(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                spaceType: spaceType,
                ownerId: ownerId,
                isLocal: isLocal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkspacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkspacesTable,
      WorkspaceRow,
      $$WorkspacesTableFilterComposer,
      $$WorkspacesTableOrderingComposer,
      $$WorkspacesTableAnnotationComposer,
      $$WorkspacesTableCreateCompanionBuilder,
      $$WorkspacesTableUpdateCompanionBuilder,
      (
        WorkspaceRow,
        BaseReferences<_$AppDatabase, $WorkspacesTable, WorkspaceRow>,
      ),
      WorkspaceRow,
      PrefetchHooks Function()
    >;
typedef $$RecordingDraftsTableCreateCompanionBuilder =
    RecordingDraftsCompanion Function({
      Value<int> id,
      required String createdAt,
      required String segmentsJson,
      Value<int> durationMs,
    });
typedef $$RecordingDraftsTableUpdateCompanionBuilder =
    RecordingDraftsCompanion Function({
      Value<int> id,
      Value<String> createdAt,
      Value<String> segmentsJson,
      Value<int> durationMs,
    });

class $$RecordingDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingDraftsTable> {
  $$RecordingDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentsJson => $composableBuilder(
    column: $table.segmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordingDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingDraftsTable> {
  $$RecordingDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentsJson => $composableBuilder(
    column: $table.segmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingDraftsTable> {
  $$RecordingDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get segmentsJson => $composableBuilder(
    column: $table.segmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );
}

class $$RecordingDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingDraftsTable,
          RecordingDraftRow,
          $$RecordingDraftsTableFilterComposer,
          $$RecordingDraftsTableOrderingComposer,
          $$RecordingDraftsTableAnnotationComposer,
          $$RecordingDraftsTableCreateCompanionBuilder,
          $$RecordingDraftsTableUpdateCompanionBuilder,
          (
            RecordingDraftRow,
            BaseReferences<
              _$AppDatabase,
              $RecordingDraftsTable,
              RecordingDraftRow
            >,
          ),
          RecordingDraftRow,
          PrefetchHooks Function()
        > {
  $$RecordingDraftsTableTableManager(
    _$AppDatabase db,
    $RecordingDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> segmentsJson = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
              }) => RecordingDraftsCompanion(
                id: id,
                createdAt: createdAt,
                segmentsJson: segmentsJson,
                durationMs: durationMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String createdAt,
                required String segmentsJson,
                Value<int> durationMs = const Value.absent(),
              }) => RecordingDraftsCompanion.insert(
                id: id,
                createdAt: createdAt,
                segmentsJson: segmentsJson,
                durationMs: durationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordingDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingDraftsTable,
      RecordingDraftRow,
      $$RecordingDraftsTableFilterComposer,
      $$RecordingDraftsTableOrderingComposer,
      $$RecordingDraftsTableAnnotationComposer,
      $$RecordingDraftsTableCreateCompanionBuilder,
      $$RecordingDraftsTableUpdateCompanionBuilder,
      (
        RecordingDraftRow,
        BaseReferences<_$AppDatabase, $RecordingDraftsTable, RecordingDraftRow>,
      ),
      RecordingDraftRow,
      PrefetchHooks Function()
    >;
typedef $$SpaceMembersTableCreateCompanionBuilder =
    SpaceMembersCompanion Function({
      required String id,
      required String spaceId,
      required String userId,
      Value<String> role,
      Value<int> rowid,
    });
typedef $$SpaceMembersTableUpdateCompanionBuilder =
    SpaceMembersCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> userId,
      Value<String> role,
      Value<int> rowid,
    });

class $$SpaceMembersTableFilterComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpaceMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpaceMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);
}

class $$SpaceMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpaceMembersTable,
          SpaceMemberRow,
          $$SpaceMembersTableFilterComposer,
          $$SpaceMembersTableOrderingComposer,
          $$SpaceMembersTableAnnotationComposer,
          $$SpaceMembersTableCreateCompanionBuilder,
          $$SpaceMembersTableUpdateCompanionBuilder,
          (
            SpaceMemberRow,
            BaseReferences<_$AppDatabase, $SpaceMembersTable, SpaceMemberRow>,
          ),
          SpaceMemberRow,
          PrefetchHooks Function()
        > {
  $$SpaceMembersTableTableManager(_$AppDatabase db, $SpaceMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpaceMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpaceMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpaceMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceMembersCompanion(
                id: id,
                spaceId: spaceId,
                userId: userId,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String userId,
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceMembersCompanion.insert(
                id: id,
                spaceId: spaceId,
                userId: userId,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpaceMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpaceMembersTable,
      SpaceMemberRow,
      $$SpaceMembersTableFilterComposer,
      $$SpaceMembersTableOrderingComposer,
      $$SpaceMembersTableAnnotationComposer,
      $$SpaceMembersTableCreateCompanionBuilder,
      $$SpaceMembersTableUpdateCompanionBuilder,
      (
        SpaceMemberRow,
        BaseReferences<_$AppDatabase, $SpaceMembersTable, SpaceMemberRow>,
      ),
      SpaceMemberRow,
      PrefetchHooks Function()
    >;
typedef $$OrganizationsTableCreateCompanionBuilder =
    OrganizationsCompanion Function({
      required String id,
      required String name,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$OrganizationsTableUpdateCompanionBuilder =
    OrganizationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$OrganizationsTableFilterComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrganizationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrganizationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OrganizationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrganizationsTable,
          OrganizationRow,
          $$OrganizationsTableFilterComposer,
          $$OrganizationsTableOrderingComposer,
          $$OrganizationsTableAnnotationComposer,
          $$OrganizationsTableCreateCompanionBuilder,
          $$OrganizationsTableUpdateCompanionBuilder,
          (
            OrganizationRow,
            BaseReferences<_$AppDatabase, $OrganizationsTable, OrganizationRow>,
          ),
          OrganizationRow,
          PrefetchHooks Function()
        > {
  $$OrganizationsTableTableManager(_$AppDatabase db, $OrganizationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrganizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrganizationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrganizationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrganizationsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OrganizationsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrganizationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrganizationsTable,
      OrganizationRow,
      $$OrganizationsTableFilterComposer,
      $$OrganizationsTableOrderingComposer,
      $$OrganizationsTableAnnotationComposer,
      $$OrganizationsTableCreateCompanionBuilder,
      $$OrganizationsTableUpdateCompanionBuilder,
      (
        OrganizationRow,
        BaseReferences<_$AppDatabase, $OrganizationsTable, OrganizationRow>,
      ),
      OrganizationRow,
      PrefetchHooks Function()
    >;
typedef $$MatomesTableCreateCompanionBuilder =
    MatomesCompanion Function({
      required String id,
      Value<String?> spaceId,
      required String title,
      required int happenedAt,
      Value<String?> description,
      Value<String?> aggregatedSummary,
      Value<bool> summaryStale,
      required int createdAt,
      Value<int?> coreId,
      Value<int?> archivedAt,
      Value<int> rowid,
    });
typedef $$MatomesTableUpdateCompanionBuilder =
    MatomesCompanion Function({
      Value<String> id,
      Value<String?> spaceId,
      Value<String> title,
      Value<int> happenedAt,
      Value<String?> description,
      Value<String?> aggregatedSummary,
      Value<bool> summaryStale,
      Value<int> createdAt,
      Value<int?> coreId,
      Value<int?> archivedAt,
      Value<int> rowid,
    });

class $$MatomesTableFilterComposer
    extends Composer<_$AppDatabase, $MatomesTable> {
  $$MatomesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get happenedAt => $composableBuilder(
    column: $table.happenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregatedSummary => $composableBuilder(
    column: $table.aggregatedSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get summaryStale => $composableBuilder(
    column: $table.summaryStale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatomesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatomesTable> {
  $$MatomesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get happenedAt => $composableBuilder(
    column: $table.happenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregatedSummary => $composableBuilder(
    column: $table.aggregatedSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get summaryStale => $composableBuilder(
    column: $table.summaryStale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatomesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatomesTable> {
  $$MatomesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get happenedAt => $composableBuilder(
    column: $table.happenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aggregatedSummary => $composableBuilder(
    column: $table.aggregatedSummary,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get summaryStale => $composableBuilder(
    column: $table.summaryStale,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get coreId =>
      $composableBuilder(column: $table.coreId, builder: (column) => column);

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$MatomesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatomesTable,
          MatomeRow,
          $$MatomesTableFilterComposer,
          $$MatomesTableOrderingComposer,
          $$MatomesTableAnnotationComposer,
          $$MatomesTableCreateCompanionBuilder,
          $$MatomesTableUpdateCompanionBuilder,
          (MatomeRow, BaseReferences<_$AppDatabase, $MatomesTable, MatomeRow>),
          MatomeRow,
          PrefetchHooks Function()
        > {
  $$MatomesTableTableManager(_$AppDatabase db, $MatomesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatomesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> spaceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> happenedAt = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> aggregatedSummary = const Value.absent(),
                Value<bool> summaryStale = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatomesCompanion(
                id: id,
                spaceId: spaceId,
                title: title,
                happenedAt: happenedAt,
                description: description,
                aggregatedSummary: aggregatedSummary,
                summaryStale: summaryStale,
                createdAt: createdAt,
                coreId: coreId,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> spaceId = const Value.absent(),
                required String title,
                required int happenedAt,
                Value<String?> description = const Value.absent(),
                Value<String?> aggregatedSummary = const Value.absent(),
                Value<bool> summaryStale = const Value.absent(),
                required int createdAt,
                Value<int?> coreId = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatomesCompanion.insert(
                id: id,
                spaceId: spaceId,
                title: title,
                happenedAt: happenedAt,
                description: description,
                aggregatedSummary: aggregatedSummary,
                summaryStale: summaryStale,
                createdAt: createdAt,
                coreId: coreId,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatomesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatomesTable,
      MatomeRow,
      $$MatomesTableFilterComposer,
      $$MatomesTableOrderingComposer,
      $$MatomesTableAnnotationComposer,
      $$MatomesTableCreateCompanionBuilder,
      $$MatomesTableUpdateCompanionBuilder,
      (MatomeRow, BaseReferences<_$AppDatabase, $MatomesTable, MatomeRow>),
      MatomeRow,
      PrefetchHooks Function()
    >;
typedef $$ContactsTableCreateCompanionBuilder =
    ContactsCompanion Function({
      required String id,
      required String ownerId,
      required String displayName,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> company,
      Value<String?> title,
      Value<String> metadata,
      Value<String?> linkedUserId,
      required int createdAt,
      Value<int?> coreId,
      Value<int> rowid,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> displayName,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> company,
      Value<String?> title,
      Value<String> metadata,
      Value<String?> linkedUserId,
      Value<int> createdAt,
      Value<int?> coreId,
      Value<int> rowid,
    });

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedUserId => $composableBuilder(
    column: $table.linkedUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedUserId => $composableBuilder(
    column: $table.linkedUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get linkedUserId => $composableBuilder(
    column: $table.linkedUserId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get coreId =>
      $composableBuilder(column: $table.coreId, builder: (column) => column);
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTable,
          ContactRow,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (
            ContactRow,
            BaseReferences<_$AppDatabase, $ContactsTable, ContactRow>,
          ),
          ContactRow,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> company = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String?> linkedUserId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                id: id,
                ownerId: ownerId,
                displayName: displayName,
                email: email,
                phone: phone,
                company: company,
                title: title,
                metadata: metadata,
                linkedUserId: linkedUserId,
                createdAt: createdAt,
                coreId: coreId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String displayName,
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> company = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String?> linkedUserId = const Value.absent(),
                required int createdAt,
                Value<int?> coreId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                id: id,
                ownerId: ownerId,
                displayName: displayName,
                email: email,
                phone: phone,
                company: company,
                title: title,
                metadata: metadata,
                linkedUserId: linkedUserId,
                createdAt: createdAt,
                coreId: coreId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTable,
      ContactRow,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (ContactRow, BaseReferences<_$AppDatabase, $ContactsTable, ContactRow>),
      ContactRow,
      PrefetchHooks Function()
    >;
typedef $$MatomeContactsTableCreateCompanionBuilder =
    MatomeContactsCompanion Function({
      required String id,
      required String matomeId,
      required String contactId,
      Value<String> role,
      Value<int> rowid,
    });
typedef $$MatomeContactsTableUpdateCompanionBuilder =
    MatomeContactsCompanion Function({
      Value<String> id,
      Value<String> matomeId,
      Value<String> contactId,
      Value<String> role,
      Value<int> rowid,
    });

class $$MatomeContactsTableFilterComposer
    extends Composer<_$AppDatabase, $MatomeContactsTable> {
  $$MatomeContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatomeContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatomeContactsTable> {
  $$MatomeContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatomeContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatomeContactsTable> {
  $$MatomeContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matomeId =>
      $composableBuilder(column: $table.matomeId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);
}

class $$MatomeContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatomeContactsTable,
          MatomeContactRow,
          $$MatomeContactsTableFilterComposer,
          $$MatomeContactsTableOrderingComposer,
          $$MatomeContactsTableAnnotationComposer,
          $$MatomeContactsTableCreateCompanionBuilder,
          $$MatomeContactsTableUpdateCompanionBuilder,
          (
            MatomeContactRow,
            BaseReferences<
              _$AppDatabase,
              $MatomeContactsTable,
              MatomeContactRow
            >,
          ),
          MatomeContactRow,
          PrefetchHooks Function()
        > {
  $$MatomeContactsTableTableManager(
    _$AppDatabase db,
    $MatomeContactsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatomeContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatomeContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatomeContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matomeId = const Value.absent(),
                Value<String> contactId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatomeContactsCompanion(
                id: id,
                matomeId: matomeId,
                contactId: contactId,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matomeId,
                required String contactId,
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatomeContactsCompanion.insert(
                id: id,
                matomeId: matomeId,
                contactId: contactId,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatomeContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatomeContactsTable,
      MatomeContactRow,
      $$MatomeContactsTableFilterComposer,
      $$MatomeContactsTableOrderingComposer,
      $$MatomeContactsTableAnnotationComposer,
      $$MatomeContactsTableCreateCompanionBuilder,
      $$MatomeContactsTableUpdateCompanionBuilder,
      (
        MatomeContactRow,
        BaseReferences<_$AppDatabase, $MatomeContactsTable, MatomeContactRow>,
      ),
      MatomeContactRow,
      PrefetchHooks Function()
    >;
typedef $$SpaceContactsTableCreateCompanionBuilder =
    SpaceContactsCompanion Function({
      required String id,
      required String spaceId,
      required String contactId,
      Value<int> rowid,
    });
typedef $$SpaceContactsTableUpdateCompanionBuilder =
    SpaceContactsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> contactId,
      Value<int> rowid,
    });

class $$SpaceContactsTableFilterComposer
    extends Composer<_$AppDatabase, $SpaceContactsTable> {
  $$SpaceContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpaceContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $SpaceContactsTable> {
  $$SpaceContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpaceContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpaceContactsTable> {
  $$SpaceContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);
}

class $$SpaceContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpaceContactsTable,
          SpaceContactRow,
          $$SpaceContactsTableFilterComposer,
          $$SpaceContactsTableOrderingComposer,
          $$SpaceContactsTableAnnotationComposer,
          $$SpaceContactsTableCreateCompanionBuilder,
          $$SpaceContactsTableUpdateCompanionBuilder,
          (
            SpaceContactRow,
            BaseReferences<_$AppDatabase, $SpaceContactsTable, SpaceContactRow>,
          ),
          SpaceContactRow,
          PrefetchHooks Function()
        > {
  $$SpaceContactsTableTableManager(_$AppDatabase db, $SpaceContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpaceContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpaceContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpaceContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> contactId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceContactsCompanion(
                id: id,
                spaceId: spaceId,
                contactId: contactId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String contactId,
                Value<int> rowid = const Value.absent(),
              }) => SpaceContactsCompanion.insert(
                id: id,
                spaceId: spaceId,
                contactId: contactId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpaceContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpaceContactsTable,
      SpaceContactRow,
      $$SpaceContactsTableFilterComposer,
      $$SpaceContactsTableOrderingComposer,
      $$SpaceContactsTableAnnotationComposer,
      $$SpaceContactsTableCreateCompanionBuilder,
      $$SpaceContactsTableUpdateCompanionBuilder,
      (
        SpaceContactRow,
        BaseReferences<_$AppDatabase, $SpaceContactsTable, SpaceContactRow>,
      ),
      SpaceContactRow,
      PrefetchHooks Function()
    >;
typedef $$MatomeSharesTableCreateCompanionBuilder =
    MatomeSharesCompanion Function({
      required String id,
      required String matomeId,
      required String sharedWithUserId,
      Value<String> permission,
      Value<int> rowid,
    });
typedef $$MatomeSharesTableUpdateCompanionBuilder =
    MatomeSharesCompanion Function({
      Value<String> id,
      Value<String> matomeId,
      Value<String> sharedWithUserId,
      Value<String> permission,
      Value<int> rowid,
    });

class $$MatomeSharesTableFilterComposer
    extends Composer<_$AppDatabase, $MatomeSharesTable> {
  $$MatomeSharesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sharedWithUserId => $composableBuilder(
    column: $table.sharedWithUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatomeSharesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatomeSharesTable> {
  $$MatomeSharesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sharedWithUserId => $composableBuilder(
    column: $table.sharedWithUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatomeSharesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatomeSharesTable> {
  $$MatomeSharesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matomeId =>
      $composableBuilder(column: $table.matomeId, builder: (column) => column);

  GeneratedColumn<String> get sharedWithUserId => $composableBuilder(
    column: $table.sharedWithUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );
}

class $$MatomeSharesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatomeSharesTable,
          MatomeShareRow,
          $$MatomeSharesTableFilterComposer,
          $$MatomeSharesTableOrderingComposer,
          $$MatomeSharesTableAnnotationComposer,
          $$MatomeSharesTableCreateCompanionBuilder,
          $$MatomeSharesTableUpdateCompanionBuilder,
          (
            MatomeShareRow,
            BaseReferences<_$AppDatabase, $MatomeSharesTable, MatomeShareRow>,
          ),
          MatomeShareRow,
          PrefetchHooks Function()
        > {
  $$MatomeSharesTableTableManager(_$AppDatabase db, $MatomeSharesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatomeSharesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatomeSharesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatomeSharesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matomeId = const Value.absent(),
                Value<String> sharedWithUserId = const Value.absent(),
                Value<String> permission = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatomeSharesCompanion(
                id: id,
                matomeId: matomeId,
                sharedWithUserId: sharedWithUserId,
                permission: permission,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matomeId,
                required String sharedWithUserId,
                Value<String> permission = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatomeSharesCompanion.insert(
                id: id,
                matomeId: matomeId,
                sharedWithUserId: sharedWithUserId,
                permission: permission,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatomeSharesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatomeSharesTable,
      MatomeShareRow,
      $$MatomeSharesTableFilterComposer,
      $$MatomeSharesTableOrderingComposer,
      $$MatomeSharesTableAnnotationComposer,
      $$MatomeSharesTableCreateCompanionBuilder,
      $$MatomeSharesTableUpdateCompanionBuilder,
      (
        MatomeShareRow,
        BaseReferences<_$AppDatabase, $MatomeSharesTable, MatomeShareRow>,
      ),
      MatomeShareRow,
      PrefetchHooks Function()
    >;
typedef $$FileBlobsTableCreateCompanionBuilder =
    FileBlobsCompanion Function({
      required String id,
      Value<int?> coreId,
      Value<String?> storageKey,
      Value<String?> filename,
      Value<String?> contentType,
      Value<int> byteSize,
      Value<String?> checksumSha256,
      required String mediaType,
      Value<int?> duration,
      Value<String> uploadState,
      Value<int> uploadGeneration,
      Value<int?> uploadedAt,
      Value<String?> multipartContext,
      Value<String?> localPath,
      Value<String?> wrappedFek,
      Value<String?> fileNoncePrefix,
      Value<bool> isDirty,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$FileBlobsTableUpdateCompanionBuilder =
    FileBlobsCompanion Function({
      Value<String> id,
      Value<int?> coreId,
      Value<String?> storageKey,
      Value<String?> filename,
      Value<String?> contentType,
      Value<int> byteSize,
      Value<String?> checksumSha256,
      Value<String> mediaType,
      Value<int?> duration,
      Value<String> uploadState,
      Value<int> uploadGeneration,
      Value<int?> uploadedAt,
      Value<String?> multipartContext,
      Value<String?> localPath,
      Value<String?> wrappedFek,
      Value<String?> fileNoncePrefix,
      Value<bool> isDirty,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$FileBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $FileBlobsTable> {
  $$FileBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksumSha256 => $composableBuilder(
    column: $table.checksumSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadGeneration => $composableBuilder(
    column: $table.uploadGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get multipartContext => $composableBuilder(
    column: $table.multipartContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrappedFek => $composableBuilder(
    column: $table.wrappedFek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileNoncePrefix => $composableBuilder(
    column: $table.fileNoncePrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $FileBlobsTable> {
  $$FileBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksumSha256 => $composableBuilder(
    column: $table.checksumSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadGeneration => $composableBuilder(
    column: $table.uploadGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get multipartContext => $composableBuilder(
    column: $table.multipartContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrappedFek => $composableBuilder(
    column: $table.wrappedFek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileNoncePrefix => $composableBuilder(
    column: $table.fileNoncePrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileBlobsTable> {
  $$FileBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get coreId =>
      $composableBuilder(column: $table.coreId, builder: (column) => column);

  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get checksumSha256 => $composableBuilder(
    column: $table.checksumSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uploadGeneration => $composableBuilder(
    column: $table.uploadGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get multipartContext => $composableBuilder(
    column: $table.multipartContext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get wrappedFek => $composableBuilder(
    column: $table.wrappedFek,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileNoncePrefix => $composableBuilder(
    column: $table.fileNoncePrefix,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FileBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileBlobsTable,
          FileBlobRow,
          $$FileBlobsTableFilterComposer,
          $$FileBlobsTableOrderingComposer,
          $$FileBlobsTableAnnotationComposer,
          $$FileBlobsTableCreateCompanionBuilder,
          $$FileBlobsTableUpdateCompanionBuilder,
          (
            FileBlobRow,
            BaseReferences<_$AppDatabase, $FileBlobsTable, FileBlobRow>,
          ),
          FileBlobRow,
          PrefetchHooks Function()
        > {
  $$FileBlobsTableTableManager(_$AppDatabase db, $FileBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<String?> storageKey = const Value.absent(),
                Value<String?> filename = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> checksumSha256 = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> uploadGeneration = const Value.absent(),
                Value<int?> uploadedAt = const Value.absent(),
                Value<String?> multipartContext = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> wrappedFek = const Value.absent(),
                Value<String?> fileNoncePrefix = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileBlobsCompanion(
                id: id,
                coreId: coreId,
                storageKey: storageKey,
                filename: filename,
                contentType: contentType,
                byteSize: byteSize,
                checksumSha256: checksumSha256,
                mediaType: mediaType,
                duration: duration,
                uploadState: uploadState,
                uploadGeneration: uploadGeneration,
                uploadedAt: uploadedAt,
                multipartContext: multipartContext,
                localPath: localPath,
                wrappedFek: wrappedFek,
                fileNoncePrefix: fileNoncePrefix,
                isDirty: isDirty,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> coreId = const Value.absent(),
                Value<String?> storageKey = const Value.absent(),
                Value<String?> filename = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> checksumSha256 = const Value.absent(),
                required String mediaType,
                Value<int?> duration = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> uploadGeneration = const Value.absent(),
                Value<int?> uploadedAt = const Value.absent(),
                Value<String?> multipartContext = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> wrappedFek = const Value.absent(),
                Value<String?> fileNoncePrefix = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FileBlobsCompanion.insert(
                id: id,
                coreId: coreId,
                storageKey: storageKey,
                filename: filename,
                contentType: contentType,
                byteSize: byteSize,
                checksumSha256: checksumSha256,
                mediaType: mediaType,
                duration: duration,
                uploadState: uploadState,
                uploadGeneration: uploadGeneration,
                uploadedAt: uploadedAt,
                multipartContext: multipartContext,
                localPath: localPath,
                wrappedFek: wrappedFek,
                fileNoncePrefix: fileNoncePrefix,
                isDirty: isDirty,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileBlobsTable,
      FileBlobRow,
      $$FileBlobsTableFilterComposer,
      $$FileBlobsTableOrderingComposer,
      $$FileBlobsTableAnnotationComposer,
      $$FileBlobsTableCreateCompanionBuilder,
      $$FileBlobsTableUpdateCompanionBuilder,
      (
        FileBlobRow,
        BaseReferences<_$AppDatabase, $FileBlobsTable, FileBlobRow>,
      ),
      FileBlobRow,
      PrefetchHooks Function()
    >;
typedef $$TextContentsTableCreateCompanionBuilder =
    TextContentsCompanion Function({
      required String id,
      Value<int?> coreId,
      required String body,
      Value<bool> isDirty,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TextContentsTableUpdateCompanionBuilder =
    TextContentsCompanion Function({
      Value<String> id,
      Value<int?> coreId,
      Value<String> body,
      Value<bool> isDirty,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TextContentsTableFilterComposer
    extends Composer<_$AppDatabase, $TextContentsTable> {
  $$TextContentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TextContentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TextContentsTable> {
  $$TextContentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TextContentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TextContentsTable> {
  $$TextContentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get coreId =>
      $composableBuilder(column: $table.coreId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TextContentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TextContentsTable,
          TextContentRow,
          $$TextContentsTableFilterComposer,
          $$TextContentsTableOrderingComposer,
          $$TextContentsTableAnnotationComposer,
          $$TextContentsTableCreateCompanionBuilder,
          $$TextContentsTableUpdateCompanionBuilder,
          (
            TextContentRow,
            BaseReferences<_$AppDatabase, $TextContentsTable, TextContentRow>,
          ),
          TextContentRow,
          PrefetchHooks Function()
        > {
  $$TextContentsTableTableManager(_$AppDatabase db, $TextContentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextContentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextContentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextContentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextContentsCompanion(
                id: id,
                coreId: coreId,
                body: body,
                isDirty: isDirty,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> coreId = const Value.absent(),
                required String body,
                Value<bool> isDirty = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TextContentsCompanion.insert(
                id: id,
                coreId: coreId,
                body: body,
                isDirty: isDirty,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TextContentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TextContentsTable,
      TextContentRow,
      $$TextContentsTableFilterComposer,
      $$TextContentsTableOrderingComposer,
      $$TextContentsTableAnnotationComposer,
      $$TextContentsTableCreateCompanionBuilder,
      $$TextContentsTableUpdateCompanionBuilder,
      (
        TextContentRow,
        BaseReferences<_$AppDatabase, $TextContentsTable, TextContentRow>,
      ),
      TextContentRow,
      PrefetchHooks Function()
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      Value<int?> coreId,
      required String ownerId,
      required String clientId,
      Value<String?> clientFingerprint,
      Value<String?> workspaceId,
      Value<String?> matomeId,
      Value<int?> position,
      required String itemType,
      Value<String> title,
      Value<String?> notes,
      Value<String> metadata,
      Value<String> processingState,
      Value<String?> processingRunId,
      Value<int> sourceRevision,
      Value<int?> processingConfigRevision,
      Value<String> processingOutputs,
      Value<String?> processingError,
      Value<String?> processingErrorCode,
      Value<String?> fileBlobId,
      Value<String?> textContentId,
      Value<bool> isDirty,
      Value<String> syncState,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<int?> coreId,
      Value<String> ownerId,
      Value<String> clientId,
      Value<String?> clientFingerprint,
      Value<String?> workspaceId,
      Value<String?> matomeId,
      Value<int?> position,
      Value<String> itemType,
      Value<String> title,
      Value<String?> notes,
      Value<String> metadata,
      Value<String> processingState,
      Value<String?> processingRunId,
      Value<int> sourceRevision,
      Value<int?> processingConfigRevision,
      Value<String> processingOutputs,
      Value<String?> processingError,
      Value<String?> processingErrorCode,
      Value<String?> fileBlobId,
      Value<String?> textContentId,
      Value<bool> isDirty,
      Value<String> syncState,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientFingerprint => $composableBuilder(
    column: $table.clientFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingRunId => $composableBuilder(
    column: $table.processingRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processingConfigRevision => $composableBuilder(
    column: $table.processingConfigRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingOutputs => $composableBuilder(
    column: $table.processingOutputs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingError => $composableBuilder(
    column: $table.processingError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingErrorCode => $composableBuilder(
    column: $table.processingErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileBlobId => $composableBuilder(
    column: $table.fileBlobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContentId => $composableBuilder(
    column: $table.textContentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientFingerprint => $composableBuilder(
    column: $table.clientFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingRunId => $composableBuilder(
    column: $table.processingRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processingConfigRevision => $composableBuilder(
    column: $table.processingConfigRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingOutputs => $composableBuilder(
    column: $table.processingOutputs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingError => $composableBuilder(
    column: $table.processingError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingErrorCode => $composableBuilder(
    column: $table.processingErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileBlobId => $composableBuilder(
    column: $table.fileBlobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContentId => $composableBuilder(
    column: $table.textContentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get coreId =>
      $composableBuilder(column: $table.coreId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get clientFingerprint => $composableBuilder(
    column: $table.clientFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get matomeId =>
      $composableBuilder(column: $table.matomeId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get processingState => $composableBuilder(
    column: $table.processingState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processingRunId => $composableBuilder(
    column: $table.processingRunId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get processingConfigRevision => $composableBuilder(
    column: $table.processingConfigRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processingOutputs => $composableBuilder(
    column: $table.processingOutputs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processingError => $composableBuilder(
    column: $table.processingError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processingErrorCode => $composableBuilder(
    column: $table.processingErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileBlobId => $composableBuilder(
    column: $table.fileBlobId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textContentId => $composableBuilder(
    column: $table.textContentId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          ItemRow,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (ItemRow, BaseReferences<_$AppDatabase, $ItemsTable, ItemRow>),
          ItemRow,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String?> clientFingerprint = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String?> matomeId = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String> processingState = const Value.absent(),
                Value<String?> processingRunId = const Value.absent(),
                Value<int> sourceRevision = const Value.absent(),
                Value<int?> processingConfigRevision = const Value.absent(),
                Value<String> processingOutputs = const Value.absent(),
                Value<String?> processingError = const Value.absent(),
                Value<String?> processingErrorCode = const Value.absent(),
                Value<String?> fileBlobId = const Value.absent(),
                Value<String?> textContentId = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                coreId: coreId,
                ownerId: ownerId,
                clientId: clientId,
                clientFingerprint: clientFingerprint,
                workspaceId: workspaceId,
                matomeId: matomeId,
                position: position,
                itemType: itemType,
                title: title,
                notes: notes,
                metadata: metadata,
                processingState: processingState,
                processingRunId: processingRunId,
                sourceRevision: sourceRevision,
                processingConfigRevision: processingConfigRevision,
                processingOutputs: processingOutputs,
                processingError: processingError,
                processingErrorCode: processingErrorCode,
                fileBlobId: fileBlobId,
                textContentId: textContentId,
                isDirty: isDirty,
                syncState: syncState,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> coreId = const Value.absent(),
                required String ownerId,
                required String clientId,
                Value<String?> clientFingerprint = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String?> matomeId = const Value.absent(),
                Value<int?> position = const Value.absent(),
                required String itemType,
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String> processingState = const Value.absent(),
                Value<String?> processingRunId = const Value.absent(),
                Value<int> sourceRevision = const Value.absent(),
                Value<int?> processingConfigRevision = const Value.absent(),
                Value<String> processingOutputs = const Value.absent(),
                Value<String?> processingError = const Value.absent(),
                Value<String?> processingErrorCode = const Value.absent(),
                Value<String?> fileBlobId = const Value.absent(),
                Value<String?> textContentId = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                coreId: coreId,
                ownerId: ownerId,
                clientId: clientId,
                clientFingerprint: clientFingerprint,
                workspaceId: workspaceId,
                matomeId: matomeId,
                position: position,
                itemType: itemType,
                title: title,
                notes: notes,
                metadata: metadata,
                processingState: processingState,
                processingRunId: processingRunId,
                sourceRevision: sourceRevision,
                processingConfigRevision: processingConfigRevision,
                processingOutputs: processingOutputs,
                processingError: processingError,
                processingErrorCode: processingErrorCode,
                fileBlobId: fileBlobId,
                textContentId: textContentId,
                isDirty: isDirty,
                syncState: syncState,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      ItemRow,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (ItemRow, BaseReferences<_$AppDatabase, $ItemsTable, ItemRow>),
      ItemRow,
      PrefetchHooks Function()
    >;
typedef $$ItemContactsTableCreateCompanionBuilder =
    ItemContactsCompanion Function({
      required String id,
      required String itemId,
      required String contactId,
      Value<int> rowid,
    });
typedef $$ItemContactsTableUpdateCompanionBuilder =
    ItemContactsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> contactId,
      Value<int> rowid,
    });

class $$ItemContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemContactsTable> {
  $$ItemContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemContactsTable> {
  $$ItemContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemContactsTable> {
  $$ItemContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);
}

class $$ItemContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemContactsTable,
          ItemContactRow,
          $$ItemContactsTableFilterComposer,
          $$ItemContactsTableOrderingComposer,
          $$ItemContactsTableAnnotationComposer,
          $$ItemContactsTableCreateCompanionBuilder,
          $$ItemContactsTableUpdateCompanionBuilder,
          (
            ItemContactRow,
            BaseReferences<_$AppDatabase, $ItemContactsTable, ItemContactRow>,
          ),
          ItemContactRow,
          PrefetchHooks Function()
        > {
  $$ItemContactsTableTableManager(_$AppDatabase db, $ItemContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> contactId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemContactsCompanion(
                id: id,
                itemId: itemId,
                contactId: contactId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String contactId,
                Value<int> rowid = const Value.absent(),
              }) => ItemContactsCompanion.insert(
                id: id,
                itemId: itemId,
                contactId: contactId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemContactsTable,
      ItemContactRow,
      $$ItemContactsTableFilterComposer,
      $$ItemContactsTableOrderingComposer,
      $$ItemContactsTableAnnotationComposer,
      $$ItemContactsTableCreateCompanionBuilder,
      $$ItemContactsTableUpdateCompanionBuilder,
      (
        ItemContactRow,
        BaseReferences<_$AppDatabase, $ItemContactsTable, ItemContactRow>,
      ),
      ItemContactRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db, _db.workspaces);
  $$RecordingDraftsTableTableManager get recordingDrafts =>
      $$RecordingDraftsTableTableManager(_db, _db.recordingDrafts);
  $$SpaceMembersTableTableManager get spaceMembers =>
      $$SpaceMembersTableTableManager(_db, _db.spaceMembers);
  $$OrganizationsTableTableManager get organizations =>
      $$OrganizationsTableTableManager(_db, _db.organizations);
  $$MatomesTableTableManager get matomes =>
      $$MatomesTableTableManager(_db, _db.matomes);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$MatomeContactsTableTableManager get matomeContacts =>
      $$MatomeContactsTableTableManager(_db, _db.matomeContacts);
  $$SpaceContactsTableTableManager get spaceContacts =>
      $$SpaceContactsTableTableManager(_db, _db.spaceContacts);
  $$MatomeSharesTableTableManager get matomeShares =>
      $$MatomeSharesTableTableManager(_db, _db.matomeShares);
  $$FileBlobsTableTableManager get fileBlobs =>
      $$FileBlobsTableTableManager(_db, _db.fileBlobs);
  $$TextContentsTableTableManager get textContents =>
      $$TextContentsTableTableManager(_db, _db.textContents);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$ItemContactsTableTableManager get itemContacts =>
      $$ItemContactsTableTableManager(_db, _db.itemContacts);
}
