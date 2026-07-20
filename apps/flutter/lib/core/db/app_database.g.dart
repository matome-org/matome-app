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
  static const VerificationMeta _segmentHandlesJsonMeta =
      const VerificationMeta('segmentHandlesJson');
  @override
  late final GeneratedColumn<String> segmentHandlesJson =
      GeneratedColumn<String>(
        'segment_handles_json',
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('legacy'),
  );
  static const VerificationMeta _captureKindMeta = const VerificationMeta(
    'captureKind',
  );
  @override
  late final GeneratedColumn<String> captureKind = GeneratedColumn<String>(
    'capture_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('microphone'),
  );
  static const VerificationMeta _backendMeta = const VerificationMeta(
    'backend',
  );
  @override
  late final GeneratedColumn<String> backend = GeneratedColumn<String>(
    'backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('record'),
  );
  static const VerificationMeta _stagingHandleMeta = const VerificationMeta(
    'stagingHandle',
  );
  @override
  late final GeneratedColumn<String> stagingHandle = GeneratedColumn<String>(
    'staging_handle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codecMeta = const VerificationMeta('codec');
  @override
  late final GeneratedColumn<String> codec = GeneratedColumn<String>(
    'codec',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('aac_lc'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('paused'),
  );
  static const VerificationMeta _heartbeatAtMeta = const VerificationMeta(
    'heartbeatAt',
  );
  @override
  late final GeneratedColumn<String> heartbeatAt = GeneratedColumn<String>(
    'heartbeat_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    segmentHandlesJson,
    durationMs,
    sessionId,
    captureKind,
    backend,
    stagingHandle,
    codec,
    state,
    heartbeatAt,
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
    if (data.containsKey('segment_handles_json')) {
      context.handle(
        _segmentHandlesJsonMeta,
        segmentHandlesJson.isAcceptableOrUnknown(
          data['segment_handles_json']!,
          _segmentHandlesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentHandlesJsonMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('capture_kind')) {
      context.handle(
        _captureKindMeta,
        captureKind.isAcceptableOrUnknown(
          data['capture_kind']!,
          _captureKindMeta,
        ),
      );
    }
    if (data.containsKey('backend')) {
      context.handle(
        _backendMeta,
        backend.isAcceptableOrUnknown(data['backend']!, _backendMeta),
      );
    }
    if (data.containsKey('staging_handle')) {
      context.handle(
        _stagingHandleMeta,
        stagingHandle.isAcceptableOrUnknown(
          data['staging_handle']!,
          _stagingHandleMeta,
        ),
      );
    }
    if (data.containsKey('codec')) {
      context.handle(
        _codecMeta,
        codec.isAcceptableOrUnknown(data['codec']!, _codecMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('heartbeat_at')) {
      context.handle(
        _heartbeatAtMeta,
        heartbeatAt.isAcceptableOrUnknown(
          data['heartbeat_at']!,
          _heartbeatAtMeta,
        ),
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
      segmentHandlesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_handles_json'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      captureKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_kind'],
      )!,
      backend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend'],
      )!,
      stagingHandle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staging_handle'],
      ),
      codec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      heartbeatAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heartbeat_at'],
      ),
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
  final String segmentHandlesJson;
  final int durationMs;
  final String sessionId;
  final String captureKind;
  final String backend;
  final String? stagingHandle;
  final String codec;
  final String state;
  final String? heartbeatAt;
  const RecordingDraftRow({
    required this.id,
    required this.createdAt,
    required this.segmentHandlesJson,
    required this.durationMs,
    required this.sessionId,
    required this.captureKind,
    required this.backend,
    this.stagingHandle,
    required this.codec,
    required this.state,
    this.heartbeatAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['segment_handles_json'] = Variable<String>(segmentHandlesJson);
    map['duration_ms'] = Variable<int>(durationMs);
    map['session_id'] = Variable<String>(sessionId);
    map['capture_kind'] = Variable<String>(captureKind);
    map['backend'] = Variable<String>(backend);
    if (!nullToAbsent || stagingHandle != null) {
      map['staging_handle'] = Variable<String>(stagingHandle);
    }
    map['codec'] = Variable<String>(codec);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || heartbeatAt != null) {
      map['heartbeat_at'] = Variable<String>(heartbeatAt);
    }
    return map;
  }

  RecordingDraftsCompanion toCompanion(bool nullToAbsent) {
    return RecordingDraftsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      segmentHandlesJson: Value(segmentHandlesJson),
      durationMs: Value(durationMs),
      sessionId: Value(sessionId),
      captureKind: Value(captureKind),
      backend: Value(backend),
      stagingHandle: stagingHandle == null && nullToAbsent
          ? const Value.absent()
          : Value(stagingHandle),
      codec: Value(codec),
      state: Value(state),
      heartbeatAt: heartbeatAt == null && nullToAbsent
          ? const Value.absent()
          : Value(heartbeatAt),
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
      segmentHandlesJson: serializer.fromJson<String>(
        json['segmentHandlesJson'],
      ),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      captureKind: serializer.fromJson<String>(json['captureKind']),
      backend: serializer.fromJson<String>(json['backend']),
      stagingHandle: serializer.fromJson<String?>(json['stagingHandle']),
      codec: serializer.fromJson<String>(json['codec']),
      state: serializer.fromJson<String>(json['state']),
      heartbeatAt: serializer.fromJson<String?>(json['heartbeatAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'segmentHandlesJson': serializer.toJson<String>(segmentHandlesJson),
      'durationMs': serializer.toJson<int>(durationMs),
      'sessionId': serializer.toJson<String>(sessionId),
      'captureKind': serializer.toJson<String>(captureKind),
      'backend': serializer.toJson<String>(backend),
      'stagingHandle': serializer.toJson<String?>(stagingHandle),
      'codec': serializer.toJson<String>(codec),
      'state': serializer.toJson<String>(state),
      'heartbeatAt': serializer.toJson<String?>(heartbeatAt),
    };
  }

  RecordingDraftRow copyWith({
    int? id,
    String? createdAt,
    String? segmentHandlesJson,
    int? durationMs,
    String? sessionId,
    String? captureKind,
    String? backend,
    Value<String?> stagingHandle = const Value.absent(),
    String? codec,
    String? state,
    Value<String?> heartbeatAt = const Value.absent(),
  }) => RecordingDraftRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    segmentHandlesJson: segmentHandlesJson ?? this.segmentHandlesJson,
    durationMs: durationMs ?? this.durationMs,
    sessionId: sessionId ?? this.sessionId,
    captureKind: captureKind ?? this.captureKind,
    backend: backend ?? this.backend,
    stagingHandle: stagingHandle.present
        ? stagingHandle.value
        : this.stagingHandle,
    codec: codec ?? this.codec,
    state: state ?? this.state,
    heartbeatAt: heartbeatAt.present ? heartbeatAt.value : this.heartbeatAt,
  );
  RecordingDraftRow copyWithCompanion(RecordingDraftsCompanion data) {
    return RecordingDraftRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      segmentHandlesJson: data.segmentHandlesJson.present
          ? data.segmentHandlesJson.value
          : this.segmentHandlesJson,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      captureKind: data.captureKind.present
          ? data.captureKind.value
          : this.captureKind,
      backend: data.backend.present ? data.backend.value : this.backend,
      stagingHandle: data.stagingHandle.present
          ? data.stagingHandle.value
          : this.stagingHandle,
      codec: data.codec.present ? data.codec.value : this.codec,
      state: data.state.present ? data.state.value : this.state,
      heartbeatAt: data.heartbeatAt.present
          ? data.heartbeatAt.value
          : this.heartbeatAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingDraftRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('segmentHandlesJson: $segmentHandlesJson, ')
          ..write('durationMs: $durationMs, ')
          ..write('sessionId: $sessionId, ')
          ..write('captureKind: $captureKind, ')
          ..write('backend: $backend, ')
          ..write('stagingHandle: $stagingHandle, ')
          ..write('codec: $codec, ')
          ..write('state: $state, ')
          ..write('heartbeatAt: $heartbeatAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    segmentHandlesJson,
    durationMs,
    sessionId,
    captureKind,
    backend,
    stagingHandle,
    codec,
    state,
    heartbeatAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingDraftRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.segmentHandlesJson == this.segmentHandlesJson &&
          other.durationMs == this.durationMs &&
          other.sessionId == this.sessionId &&
          other.captureKind == this.captureKind &&
          other.backend == this.backend &&
          other.stagingHandle == this.stagingHandle &&
          other.codec == this.codec &&
          other.state == this.state &&
          other.heartbeatAt == this.heartbeatAt);
}

class RecordingDraftsCompanion extends UpdateCompanion<RecordingDraftRow> {
  final Value<int> id;
  final Value<String> createdAt;
  final Value<String> segmentHandlesJson;
  final Value<int> durationMs;
  final Value<String> sessionId;
  final Value<String> captureKind;
  final Value<String> backend;
  final Value<String?> stagingHandle;
  final Value<String> codec;
  final Value<String> state;
  final Value<String?> heartbeatAt;
  const RecordingDraftsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.segmentHandlesJson = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.captureKind = const Value.absent(),
    this.backend = const Value.absent(),
    this.stagingHandle = const Value.absent(),
    this.codec = const Value.absent(),
    this.state = const Value.absent(),
    this.heartbeatAt = const Value.absent(),
  });
  RecordingDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String createdAt,
    required String segmentHandlesJson,
    this.durationMs = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.captureKind = const Value.absent(),
    this.backend = const Value.absent(),
    this.stagingHandle = const Value.absent(),
    this.codec = const Value.absent(),
    this.state = const Value.absent(),
    this.heartbeatAt = const Value.absent(),
  }) : createdAt = Value(createdAt),
       segmentHandlesJson = Value(segmentHandlesJson);
  static Insertable<RecordingDraftRow> custom({
    Expression<int>? id,
    Expression<String>? createdAt,
    Expression<String>? segmentHandlesJson,
    Expression<int>? durationMs,
    Expression<String>? sessionId,
    Expression<String>? captureKind,
    Expression<String>? backend,
    Expression<String>? stagingHandle,
    Expression<String>? codec,
    Expression<String>? state,
    Expression<String>? heartbeatAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (segmentHandlesJson != null)
        'segment_handles_json': segmentHandlesJson,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sessionId != null) 'session_id': sessionId,
      if (captureKind != null) 'capture_kind': captureKind,
      if (backend != null) 'backend': backend,
      if (stagingHandle != null) 'staging_handle': stagingHandle,
      if (codec != null) 'codec': codec,
      if (state != null) 'state': state,
      if (heartbeatAt != null) 'heartbeat_at': heartbeatAt,
    });
  }

  RecordingDraftsCompanion copyWith({
    Value<int>? id,
    Value<String>? createdAt,
    Value<String>? segmentHandlesJson,
    Value<int>? durationMs,
    Value<String>? sessionId,
    Value<String>? captureKind,
    Value<String>? backend,
    Value<String?>? stagingHandle,
    Value<String>? codec,
    Value<String>? state,
    Value<String?>? heartbeatAt,
  }) {
    return RecordingDraftsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      segmentHandlesJson: segmentHandlesJson ?? this.segmentHandlesJson,
      durationMs: durationMs ?? this.durationMs,
      sessionId: sessionId ?? this.sessionId,
      captureKind: captureKind ?? this.captureKind,
      backend: backend ?? this.backend,
      stagingHandle: stagingHandle ?? this.stagingHandle,
      codec: codec ?? this.codec,
      state: state ?? this.state,
      heartbeatAt: heartbeatAt ?? this.heartbeatAt,
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
    if (segmentHandlesJson.present) {
      map['segment_handles_json'] = Variable<String>(segmentHandlesJson.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (captureKind.present) {
      map['capture_kind'] = Variable<String>(captureKind.value);
    }
    if (backend.present) {
      map['backend'] = Variable<String>(backend.value);
    }
    if (stagingHandle.present) {
      map['staging_handle'] = Variable<String>(stagingHandle.value);
    }
    if (codec.present) {
      map['codec'] = Variable<String>(codec.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (heartbeatAt.present) {
      map['heartbeat_at'] = Variable<String>(heartbeatAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingDraftsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('segmentHandlesJson: $segmentHandlesJson, ')
          ..write('durationMs: $durationMs, ')
          ..write('sessionId: $sessionId, ')
          ..write('captureKind: $captureKind, ')
          ..write('backend: $backend, ')
          ..write('stagingHandle: $stagingHandle, ')
          ..write('codec: $codec, ')
          ..write('state: $state, ')
          ..write('heartbeatAt: $heartbeatAt')
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
  static const VerificationMeta _originalExtensionMeta = const VerificationMeta(
    'originalExtension',
  );
  @override
  late final GeneratedColumn<String> originalExtension =
      GeneratedColumn<String>(
        'original_extension',
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
  static const VerificationMeta _openPolicyMeta = const VerificationMeta(
    'openPolicy',
  );
  @override
  late final GeneratedColumn<String> openPolicy = GeneratedColumn<String>(
    'open_policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('download_only'),
  );
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blobStateMeta = const VerificationMeta(
    'blobState',
  );
  @override
  late final GeneratedColumn<String> blobState = GeneratedColumn<String>(
    'blob_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('missing'),
  );
  static const VerificationMeta _cipherFormatMeta = const VerificationMeta(
    'cipherFormat',
  );
  @override
  late final GeneratedColumn<String> cipherFormat = GeneratedColumn<String>(
    'cipher_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mec1'),
  );
  static const VerificationMeta _cipherVersionMeta = const VerificationMeta(
    'cipherVersion',
  );
  @override
  late final GeneratedColumn<int> cipherVersion = GeneratedColumn<int>(
    'cipher_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    originalExtension,
    contentType,
    byteSize,
    checksumSha256,
    mediaType,
    duration,
    uploadState,
    uploadGeneration,
    uploadedAt,
    multipartContext,
    openPolicy,
    blobId,
    blobState,
    cipherFormat,
    cipherVersion,
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
    if (data.containsKey('original_extension')) {
      context.handle(
        _originalExtensionMeta,
        originalExtension.isAcceptableOrUnknown(
          data['original_extension']!,
          _originalExtensionMeta,
        ),
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
    if (data.containsKey('open_policy')) {
      context.handle(
        _openPolicyMeta,
        openPolicy.isAcceptableOrUnknown(data['open_policy']!, _openPolicyMeta),
      );
    }
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    }
    if (data.containsKey('blob_state')) {
      context.handle(
        _blobStateMeta,
        blobState.isAcceptableOrUnknown(data['blob_state']!, _blobStateMeta),
      );
    }
    if (data.containsKey('cipher_format')) {
      context.handle(
        _cipherFormatMeta,
        cipherFormat.isAcceptableOrUnknown(
          data['cipher_format']!,
          _cipherFormatMeta,
        ),
      );
    }
    if (data.containsKey('cipher_version')) {
      context.handle(
        _cipherVersionMeta,
        cipherVersion.isAcceptableOrUnknown(
          data['cipher_version']!,
          _cipherVersionMeta,
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
      originalExtension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_extension'],
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
      openPolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}open_policy'],
      )!,
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      ),
      blobState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_state'],
      )!,
      cipherFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cipher_format'],
      )!,
      cipherVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cipher_version'],
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
  $FileBlobsTable createAlias(String alias) {
    return $FileBlobsTable(attachedDatabase, alias);
  }
}

class FileBlobRow extends DataClass implements Insertable<FileBlobRow> {
  final String id;
  final int? coreId;
  final String? storageKey;
  final String? filename;
  final String? originalExtension;
  final String? contentType;
  final int byteSize;
  final String? checksumSha256;
  final String mediaType;
  final int? duration;
  final String uploadState;
  final int uploadGeneration;
  final int? uploadedAt;
  final String? multipartContext;
  final String openPolicy;
  final String? blobId;
  final String blobState;
  final String cipherFormat;
  final int cipherVersion;
  final bool isDirty;
  final int createdAt;
  final int updatedAt;
  const FileBlobRow({
    required this.id,
    this.coreId,
    this.storageKey,
    this.filename,
    this.originalExtension,
    this.contentType,
    required this.byteSize,
    this.checksumSha256,
    required this.mediaType,
    this.duration,
    required this.uploadState,
    required this.uploadGeneration,
    this.uploadedAt,
    this.multipartContext,
    required this.openPolicy,
    this.blobId,
    required this.blobState,
    required this.cipherFormat,
    required this.cipherVersion,
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
    if (!nullToAbsent || originalExtension != null) {
      map['original_extension'] = Variable<String>(originalExtension);
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
    map['open_policy'] = Variable<String>(openPolicy);
    if (!nullToAbsent || blobId != null) {
      map['blob_id'] = Variable<String>(blobId);
    }
    map['blob_state'] = Variable<String>(blobState);
    map['cipher_format'] = Variable<String>(cipherFormat);
    map['cipher_version'] = Variable<int>(cipherVersion);
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
      originalExtension: originalExtension == null && nullToAbsent
          ? const Value.absent()
          : Value(originalExtension),
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
      openPolicy: Value(openPolicy),
      blobId: blobId == null && nullToAbsent
          ? const Value.absent()
          : Value(blobId),
      blobState: Value(blobState),
      cipherFormat: Value(cipherFormat),
      cipherVersion: Value(cipherVersion),
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
      originalExtension: serializer.fromJson<String?>(
        json['originalExtension'],
      ),
      contentType: serializer.fromJson<String?>(json['contentType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      checksumSha256: serializer.fromJson<String?>(json['checksumSha256']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      duration: serializer.fromJson<int?>(json['duration']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      uploadGeneration: serializer.fromJson<int>(json['uploadGeneration']),
      uploadedAt: serializer.fromJson<int?>(json['uploadedAt']),
      multipartContext: serializer.fromJson<String?>(json['multipartContext']),
      openPolicy: serializer.fromJson<String>(json['openPolicy']),
      blobId: serializer.fromJson<String?>(json['blobId']),
      blobState: serializer.fromJson<String>(json['blobState']),
      cipherFormat: serializer.fromJson<String>(json['cipherFormat']),
      cipherVersion: serializer.fromJson<int>(json['cipherVersion']),
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
      'originalExtension': serializer.toJson<String?>(originalExtension),
      'contentType': serializer.toJson<String?>(contentType),
      'byteSize': serializer.toJson<int>(byteSize),
      'checksumSha256': serializer.toJson<String?>(checksumSha256),
      'mediaType': serializer.toJson<String>(mediaType),
      'duration': serializer.toJson<int?>(duration),
      'uploadState': serializer.toJson<String>(uploadState),
      'uploadGeneration': serializer.toJson<int>(uploadGeneration),
      'uploadedAt': serializer.toJson<int?>(uploadedAt),
      'multipartContext': serializer.toJson<String?>(multipartContext),
      'openPolicy': serializer.toJson<String>(openPolicy),
      'blobId': serializer.toJson<String?>(blobId),
      'blobState': serializer.toJson<String>(blobState),
      'cipherFormat': serializer.toJson<String>(cipherFormat),
      'cipherVersion': serializer.toJson<int>(cipherVersion),
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
    Value<String?> originalExtension = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    int? byteSize,
    Value<String?> checksumSha256 = const Value.absent(),
    String? mediaType,
    Value<int?> duration = const Value.absent(),
    String? uploadState,
    int? uploadGeneration,
    Value<int?> uploadedAt = const Value.absent(),
    Value<String?> multipartContext = const Value.absent(),
    String? openPolicy,
    Value<String?> blobId = const Value.absent(),
    String? blobState,
    String? cipherFormat,
    int? cipherVersion,
    bool? isDirty,
    int? createdAt,
    int? updatedAt,
  }) => FileBlobRow(
    id: id ?? this.id,
    coreId: coreId.present ? coreId.value : this.coreId,
    storageKey: storageKey.present ? storageKey.value : this.storageKey,
    filename: filename.present ? filename.value : this.filename,
    originalExtension: originalExtension.present
        ? originalExtension.value
        : this.originalExtension,
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
    openPolicy: openPolicy ?? this.openPolicy,
    blobId: blobId.present ? blobId.value : this.blobId,
    blobState: blobState ?? this.blobState,
    cipherFormat: cipherFormat ?? this.cipherFormat,
    cipherVersion: cipherVersion ?? this.cipherVersion,
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
      originalExtension: data.originalExtension.present
          ? data.originalExtension.value
          : this.originalExtension,
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
      openPolicy: data.openPolicy.present
          ? data.openPolicy.value
          : this.openPolicy,
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      blobState: data.blobState.present ? data.blobState.value : this.blobState,
      cipherFormat: data.cipherFormat.present
          ? data.cipherFormat.value
          : this.cipherFormat,
      cipherVersion: data.cipherVersion.present
          ? data.cipherVersion.value
          : this.cipherVersion,
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
          ..write('originalExtension: $originalExtension, ')
          ..write('contentType: $contentType, ')
          ..write('byteSize: $byteSize, ')
          ..write('checksumSha256: $checksumSha256, ')
          ..write('mediaType: $mediaType, ')
          ..write('duration: $duration, ')
          ..write('uploadState: $uploadState, ')
          ..write('uploadGeneration: $uploadGeneration, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('multipartContext: $multipartContext, ')
          ..write('openPolicy: $openPolicy, ')
          ..write('blobId: $blobId, ')
          ..write('blobState: $blobState, ')
          ..write('cipherFormat: $cipherFormat, ')
          ..write('cipherVersion: $cipherVersion, ')
          ..write('isDirty: $isDirty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    coreId,
    storageKey,
    filename,
    originalExtension,
    contentType,
    byteSize,
    checksumSha256,
    mediaType,
    duration,
    uploadState,
    uploadGeneration,
    uploadedAt,
    multipartContext,
    openPolicy,
    blobId,
    blobState,
    cipherFormat,
    cipherVersion,
    isDirty,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileBlobRow &&
          other.id == this.id &&
          other.coreId == this.coreId &&
          other.storageKey == this.storageKey &&
          other.filename == this.filename &&
          other.originalExtension == this.originalExtension &&
          other.contentType == this.contentType &&
          other.byteSize == this.byteSize &&
          other.checksumSha256 == this.checksumSha256 &&
          other.mediaType == this.mediaType &&
          other.duration == this.duration &&
          other.uploadState == this.uploadState &&
          other.uploadGeneration == this.uploadGeneration &&
          other.uploadedAt == this.uploadedAt &&
          other.multipartContext == this.multipartContext &&
          other.openPolicy == this.openPolicy &&
          other.blobId == this.blobId &&
          other.blobState == this.blobState &&
          other.cipherFormat == this.cipherFormat &&
          other.cipherVersion == this.cipherVersion &&
          other.isDirty == this.isDirty &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FileBlobsCompanion extends UpdateCompanion<FileBlobRow> {
  final Value<String> id;
  final Value<int?> coreId;
  final Value<String?> storageKey;
  final Value<String?> filename;
  final Value<String?> originalExtension;
  final Value<String?> contentType;
  final Value<int> byteSize;
  final Value<String?> checksumSha256;
  final Value<String> mediaType;
  final Value<int?> duration;
  final Value<String> uploadState;
  final Value<int> uploadGeneration;
  final Value<int?> uploadedAt;
  final Value<String?> multipartContext;
  final Value<String> openPolicy;
  final Value<String?> blobId;
  final Value<String> blobState;
  final Value<String> cipherFormat;
  final Value<int> cipherVersion;
  final Value<bool> isDirty;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const FileBlobsCompanion({
    this.id = const Value.absent(),
    this.coreId = const Value.absent(),
    this.storageKey = const Value.absent(),
    this.filename = const Value.absent(),
    this.originalExtension = const Value.absent(),
    this.contentType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.checksumSha256 = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.duration = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.uploadGeneration = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.multipartContext = const Value.absent(),
    this.openPolicy = const Value.absent(),
    this.blobId = const Value.absent(),
    this.blobState = const Value.absent(),
    this.cipherFormat = const Value.absent(),
    this.cipherVersion = const Value.absent(),
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
    this.originalExtension = const Value.absent(),
    this.contentType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.checksumSha256 = const Value.absent(),
    required String mediaType,
    this.duration = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.uploadGeneration = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.multipartContext = const Value.absent(),
    this.openPolicy = const Value.absent(),
    this.blobId = const Value.absent(),
    this.blobState = const Value.absent(),
    this.cipherFormat = const Value.absent(),
    this.cipherVersion = const Value.absent(),
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
    Expression<String>? originalExtension,
    Expression<String>? contentType,
    Expression<int>? byteSize,
    Expression<String>? checksumSha256,
    Expression<String>? mediaType,
    Expression<int>? duration,
    Expression<String>? uploadState,
    Expression<int>? uploadGeneration,
    Expression<int>? uploadedAt,
    Expression<String>? multipartContext,
    Expression<String>? openPolicy,
    Expression<String>? blobId,
    Expression<String>? blobState,
    Expression<String>? cipherFormat,
    Expression<int>? cipherVersion,
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
      if (originalExtension != null) 'original_extension': originalExtension,
      if (contentType != null) 'content_type': contentType,
      if (byteSize != null) 'byte_size': byteSize,
      if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
      if (mediaType != null) 'media_type': mediaType,
      if (duration != null) 'duration': duration,
      if (uploadState != null) 'upload_state': uploadState,
      if (uploadGeneration != null) 'upload_generation': uploadGeneration,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (multipartContext != null) 'multipart_context': multipartContext,
      if (openPolicy != null) 'open_policy': openPolicy,
      if (blobId != null) 'blob_id': blobId,
      if (blobState != null) 'blob_state': blobState,
      if (cipherFormat != null) 'cipher_format': cipherFormat,
      if (cipherVersion != null) 'cipher_version': cipherVersion,
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
    Value<String?>? originalExtension,
    Value<String?>? contentType,
    Value<int>? byteSize,
    Value<String?>? checksumSha256,
    Value<String>? mediaType,
    Value<int?>? duration,
    Value<String>? uploadState,
    Value<int>? uploadGeneration,
    Value<int?>? uploadedAt,
    Value<String?>? multipartContext,
    Value<String>? openPolicy,
    Value<String?>? blobId,
    Value<String>? blobState,
    Value<String>? cipherFormat,
    Value<int>? cipherVersion,
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
      originalExtension: originalExtension ?? this.originalExtension,
      contentType: contentType ?? this.contentType,
      byteSize: byteSize ?? this.byteSize,
      checksumSha256: checksumSha256 ?? this.checksumSha256,
      mediaType: mediaType ?? this.mediaType,
      duration: duration ?? this.duration,
      uploadState: uploadState ?? this.uploadState,
      uploadGeneration: uploadGeneration ?? this.uploadGeneration,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      multipartContext: multipartContext ?? this.multipartContext,
      openPolicy: openPolicy ?? this.openPolicy,
      blobId: blobId ?? this.blobId,
      blobState: blobState ?? this.blobState,
      cipherFormat: cipherFormat ?? this.cipherFormat,
      cipherVersion: cipherVersion ?? this.cipherVersion,
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
    if (originalExtension.present) {
      map['original_extension'] = Variable<String>(originalExtension.value);
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
    if (openPolicy.present) {
      map['open_policy'] = Variable<String>(openPolicy.value);
    }
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (blobState.present) {
      map['blob_state'] = Variable<String>(blobState.value);
    }
    if (cipherFormat.present) {
      map['cipher_format'] = Variable<String>(cipherFormat.value);
    }
    if (cipherVersion.present) {
      map['cipher_version'] = Variable<int>(cipherVersion.value);
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
          ..write('originalExtension: $originalExtension, ')
          ..write('contentType: $contentType, ')
          ..write('byteSize: $byteSize, ')
          ..write('checksumSha256: $checksumSha256, ')
          ..write('mediaType: $mediaType, ')
          ..write('duration: $duration, ')
          ..write('uploadState: $uploadState, ')
          ..write('uploadGeneration: $uploadGeneration, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('multipartContext: $multipartContext, ')
          ..write('openPolicy: $openPolicy, ')
          ..write('blobId: $blobId, ')
          ..write('blobState: $blobState, ')
          ..write('cipherFormat: $cipherFormat, ')
          ..write('cipherVersion: $cipherVersion, ')
          ..write('isDirty: $isDirty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultRetentionPoliciesTable extends VaultRetentionPolicies
    with TableInfo<$VaultRetentionPoliciesTable, VaultRetentionPolicyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultRetentionPoliciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('keep_forever'),
  );
  static const VerificationMeta _expiryDaysMeta = const VerificationMeta(
    'expiryDays',
  );
  @override
  late final GeneratedColumn<int> expiryDays = GeneratedColumn<int>(
    'expiry_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [id, mode, expiryDays, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_retention_policies';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultRetentionPolicyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('expiry_days')) {
      context.handle(
        _expiryDaysMeta,
        expiryDays.isAcceptableOrUnknown(data['expiry_days']!, _expiryDaysMeta),
      );
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
  VaultRetentionPolicyRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultRetentionPolicyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      expiryDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expiry_days'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VaultRetentionPoliciesTable createAlias(String alias) {
    return $VaultRetentionPoliciesTable(attachedDatabase, alias);
  }
}

class VaultRetentionPolicyRow extends DataClass
    implements Insertable<VaultRetentionPolicyRow> {
  final int id;
  final String mode;
  final int? expiryDays;
  final int updatedAt;
  const VaultRetentionPolicyRow({
    required this.id,
    required this.mode,
    this.expiryDays,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || expiryDays != null) {
      map['expiry_days'] = Variable<int>(expiryDays);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  VaultRetentionPoliciesCompanion toCompanion(bool nullToAbsent) {
    return VaultRetentionPoliciesCompanion(
      id: Value(id),
      mode: Value(mode),
      expiryDays: expiryDays == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDays),
      updatedAt: Value(updatedAt),
    );
  }

  factory VaultRetentionPolicyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultRetentionPolicyRow(
      id: serializer.fromJson<int>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      expiryDays: serializer.fromJson<int?>(json['expiryDays']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mode': serializer.toJson<String>(mode),
      'expiryDays': serializer.toJson<int?>(expiryDays),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  VaultRetentionPolicyRow copyWith({
    int? id,
    String? mode,
    Value<int?> expiryDays = const Value.absent(),
    int? updatedAt,
  }) => VaultRetentionPolicyRow(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    expiryDays: expiryDays.present ? expiryDays.value : this.expiryDays,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VaultRetentionPolicyRow copyWithCompanion(
    VaultRetentionPoliciesCompanion data,
  ) {
    return VaultRetentionPolicyRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      expiryDays: data.expiryDays.present
          ? data.expiryDays.value
          : this.expiryDays,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultRetentionPolicyRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('expiryDays: $expiryDays, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mode, expiryDays, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultRetentionPolicyRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.expiryDays == this.expiryDays &&
          other.updatedAt == this.updatedAt);
}

class VaultRetentionPoliciesCompanion
    extends UpdateCompanion<VaultRetentionPolicyRow> {
  final Value<int> id;
  final Value<String> mode;
  final Value<int?> expiryDays;
  final Value<int> updatedAt;
  const VaultRetentionPoliciesCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.expiryDays = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VaultRetentionPoliciesCompanion.insert({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.expiryDays = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<VaultRetentionPolicyRow> custom({
    Expression<int>? id,
    Expression<String>? mode,
    Expression<int>? expiryDays,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (expiryDays != null) 'expiry_days': expiryDays,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VaultRetentionPoliciesCompanion copyWith({
    Value<int>? id,
    Value<String>? mode,
    Value<int?>? expiryDays,
    Value<int>? updatedAt,
  }) {
    return VaultRetentionPoliciesCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      expiryDays: expiryDays ?? this.expiryDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (expiryDays.present) {
      map['expiry_days'] = Variable<int>(expiryDays.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultRetentionPoliciesCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('expiryDays: $expiryDays, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BlobGcDecisionsTable extends BlobGcDecisions
    with TableInfo<$BlobGcDecisionsTable, BlobGcDecisionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlobGcDecisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decisionMeta = const VerificationMeta(
    'decision',
  );
  @override
  late final GeneratedColumn<String> decision = GeneratedColumn<String>(
    'decision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decidedAtMeta = const VerificationMeta(
    'decidedAt',
  );
  @override
  late final GeneratedColumn<int> decidedAt = GeneratedColumn<int>(
    'decided_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [blobId, decision, reason, decidedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blob_gc_decisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlobGcDecisionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('decision')) {
      context.handle(
        _decisionMeta,
        decision.isAcceptableOrUnknown(data['decision']!, _decisionMeta),
      );
    } else if (isInserting) {
      context.missing(_decisionMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('decided_at')) {
      context.handle(
        _decidedAtMeta,
        decidedAt.isAcceptableOrUnknown(data['decided_at']!, _decidedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_decidedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blobId};
  @override
  BlobGcDecisionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlobGcDecisionRow(
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      decision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decision'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      decidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}decided_at'],
      )!,
    );
  }

  @override
  $BlobGcDecisionsTable createAlias(String alias) {
    return $BlobGcDecisionsTable(attachedDatabase, alias);
  }
}

class BlobGcDecisionRow extends DataClass
    implements Insertable<BlobGcDecisionRow> {
  final String blobId;
  final String decision;
  final String reason;
  final int decidedAt;
  const BlobGcDecisionRow({
    required this.blobId,
    required this.decision,
    required this.reason,
    required this.decidedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['blob_id'] = Variable<String>(blobId);
    map['decision'] = Variable<String>(decision);
    map['reason'] = Variable<String>(reason);
    map['decided_at'] = Variable<int>(decidedAt);
    return map;
  }

  BlobGcDecisionsCompanion toCompanion(bool nullToAbsent) {
    return BlobGcDecisionsCompanion(
      blobId: Value(blobId),
      decision: Value(decision),
      reason: Value(reason),
      decidedAt: Value(decidedAt),
    );
  }

  factory BlobGcDecisionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlobGcDecisionRow(
      blobId: serializer.fromJson<String>(json['blobId']),
      decision: serializer.fromJson<String>(json['decision']),
      reason: serializer.fromJson<String>(json['reason']),
      decidedAt: serializer.fromJson<int>(json['decidedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blobId': serializer.toJson<String>(blobId),
      'decision': serializer.toJson<String>(decision),
      'reason': serializer.toJson<String>(reason),
      'decidedAt': serializer.toJson<int>(decidedAt),
    };
  }

  BlobGcDecisionRow copyWith({
    String? blobId,
    String? decision,
    String? reason,
    int? decidedAt,
  }) => BlobGcDecisionRow(
    blobId: blobId ?? this.blobId,
    decision: decision ?? this.decision,
    reason: reason ?? this.reason,
    decidedAt: decidedAt ?? this.decidedAt,
  );
  BlobGcDecisionRow copyWithCompanion(BlobGcDecisionsCompanion data) {
    return BlobGcDecisionRow(
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      decision: data.decision.present ? data.decision.value : this.decision,
      reason: data.reason.present ? data.reason.value : this.reason,
      decidedAt: data.decidedAt.present ? data.decidedAt.value : this.decidedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlobGcDecisionRow(')
          ..write('blobId: $blobId, ')
          ..write('decision: $decision, ')
          ..write('reason: $reason, ')
          ..write('decidedAt: $decidedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(blobId, decision, reason, decidedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlobGcDecisionRow &&
          other.blobId == this.blobId &&
          other.decision == this.decision &&
          other.reason == this.reason &&
          other.decidedAt == this.decidedAt);
}

class BlobGcDecisionsCompanion extends UpdateCompanion<BlobGcDecisionRow> {
  final Value<String> blobId;
  final Value<String> decision;
  final Value<String> reason;
  final Value<int> decidedAt;
  final Value<int> rowid;
  const BlobGcDecisionsCompanion({
    this.blobId = const Value.absent(),
    this.decision = const Value.absent(),
    this.reason = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlobGcDecisionsCompanion.insert({
    required String blobId,
    required String decision,
    required String reason,
    required int decidedAt,
    this.rowid = const Value.absent(),
  }) : blobId = Value(blobId),
       decision = Value(decision),
       reason = Value(reason),
       decidedAt = Value(decidedAt);
  static Insertable<BlobGcDecisionRow> custom({
    Expression<String>? blobId,
    Expression<String>? decision,
    Expression<String>? reason,
    Expression<int>? decidedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blobId != null) 'blob_id': blobId,
      if (decision != null) 'decision': decision,
      if (reason != null) 'reason': reason,
      if (decidedAt != null) 'decided_at': decidedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlobGcDecisionsCompanion copyWith({
    Value<String>? blobId,
    Value<String>? decision,
    Value<String>? reason,
    Value<int>? decidedAt,
    Value<int>? rowid,
  }) {
    return BlobGcDecisionsCompanion(
      blobId: blobId ?? this.blobId,
      decision: decision ?? this.decision,
      reason: reason ?? this.reason,
      decidedAt: decidedAt ?? this.decidedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (decision.present) {
      map['decision'] = Variable<String>(decision.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (decidedAt.present) {
      map['decided_at'] = Variable<int>(decidedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlobGcDecisionsCompanion(')
          ..write('blobId: $blobId, ')
          ..write('decision: $decision, ')
          ..write('reason: $reason, ')
          ..write('decidedAt: $decidedAt, ')
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
  static const VerificationMeta _acceptedBodyMeta = const VerificationMeta(
    'acceptedBody',
  );
  @override
  late final GeneratedColumn<String> acceptedBody = GeneratedColumn<String>(
    'accepted_body',
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
    body,
    acceptedBody,
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
    if (data.containsKey('accepted_body')) {
      context.handle(
        _acceptedBodyMeta,
        acceptedBody.isAcceptableOrUnknown(
          data['accepted_body']!,
          _acceptedBodyMeta,
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
      acceptedBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accepted_body'],
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
  $TextContentsTable createAlias(String alias) {
    return $TextContentsTable(attachedDatabase, alias);
  }
}

class TextContentRow extends DataClass implements Insertable<TextContentRow> {
  final String id;
  final int? coreId;
  final String body;
  final String? acceptedBody;
  final bool isDirty;
  final int createdAt;
  final int updatedAt;
  const TextContentRow({
    required this.id,
    this.coreId,
    required this.body,
    this.acceptedBody,
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
    if (!nullToAbsent || acceptedBody != null) {
      map['accepted_body'] = Variable<String>(acceptedBody);
    }
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
      acceptedBody: acceptedBody == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedBody),
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
      acceptedBody: serializer.fromJson<String?>(json['acceptedBody']),
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
      'acceptedBody': serializer.toJson<String?>(acceptedBody),
      'isDirty': serializer.toJson<bool>(isDirty),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TextContentRow copyWith({
    String? id,
    Value<int?> coreId = const Value.absent(),
    String? body,
    Value<String?> acceptedBody = const Value.absent(),
    bool? isDirty,
    int? createdAt,
    int? updatedAt,
  }) => TextContentRow(
    id: id ?? this.id,
    coreId: coreId.present ? coreId.value : this.coreId,
    body: body ?? this.body,
    acceptedBody: acceptedBody.present ? acceptedBody.value : this.acceptedBody,
    isDirty: isDirty ?? this.isDirty,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TextContentRow copyWithCompanion(TextContentsCompanion data) {
    return TextContentRow(
      id: data.id.present ? data.id.value : this.id,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
      body: data.body.present ? data.body.value : this.body,
      acceptedBody: data.acceptedBody.present
          ? data.acceptedBody.value
          : this.acceptedBody,
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
          ..write('acceptedBody: $acceptedBody, ')
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
    body,
    acceptedBody,
    isDirty,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextContentRow &&
          other.id == this.id &&
          other.coreId == this.coreId &&
          other.body == this.body &&
          other.acceptedBody == this.acceptedBody &&
          other.isDirty == this.isDirty &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TextContentsCompanion extends UpdateCompanion<TextContentRow> {
  final Value<String> id;
  final Value<int?> coreId;
  final Value<String> body;
  final Value<String?> acceptedBody;
  final Value<bool> isDirty;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TextContentsCompanion({
    this.id = const Value.absent(),
    this.coreId = const Value.absent(),
    this.body = const Value.absent(),
    this.acceptedBody = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextContentsCompanion.insert({
    required String id,
    this.coreId = const Value.absent(),
    required String body,
    this.acceptedBody = const Value.absent(),
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
    Expression<String>? acceptedBody,
    Expression<bool>? isDirty,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coreId != null) 'core_id': coreId,
      if (body != null) 'body': body,
      if (acceptedBody != null) 'accepted_body': acceptedBody,
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
    Value<String?>? acceptedBody,
    Value<bool>? isDirty,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TextContentsCompanion(
      id: id ?? this.id,
      coreId: coreId ?? this.coreId,
      body: body ?? this.body,
      acceptedBody: acceptedBody ?? this.acceptedBody,
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
    if (acceptedBody.present) {
      map['accepted_body'] = Variable<String>(acceptedBody.value);
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
          ..write('acceptedBody: $acceptedBody, ')
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
  static const VerificationMeta _processingAttemptMeta = const VerificationMeta(
    'processingAttempt',
  );
  @override
  late final GeneratedColumn<int> processingAttempt = GeneratedColumn<int>(
    'processing_attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _acceptedSourceRevisionMeta =
      const VerificationMeta('acceptedSourceRevision');
  @override
  late final GeneratedColumn<int> acceptedSourceRevision = GeneratedColumn<int>(
    'accepted_source_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _processingRequestedOutputsMeta =
      const VerificationMeta('processingRequestedOutputs');
  @override
  late final GeneratedColumn<String> processingRequestedOutputs =
      GeneratedColumn<String>(
        'processing_requested_outputs',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
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
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
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
    processingAttempt,
    sourceRevision,
    acceptedSourceRevision,
    processingConfigRevision,
    processingOutputs,
    processingRequestedOutputs,
    processingError,
    processingErrorCode,
    fileBlobId,
    textContentId,
    isDirty,
    syncState,
    isDeleted,
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
    if (data.containsKey('processing_attempt')) {
      context.handle(
        _processingAttemptMeta,
        processingAttempt.isAcceptableOrUnknown(
          data['processing_attempt']!,
          _processingAttemptMeta,
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
    if (data.containsKey('accepted_source_revision')) {
      context.handle(
        _acceptedSourceRevisionMeta,
        acceptedSourceRevision.isAcceptableOrUnknown(
          data['accepted_source_revision']!,
          _acceptedSourceRevisionMeta,
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
    if (data.containsKey('processing_requested_outputs')) {
      context.handle(
        _processingRequestedOutputsMeta,
        processingRequestedOutputs.isAcceptableOrUnknown(
          data['processing_requested_outputs']!,
          _processingRequestedOutputsMeta,
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
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
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
      processingAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processing_attempt'],
      )!,
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_revision'],
      )!,
      acceptedSourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted_source_revision'],
      )!,
      processingConfigRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processing_config_revision'],
      ),
      processingOutputs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_outputs'],
      )!,
      processingRequestedOutputs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_requested_outputs'],
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
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
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
  final int processingAttempt;
  final int sourceRevision;
  final int acceptedSourceRevision;
  final int? processingConfigRevision;
  final String processingOutputs;
  final String processingRequestedOutputs;
  final String? processingError;
  final String? processingErrorCode;
  final String? fileBlobId;
  final String? textContentId;
  final bool isDirty;
  final String syncState;
  final bool isDeleted;
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
    required this.processingAttempt,
    required this.sourceRevision,
    required this.acceptedSourceRevision,
    this.processingConfigRevision,
    required this.processingOutputs,
    required this.processingRequestedOutputs,
    this.processingError,
    this.processingErrorCode,
    this.fileBlobId,
    this.textContentId,
    required this.isDirty,
    required this.syncState,
    required this.isDeleted,
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
    map['processing_attempt'] = Variable<int>(processingAttempt);
    map['source_revision'] = Variable<int>(sourceRevision);
    map['accepted_source_revision'] = Variable<int>(acceptedSourceRevision);
    if (!nullToAbsent || processingConfigRevision != null) {
      map['processing_config_revision'] = Variable<int>(
        processingConfigRevision,
      );
    }
    map['processing_outputs'] = Variable<String>(processingOutputs);
    map['processing_requested_outputs'] = Variable<String>(
      processingRequestedOutputs,
    );
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
    map['is_deleted'] = Variable<bool>(isDeleted);
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
      processingAttempt: Value(processingAttempt),
      sourceRevision: Value(sourceRevision),
      acceptedSourceRevision: Value(acceptedSourceRevision),
      processingConfigRevision: processingConfigRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(processingConfigRevision),
      processingOutputs: Value(processingOutputs),
      processingRequestedOutputs: Value(processingRequestedOutputs),
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
      isDeleted: Value(isDeleted),
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
      processingAttempt: serializer.fromJson<int>(json['processingAttempt']),
      sourceRevision: serializer.fromJson<int>(json['sourceRevision']),
      acceptedSourceRevision: serializer.fromJson<int>(
        json['acceptedSourceRevision'],
      ),
      processingConfigRevision: serializer.fromJson<int?>(
        json['processingConfigRevision'],
      ),
      processingOutputs: serializer.fromJson<String>(json['processingOutputs']),
      processingRequestedOutputs: serializer.fromJson<String>(
        json['processingRequestedOutputs'],
      ),
      processingError: serializer.fromJson<String?>(json['processingError']),
      processingErrorCode: serializer.fromJson<String?>(
        json['processingErrorCode'],
      ),
      fileBlobId: serializer.fromJson<String?>(json['fileBlobId']),
      textContentId: serializer.fromJson<String?>(json['textContentId']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      syncState: serializer.fromJson<String>(json['syncState']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
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
      'processingAttempt': serializer.toJson<int>(processingAttempt),
      'sourceRevision': serializer.toJson<int>(sourceRevision),
      'acceptedSourceRevision': serializer.toJson<int>(acceptedSourceRevision),
      'processingConfigRevision': serializer.toJson<int?>(
        processingConfigRevision,
      ),
      'processingOutputs': serializer.toJson<String>(processingOutputs),
      'processingRequestedOutputs': serializer.toJson<String>(
        processingRequestedOutputs,
      ),
      'processingError': serializer.toJson<String?>(processingError),
      'processingErrorCode': serializer.toJson<String?>(processingErrorCode),
      'fileBlobId': serializer.toJson<String?>(fileBlobId),
      'textContentId': serializer.toJson<String?>(textContentId),
      'isDirty': serializer.toJson<bool>(isDirty),
      'syncState': serializer.toJson<String>(syncState),
      'isDeleted': serializer.toJson<bool>(isDeleted),
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
    int? processingAttempt,
    int? sourceRevision,
    int? acceptedSourceRevision,
    Value<int?> processingConfigRevision = const Value.absent(),
    String? processingOutputs,
    String? processingRequestedOutputs,
    Value<String?> processingError = const Value.absent(),
    Value<String?> processingErrorCode = const Value.absent(),
    Value<String?> fileBlobId = const Value.absent(),
    Value<String?> textContentId = const Value.absent(),
    bool? isDirty,
    String? syncState,
    bool? isDeleted,
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
    processingAttempt: processingAttempt ?? this.processingAttempt,
    sourceRevision: sourceRevision ?? this.sourceRevision,
    acceptedSourceRevision:
        acceptedSourceRevision ?? this.acceptedSourceRevision,
    processingConfigRevision: processingConfigRevision.present
        ? processingConfigRevision.value
        : this.processingConfigRevision,
    processingOutputs: processingOutputs ?? this.processingOutputs,
    processingRequestedOutputs:
        processingRequestedOutputs ?? this.processingRequestedOutputs,
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
    isDeleted: isDeleted ?? this.isDeleted,
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
      processingAttempt: data.processingAttempt.present
          ? data.processingAttempt.value
          : this.processingAttempt,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      acceptedSourceRevision: data.acceptedSourceRevision.present
          ? data.acceptedSourceRevision.value
          : this.acceptedSourceRevision,
      processingConfigRevision: data.processingConfigRevision.present
          ? data.processingConfigRevision.value
          : this.processingConfigRevision,
      processingOutputs: data.processingOutputs.present
          ? data.processingOutputs.value
          : this.processingOutputs,
      processingRequestedOutputs: data.processingRequestedOutputs.present
          ? data.processingRequestedOutputs.value
          : this.processingRequestedOutputs,
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
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
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
          ..write('processingAttempt: $processingAttempt, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('acceptedSourceRevision: $acceptedSourceRevision, ')
          ..write('processingConfigRevision: $processingConfigRevision, ')
          ..write('processingOutputs: $processingOutputs, ')
          ..write('processingRequestedOutputs: $processingRequestedOutputs, ')
          ..write('processingError: $processingError, ')
          ..write('processingErrorCode: $processingErrorCode, ')
          ..write('fileBlobId: $fileBlobId, ')
          ..write('textContentId: $textContentId, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncState: $syncState, ')
          ..write('isDeleted: $isDeleted, ')
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
    processingAttempt,
    sourceRevision,
    acceptedSourceRevision,
    processingConfigRevision,
    processingOutputs,
    processingRequestedOutputs,
    processingError,
    processingErrorCode,
    fileBlobId,
    textContentId,
    isDirty,
    syncState,
    isDeleted,
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
          other.processingAttempt == this.processingAttempt &&
          other.sourceRevision == this.sourceRevision &&
          other.acceptedSourceRevision == this.acceptedSourceRevision &&
          other.processingConfigRevision == this.processingConfigRevision &&
          other.processingOutputs == this.processingOutputs &&
          other.processingRequestedOutputs == this.processingRequestedOutputs &&
          other.processingError == this.processingError &&
          other.processingErrorCode == this.processingErrorCode &&
          other.fileBlobId == this.fileBlobId &&
          other.textContentId == this.textContentId &&
          other.isDirty == this.isDirty &&
          other.syncState == this.syncState &&
          other.isDeleted == this.isDeleted &&
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
  final Value<int> processingAttempt;
  final Value<int> sourceRevision;
  final Value<int> acceptedSourceRevision;
  final Value<int?> processingConfigRevision;
  final Value<String> processingOutputs;
  final Value<String> processingRequestedOutputs;
  final Value<String?> processingError;
  final Value<String?> processingErrorCode;
  final Value<String?> fileBlobId;
  final Value<String?> textContentId;
  final Value<bool> isDirty;
  final Value<String> syncState;
  final Value<bool> isDeleted;
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
    this.processingAttempt = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.acceptedSourceRevision = const Value.absent(),
    this.processingConfigRevision = const Value.absent(),
    this.processingOutputs = const Value.absent(),
    this.processingRequestedOutputs = const Value.absent(),
    this.processingError = const Value.absent(),
    this.processingErrorCode = const Value.absent(),
    this.fileBlobId = const Value.absent(),
    this.textContentId = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncState = const Value.absent(),
    this.isDeleted = const Value.absent(),
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
    this.processingAttempt = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.acceptedSourceRevision = const Value.absent(),
    this.processingConfigRevision = const Value.absent(),
    this.processingOutputs = const Value.absent(),
    this.processingRequestedOutputs = const Value.absent(),
    this.processingError = const Value.absent(),
    this.processingErrorCode = const Value.absent(),
    this.fileBlobId = const Value.absent(),
    this.textContentId = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncState = const Value.absent(),
    this.isDeleted = const Value.absent(),
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
    Expression<int>? processingAttempt,
    Expression<int>? sourceRevision,
    Expression<int>? acceptedSourceRevision,
    Expression<int>? processingConfigRevision,
    Expression<String>? processingOutputs,
    Expression<String>? processingRequestedOutputs,
    Expression<String>? processingError,
    Expression<String>? processingErrorCode,
    Expression<String>? fileBlobId,
    Expression<String>? textContentId,
    Expression<bool>? isDirty,
    Expression<String>? syncState,
    Expression<bool>? isDeleted,
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
      if (processingAttempt != null) 'processing_attempt': processingAttempt,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (acceptedSourceRevision != null)
        'accepted_source_revision': acceptedSourceRevision,
      if (processingConfigRevision != null)
        'processing_config_revision': processingConfigRevision,
      if (processingOutputs != null) 'processing_outputs': processingOutputs,
      if (processingRequestedOutputs != null)
        'processing_requested_outputs': processingRequestedOutputs,
      if (processingError != null) 'processing_error': processingError,
      if (processingErrorCode != null)
        'processing_error_code': processingErrorCode,
      if (fileBlobId != null) 'file_blob_id': fileBlobId,
      if (textContentId != null) 'text_content_id': textContentId,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncState != null) 'sync_state': syncState,
      if (isDeleted != null) 'is_deleted': isDeleted,
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
    Value<int>? processingAttempt,
    Value<int>? sourceRevision,
    Value<int>? acceptedSourceRevision,
    Value<int?>? processingConfigRevision,
    Value<String>? processingOutputs,
    Value<String>? processingRequestedOutputs,
    Value<String?>? processingError,
    Value<String?>? processingErrorCode,
    Value<String?>? fileBlobId,
    Value<String?>? textContentId,
    Value<bool>? isDirty,
    Value<String>? syncState,
    Value<bool>? isDeleted,
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
      processingAttempt: processingAttempt ?? this.processingAttempt,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      acceptedSourceRevision:
          acceptedSourceRevision ?? this.acceptedSourceRevision,
      processingConfigRevision:
          processingConfigRevision ?? this.processingConfigRevision,
      processingOutputs: processingOutputs ?? this.processingOutputs,
      processingRequestedOutputs:
          processingRequestedOutputs ?? this.processingRequestedOutputs,
      processingError: processingError ?? this.processingError,
      processingErrorCode: processingErrorCode ?? this.processingErrorCode,
      fileBlobId: fileBlobId ?? this.fileBlobId,
      textContentId: textContentId ?? this.textContentId,
      isDirty: isDirty ?? this.isDirty,
      syncState: syncState ?? this.syncState,
      isDeleted: isDeleted ?? this.isDeleted,
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
    if (processingAttempt.present) {
      map['processing_attempt'] = Variable<int>(processingAttempt.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<int>(sourceRevision.value);
    }
    if (acceptedSourceRevision.present) {
      map['accepted_source_revision'] = Variable<int>(
        acceptedSourceRevision.value,
      );
    }
    if (processingConfigRevision.present) {
      map['processing_config_revision'] = Variable<int>(
        processingConfigRevision.value,
      );
    }
    if (processingOutputs.present) {
      map['processing_outputs'] = Variable<String>(processingOutputs.value);
    }
    if (processingRequestedOutputs.present) {
      map['processing_requested_outputs'] = Variable<String>(
        processingRequestedOutputs.value,
      );
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
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
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
          ..write('processingAttempt: $processingAttempt, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('acceptedSourceRevision: $acceptedSourceRevision, ')
          ..write('processingConfigRevision: $processingConfigRevision, ')
          ..write('processingOutputs: $processingOutputs, ')
          ..write('processingRequestedOutputs: $processingRequestedOutputs, ')
          ..write('processingError: $processingError, ')
          ..write('processingErrorCode: $processingErrorCode, ')
          ..write('fileBlobId: $fileBlobId, ')
          ..write('textContentId: $textContentId, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncState: $syncState, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkQueueTable extends WorkQueue
    with TableInfo<$WorkQueueTable, WorkQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blobRevisionMeta = const VerificationMeta(
    'blobRevision',
  );
  @override
  late final GeneratedColumn<int> blobRevision = GeneratedColumn<int>(
    'blob_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependsOnMeta = const VerificationMeta(
    'dependsOn',
  );
  @override
  late final GeneratedColumn<String> dependsOn = GeneratedColumn<String>(
    'depends_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationBodyMeta = const VerificationMeta(
    'operationBody',
  );
  @override
  late final GeneratedColumn<String> operationBody = GeneratedColumn<String>(
    'operation_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submittedSourceRevisionMeta =
      const VerificationMeta('submittedSourceRevision');
  @override
  late final GeneratedColumn<int> submittedSourceRevision =
      GeneratedColumn<int>(
        'submitted_source_revision',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _expectedSourceRevisionMeta =
      const VerificationMeta('expectedSourceRevision');
  @override
  late final GeneratedColumn<int> expectedSourceRevision = GeneratedColumn<int>(
    'expected_source_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _availableAtMeta = const VerificationMeta(
    'availableAt',
  );
  @override
  late final GeneratedColumn<int> availableAt = GeneratedColumn<int>(
    'available_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaseOwnerMeta = const VerificationMeta(
    'leaseOwner',
  );
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
    'lease_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockedReasonMeta = const VerificationMeta(
    'blockedReason',
  );
  @override
  late final GeneratedColumn<String> blockedReason = GeneratedColumn<String>(
    'blocked_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configRevisionMeta = const VerificationMeta(
    'configRevision',
  );
  @override
  late final GeneratedColumn<int> configRevision = GeneratedColumn<int>(
    'config_revision',
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
    kind,
    itemId,
    blobId,
    blobRevision,
    dedupeKey,
    state,
    stage,
    dependsOn,
    operationBody,
    submittedSourceRevision,
    expectedSourceRevision,
    attempt,
    availableAt,
    leaseOwner,
    leaseUntil,
    progress,
    errorCode,
    blockedReason,
    configRevision,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    }
    if (data.containsKey('blob_revision')) {
      context.handle(
        _blobRevisionMeta,
        blobRevision.isAcceptableOrUnknown(
          data['blob_revision']!,
          _blobRevisionMeta,
        ),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('depends_on')) {
      context.handle(
        _dependsOnMeta,
        dependsOn.isAcceptableOrUnknown(data['depends_on']!, _dependsOnMeta),
      );
    }
    if (data.containsKey('operation_body')) {
      context.handle(
        _operationBodyMeta,
        operationBody.isAcceptableOrUnknown(
          data['operation_body']!,
          _operationBodyMeta,
        ),
      );
    }
    if (data.containsKey('submitted_source_revision')) {
      context.handle(
        _submittedSourceRevisionMeta,
        submittedSourceRevision.isAcceptableOrUnknown(
          data['submitted_source_revision']!,
          _submittedSourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('expected_source_revision')) {
      context.handle(
        _expectedSourceRevisionMeta,
        expectedSourceRevision.isAcceptableOrUnknown(
          data['expected_source_revision']!,
          _expectedSourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('available_at')) {
      context.handle(
        _availableAtMeta,
        availableAt.isAcceptableOrUnknown(
          data['available_at']!,
          _availableAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availableAtMeta);
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
        _leaseOwnerMeta,
        leaseOwner.isAcceptableOrUnknown(data['lease_owner']!, _leaseOwnerMeta),
      );
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('blocked_reason')) {
      context.handle(
        _blockedReasonMeta,
        blockedReason.isAcceptableOrUnknown(
          data['blocked_reason']!,
          _blockedReasonMeta,
        ),
      );
    }
    if (data.containsKey('config_revision')) {
      context.handle(
        _configRevisionMeta,
        configRevision.isAcceptableOrUnknown(
          data['config_revision']!,
          _configRevisionMeta,
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
    {dedupeKey},
  ];
  @override
  WorkQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      ),
      blobRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blob_revision'],
      ),
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      dependsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}depends_on'],
      ),
      operationBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_body'],
      ),
      submittedSourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}submitted_source_revision'],
      ),
      expectedSourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_source_revision'],
      ),
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      availableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}available_at'],
      )!,
      leaseOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_owner'],
      ),
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      blockedReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocked_reason'],
      ),
      configRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}config_revision'],
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
  $WorkQueueTable createAlias(String alias) {
    return $WorkQueueTable(attachedDatabase, alias);
  }
}

class WorkQueueRow extends DataClass implements Insertable<WorkQueueRow> {
  final String id;
  final String kind;
  final String itemId;
  final String? blobId;
  final int? blobRevision;
  final String dedupeKey;
  final String state;
  final String stage;
  final String? dependsOn;
  final String? operationBody;
  final int? submittedSourceRevision;
  final int? expectedSourceRevision;
  final int attempt;
  final int availableAt;
  final String? leaseOwner;
  final int? leaseUntil;
  final double progress;
  final String? errorCode;
  final String? blockedReason;
  final int configRevision;
  final int createdAt;
  final int updatedAt;
  const WorkQueueRow({
    required this.id,
    required this.kind,
    required this.itemId,
    this.blobId,
    this.blobRevision,
    required this.dedupeKey,
    required this.state,
    required this.stage,
    this.dependsOn,
    this.operationBody,
    this.submittedSourceRevision,
    this.expectedSourceRevision,
    required this.attempt,
    required this.availableAt,
    this.leaseOwner,
    this.leaseUntil,
    required this.progress,
    this.errorCode,
    this.blockedReason,
    required this.configRevision,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || blobId != null) {
      map['blob_id'] = Variable<String>(blobId);
    }
    if (!nullToAbsent || blobRevision != null) {
      map['blob_revision'] = Variable<int>(blobRevision);
    }
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['state'] = Variable<String>(state);
    map['stage'] = Variable<String>(stage);
    if (!nullToAbsent || dependsOn != null) {
      map['depends_on'] = Variable<String>(dependsOn);
    }
    if (!nullToAbsent || operationBody != null) {
      map['operation_body'] = Variable<String>(operationBody);
    }
    if (!nullToAbsent || submittedSourceRevision != null) {
      map['submitted_source_revision'] = Variable<int>(submittedSourceRevision);
    }
    if (!nullToAbsent || expectedSourceRevision != null) {
      map['expected_source_revision'] = Variable<int>(expectedSourceRevision);
    }
    map['attempt'] = Variable<int>(attempt);
    map['available_at'] = Variable<int>(availableAt);
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || blockedReason != null) {
      map['blocked_reason'] = Variable<String>(blockedReason);
    }
    map['config_revision'] = Variable<int>(configRevision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  WorkQueueCompanion toCompanion(bool nullToAbsent) {
    return WorkQueueCompanion(
      id: Value(id),
      kind: Value(kind),
      itemId: Value(itemId),
      blobId: blobId == null && nullToAbsent
          ? const Value.absent()
          : Value(blobId),
      blobRevision: blobRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(blobRevision),
      dedupeKey: Value(dedupeKey),
      state: Value(state),
      stage: Value(stage),
      dependsOn: dependsOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOn),
      operationBody: operationBody == null && nullToAbsent
          ? const Value.absent()
          : Value(operationBody),
      submittedSourceRevision: submittedSourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedSourceRevision),
      expectedSourceRevision: expectedSourceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedSourceRevision),
      attempt: Value(attempt),
      availableAt: Value(availableAt),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      progress: Value(progress),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      blockedReason: blockedReason == null && nullToAbsent
          ? const Value.absent()
          : Value(blockedReason),
      configRevision: Value(configRevision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkQueueRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      itemId: serializer.fromJson<String>(json['itemId']),
      blobId: serializer.fromJson<String?>(json['blobId']),
      blobRevision: serializer.fromJson<int?>(json['blobRevision']),
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      state: serializer.fromJson<String>(json['state']),
      stage: serializer.fromJson<String>(json['stage']),
      dependsOn: serializer.fromJson<String?>(json['dependsOn']),
      operationBody: serializer.fromJson<String?>(json['operationBody']),
      submittedSourceRevision: serializer.fromJson<int?>(
        json['submittedSourceRevision'],
      ),
      expectedSourceRevision: serializer.fromJson<int?>(
        json['expectedSourceRevision'],
      ),
      attempt: serializer.fromJson<int>(json['attempt']),
      availableAt: serializer.fromJson<int>(json['availableAt']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseUntil: serializer.fromJson<int?>(json['leaseUntil']),
      progress: serializer.fromJson<double>(json['progress']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      blockedReason: serializer.fromJson<String?>(json['blockedReason']),
      configRevision: serializer.fromJson<int>(json['configRevision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'itemId': serializer.toJson<String>(itemId),
      'blobId': serializer.toJson<String?>(blobId),
      'blobRevision': serializer.toJson<int?>(blobRevision),
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'state': serializer.toJson<String>(state),
      'stage': serializer.toJson<String>(stage),
      'dependsOn': serializer.toJson<String?>(dependsOn),
      'operationBody': serializer.toJson<String?>(operationBody),
      'submittedSourceRevision': serializer.toJson<int?>(
        submittedSourceRevision,
      ),
      'expectedSourceRevision': serializer.toJson<int?>(expectedSourceRevision),
      'attempt': serializer.toJson<int>(attempt),
      'availableAt': serializer.toJson<int>(availableAt),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseUntil': serializer.toJson<int?>(leaseUntil),
      'progress': serializer.toJson<double>(progress),
      'errorCode': serializer.toJson<String?>(errorCode),
      'blockedReason': serializer.toJson<String?>(blockedReason),
      'configRevision': serializer.toJson<int>(configRevision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  WorkQueueRow copyWith({
    String? id,
    String? kind,
    String? itemId,
    Value<String?> blobId = const Value.absent(),
    Value<int?> blobRevision = const Value.absent(),
    String? dedupeKey,
    String? state,
    String? stage,
    Value<String?> dependsOn = const Value.absent(),
    Value<String?> operationBody = const Value.absent(),
    Value<int?> submittedSourceRevision = const Value.absent(),
    Value<int?> expectedSourceRevision = const Value.absent(),
    int? attempt,
    int? availableAt,
    Value<String?> leaseOwner = const Value.absent(),
    Value<int?> leaseUntil = const Value.absent(),
    double? progress,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> blockedReason = const Value.absent(),
    int? configRevision,
    int? createdAt,
    int? updatedAt,
  }) => WorkQueueRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    itemId: itemId ?? this.itemId,
    blobId: blobId.present ? blobId.value : this.blobId,
    blobRevision: blobRevision.present ? blobRevision.value : this.blobRevision,
    dedupeKey: dedupeKey ?? this.dedupeKey,
    state: state ?? this.state,
    stage: stage ?? this.stage,
    dependsOn: dependsOn.present ? dependsOn.value : this.dependsOn,
    operationBody: operationBody.present
        ? operationBody.value
        : this.operationBody,
    submittedSourceRevision: submittedSourceRevision.present
        ? submittedSourceRevision.value
        : this.submittedSourceRevision,
    expectedSourceRevision: expectedSourceRevision.present
        ? expectedSourceRevision.value
        : this.expectedSourceRevision,
    attempt: attempt ?? this.attempt,
    availableAt: availableAt ?? this.availableAt,
    leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    progress: progress ?? this.progress,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    blockedReason: blockedReason.present
        ? blockedReason.value
        : this.blockedReason,
    configRevision: configRevision ?? this.configRevision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkQueueRow copyWithCompanion(WorkQueueCompanion data) {
    return WorkQueueRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      blobRevision: data.blobRevision.present
          ? data.blobRevision.value
          : this.blobRevision,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      state: data.state.present ? data.state.value : this.state,
      stage: data.stage.present ? data.stage.value : this.stage,
      dependsOn: data.dependsOn.present ? data.dependsOn.value : this.dependsOn,
      operationBody: data.operationBody.present
          ? data.operationBody.value
          : this.operationBody,
      submittedSourceRevision: data.submittedSourceRevision.present
          ? data.submittedSourceRevision.value
          : this.submittedSourceRevision,
      expectedSourceRevision: data.expectedSourceRevision.present
          ? data.expectedSourceRevision.value
          : this.expectedSourceRevision,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      availableAt: data.availableAt.present
          ? data.availableAt.value
          : this.availableAt,
      leaseOwner: data.leaseOwner.present
          ? data.leaseOwner.value
          : this.leaseOwner,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      progress: data.progress.present ? data.progress.value : this.progress,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      blockedReason: data.blockedReason.present
          ? data.blockedReason.value
          : this.blockedReason,
      configRevision: data.configRevision.present
          ? data.configRevision.value
          : this.configRevision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkQueueRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('itemId: $itemId, ')
          ..write('blobId: $blobId, ')
          ..write('blobRevision: $blobRevision, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('state: $state, ')
          ..write('stage: $stage, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('operationBody: $operationBody, ')
          ..write('submittedSourceRevision: $submittedSourceRevision, ')
          ..write('expectedSourceRevision: $expectedSourceRevision, ')
          ..write('attempt: $attempt, ')
          ..write('availableAt: $availableAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('progress: $progress, ')
          ..write('errorCode: $errorCode, ')
          ..write('blockedReason: $blockedReason, ')
          ..write('configRevision: $configRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    itemId,
    blobId,
    blobRevision,
    dedupeKey,
    state,
    stage,
    dependsOn,
    operationBody,
    submittedSourceRevision,
    expectedSourceRevision,
    attempt,
    availableAt,
    leaseOwner,
    leaseUntil,
    progress,
    errorCode,
    blockedReason,
    configRevision,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkQueueRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.itemId == this.itemId &&
          other.blobId == this.blobId &&
          other.blobRevision == this.blobRevision &&
          other.dedupeKey == this.dedupeKey &&
          other.state == this.state &&
          other.stage == this.stage &&
          other.dependsOn == this.dependsOn &&
          other.operationBody == this.operationBody &&
          other.submittedSourceRevision == this.submittedSourceRevision &&
          other.expectedSourceRevision == this.expectedSourceRevision &&
          other.attempt == this.attempt &&
          other.availableAt == this.availableAt &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseUntil == this.leaseUntil &&
          other.progress == this.progress &&
          other.errorCode == this.errorCode &&
          other.blockedReason == this.blockedReason &&
          other.configRevision == this.configRevision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkQueueCompanion extends UpdateCompanion<WorkQueueRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> itemId;
  final Value<String?> blobId;
  final Value<int?> blobRevision;
  final Value<String> dedupeKey;
  final Value<String> state;
  final Value<String> stage;
  final Value<String?> dependsOn;
  final Value<String?> operationBody;
  final Value<int?> submittedSourceRevision;
  final Value<int?> expectedSourceRevision;
  final Value<int> attempt;
  final Value<int> availableAt;
  final Value<String?> leaseOwner;
  final Value<int?> leaseUntil;
  final Value<double> progress;
  final Value<String?> errorCode;
  final Value<String?> blockedReason;
  final Value<int> configRevision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const WorkQueueCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.itemId = const Value.absent(),
    this.blobId = const Value.absent(),
    this.blobRevision = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.state = const Value.absent(),
    this.stage = const Value.absent(),
    this.dependsOn = const Value.absent(),
    this.operationBody = const Value.absent(),
    this.submittedSourceRevision = const Value.absent(),
    this.expectedSourceRevision = const Value.absent(),
    this.attempt = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.progress = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.blockedReason = const Value.absent(),
    this.configRevision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkQueueCompanion.insert({
    required String id,
    required String kind,
    required String itemId,
    this.blobId = const Value.absent(),
    this.blobRevision = const Value.absent(),
    required String dedupeKey,
    required String state,
    required String stage,
    this.dependsOn = const Value.absent(),
    this.operationBody = const Value.absent(),
    this.submittedSourceRevision = const Value.absent(),
    this.expectedSourceRevision = const Value.absent(),
    this.attempt = const Value.absent(),
    required int availableAt,
    this.leaseOwner = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.progress = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.blockedReason = const Value.absent(),
    this.configRevision = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       itemId = Value(itemId),
       dedupeKey = Value(dedupeKey),
       state = Value(state),
       stage = Value(stage),
       availableAt = Value(availableAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WorkQueueRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? itemId,
    Expression<String>? blobId,
    Expression<int>? blobRevision,
    Expression<String>? dedupeKey,
    Expression<String>? state,
    Expression<String>? stage,
    Expression<String>? dependsOn,
    Expression<String>? operationBody,
    Expression<int>? submittedSourceRevision,
    Expression<int>? expectedSourceRevision,
    Expression<int>? attempt,
    Expression<int>? availableAt,
    Expression<String>? leaseOwner,
    Expression<int>? leaseUntil,
    Expression<double>? progress,
    Expression<String>? errorCode,
    Expression<String>? blockedReason,
    Expression<int>? configRevision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (itemId != null) 'item_id': itemId,
      if (blobId != null) 'blob_id': blobId,
      if (blobRevision != null) 'blob_revision': blobRevision,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (state != null) 'state': state,
      if (stage != null) 'stage': stage,
      if (dependsOn != null) 'depends_on': dependsOn,
      if (operationBody != null) 'operation_body': operationBody,
      if (submittedSourceRevision != null)
        'submitted_source_revision': submittedSourceRevision,
      if (expectedSourceRevision != null)
        'expected_source_revision': expectedSourceRevision,
      if (attempt != null) 'attempt': attempt,
      if (availableAt != null) 'available_at': availableAt,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (progress != null) 'progress': progress,
      if (errorCode != null) 'error_code': errorCode,
      if (blockedReason != null) 'blocked_reason': blockedReason,
      if (configRevision != null) 'config_revision': configRevision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? itemId,
    Value<String?>? blobId,
    Value<int?>? blobRevision,
    Value<String>? dedupeKey,
    Value<String>? state,
    Value<String>? stage,
    Value<String?>? dependsOn,
    Value<String?>? operationBody,
    Value<int?>? submittedSourceRevision,
    Value<int?>? expectedSourceRevision,
    Value<int>? attempt,
    Value<int>? availableAt,
    Value<String?>? leaseOwner,
    Value<int?>? leaseUntil,
    Value<double>? progress,
    Value<String?>? errorCode,
    Value<String?>? blockedReason,
    Value<int>? configRevision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkQueueCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      itemId: itemId ?? this.itemId,
      blobId: blobId ?? this.blobId,
      blobRevision: blobRevision ?? this.blobRevision,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      state: state ?? this.state,
      stage: stage ?? this.stage,
      dependsOn: dependsOn ?? this.dependsOn,
      operationBody: operationBody ?? this.operationBody,
      submittedSourceRevision:
          submittedSourceRevision ?? this.submittedSourceRevision,
      expectedSourceRevision:
          expectedSourceRevision ?? this.expectedSourceRevision,
      attempt: attempt ?? this.attempt,
      availableAt: availableAt ?? this.availableAt,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      progress: progress ?? this.progress,
      errorCode: errorCode ?? this.errorCode,
      blockedReason: blockedReason ?? this.blockedReason,
      configRevision: configRevision ?? this.configRevision,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (blobRevision.present) {
      map['blob_revision'] = Variable<int>(blobRevision.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (dependsOn.present) {
      map['depends_on'] = Variable<String>(dependsOn.value);
    }
    if (operationBody.present) {
      map['operation_body'] = Variable<String>(operationBody.value);
    }
    if (submittedSourceRevision.present) {
      map['submitted_source_revision'] = Variable<int>(
        submittedSourceRevision.value,
      );
    }
    if (expectedSourceRevision.present) {
      map['expected_source_revision'] = Variable<int>(
        expectedSourceRevision.value,
      );
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<int>(availableAt.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (blockedReason.present) {
      map['blocked_reason'] = Variable<String>(blockedReason.value);
    }
    if (configRevision.present) {
      map['config_revision'] = Variable<int>(configRevision.value);
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
    return (StringBuffer('WorkQueueCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('itemId: $itemId, ')
          ..write('blobId: $blobId, ')
          ..write('blobRevision: $blobRevision, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('state: $state, ')
          ..write('stage: $stage, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('operationBody: $operationBody, ')
          ..write('submittedSourceRevision: $submittedSourceRevision, ')
          ..write('expectedSourceRevision: $expectedSourceRevision, ')
          ..write('attempt: $attempt, ')
          ..write('availableAt: $availableAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('progress: $progress, ')
          ..write('errorCode: $errorCode, ')
          ..write('blockedReason: $blockedReason, ')
          ..write('configRevision: $configRevision, ')
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
  late final $VaultRetentionPoliciesTable vaultRetentionPolicies =
      $VaultRetentionPoliciesTable(this);
  late final $BlobGcDecisionsTable blobGcDecisions = $BlobGcDecisionsTable(
    this,
  );
  late final $TextContentsTable textContents = $TextContentsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $WorkQueueTable workQueue = $WorkQueueTable(this);
  late final $ItemContactsTable itemContacts = $ItemContactsTable(this);
  late final WorkspacesDao workspacesDao = WorkspacesDao(this as AppDatabase);
  late final RecordingDraftsDao recordingDraftsDao = RecordingDraftsDao(
    this as AppDatabase,
  );
  late final SpacesDao spacesDao = SpacesDao(this as AppDatabase);
  late final MatomesDao matomesDao = MatomesDao(this as AppDatabase);
  late final ContactsDao contactsDao = ContactsDao(this as AppDatabase);
  late final ItemsDao itemsDao = ItemsDao(this as AppDatabase);
  late final WorkQueueDao workQueueDao = WorkQueueDao(this as AppDatabase);
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
    vaultRetentionPolicies,
    blobGcDecisions,
    textContents,
    items,
    workQueue,
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
      required String segmentHandlesJson,
      Value<int> durationMs,
      Value<String> sessionId,
      Value<String> captureKind,
      Value<String> backend,
      Value<String?> stagingHandle,
      Value<String> codec,
      Value<String> state,
      Value<String?> heartbeatAt,
    });
typedef $$RecordingDraftsTableUpdateCompanionBuilder =
    RecordingDraftsCompanion Function({
      Value<int> id,
      Value<String> createdAt,
      Value<String> segmentHandlesJson,
      Value<int> durationMs,
      Value<String> sessionId,
      Value<String> captureKind,
      Value<String> backend,
      Value<String?> stagingHandle,
      Value<String> codec,
      Value<String> state,
      Value<String?> heartbeatAt,
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

  ColumnFilters<String> get segmentHandlesJson => $composableBuilder(
    column: $table.segmentHandlesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureKind => $composableBuilder(
    column: $table.captureKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backend => $composableBuilder(
    column: $table.backend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stagingHandle => $composableBuilder(
    column: $table.stagingHandle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heartbeatAt => $composableBuilder(
    column: $table.heartbeatAt,
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

  ColumnOrderings<String> get segmentHandlesJson => $composableBuilder(
    column: $table.segmentHandlesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureKind => $composableBuilder(
    column: $table.captureKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backend => $composableBuilder(
    column: $table.backend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stagingHandle => $composableBuilder(
    column: $table.stagingHandle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heartbeatAt => $composableBuilder(
    column: $table.heartbeatAt,
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

  GeneratedColumn<String> get segmentHandlesJson => $composableBuilder(
    column: $table.segmentHandlesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get captureKind => $composableBuilder(
    column: $table.captureKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backend =>
      $composableBuilder(column: $table.backend, builder: (column) => column);

  GeneratedColumn<String> get stagingHandle => $composableBuilder(
    column: $table.stagingHandle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get codec =>
      $composableBuilder(column: $table.codec, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get heartbeatAt => $composableBuilder(
    column: $table.heartbeatAt,
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
                Value<String> segmentHandlesJson = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> captureKind = const Value.absent(),
                Value<String> backend = const Value.absent(),
                Value<String?> stagingHandle = const Value.absent(),
                Value<String> codec = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> heartbeatAt = const Value.absent(),
              }) => RecordingDraftsCompanion(
                id: id,
                createdAt: createdAt,
                segmentHandlesJson: segmentHandlesJson,
                durationMs: durationMs,
                sessionId: sessionId,
                captureKind: captureKind,
                backend: backend,
                stagingHandle: stagingHandle,
                codec: codec,
                state: state,
                heartbeatAt: heartbeatAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String createdAt,
                required String segmentHandlesJson,
                Value<int> durationMs = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> captureKind = const Value.absent(),
                Value<String> backend = const Value.absent(),
                Value<String?> stagingHandle = const Value.absent(),
                Value<String> codec = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> heartbeatAt = const Value.absent(),
              }) => RecordingDraftsCompanion.insert(
                id: id,
                createdAt: createdAt,
                segmentHandlesJson: segmentHandlesJson,
                durationMs: durationMs,
                sessionId: sessionId,
                captureKind: captureKind,
                backend: backend,
                stagingHandle: stagingHandle,
                codec: codec,
                state: state,
                heartbeatAt: heartbeatAt,
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
      Value<String?> originalExtension,
      Value<String?> contentType,
      Value<int> byteSize,
      Value<String?> checksumSha256,
      required String mediaType,
      Value<int?> duration,
      Value<String> uploadState,
      Value<int> uploadGeneration,
      Value<int?> uploadedAt,
      Value<String?> multipartContext,
      Value<String> openPolicy,
      Value<String?> blobId,
      Value<String> blobState,
      Value<String> cipherFormat,
      Value<int> cipherVersion,
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
      Value<String?> originalExtension,
      Value<String?> contentType,
      Value<int> byteSize,
      Value<String?> checksumSha256,
      Value<String> mediaType,
      Value<int?> duration,
      Value<String> uploadState,
      Value<int> uploadGeneration,
      Value<int?> uploadedAt,
      Value<String?> multipartContext,
      Value<String> openPolicy,
      Value<String?> blobId,
      Value<String> blobState,
      Value<String> cipherFormat,
      Value<int> cipherVersion,
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

  ColumnFilters<String> get originalExtension => $composableBuilder(
    column: $table.originalExtension,
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

  ColumnFilters<String> get openPolicy => $composableBuilder(
    column: $table.openPolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobState => $composableBuilder(
    column: $table.blobState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cipherFormat => $composableBuilder(
    column: $table.cipherFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cipherVersion => $composableBuilder(
    column: $table.cipherVersion,
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

  ColumnOrderings<String> get originalExtension => $composableBuilder(
    column: $table.originalExtension,
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

  ColumnOrderings<String> get openPolicy => $composableBuilder(
    column: $table.openPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobState => $composableBuilder(
    column: $table.blobState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cipherFormat => $composableBuilder(
    column: $table.cipherFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cipherVersion => $composableBuilder(
    column: $table.cipherVersion,
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

  GeneratedColumn<String> get originalExtension => $composableBuilder(
    column: $table.originalExtension,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get openPolicy => $composableBuilder(
    column: $table.openPolicy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get blobState =>
      $composableBuilder(column: $table.blobState, builder: (column) => column);

  GeneratedColumn<String> get cipherFormat => $composableBuilder(
    column: $table.cipherFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cipherVersion => $composableBuilder(
    column: $table.cipherVersion,
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
                Value<String?> originalExtension = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> checksumSha256 = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> uploadGeneration = const Value.absent(),
                Value<int?> uploadedAt = const Value.absent(),
                Value<String?> multipartContext = const Value.absent(),
                Value<String> openPolicy = const Value.absent(),
                Value<String?> blobId = const Value.absent(),
                Value<String> blobState = const Value.absent(),
                Value<String> cipherFormat = const Value.absent(),
                Value<int> cipherVersion = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileBlobsCompanion(
                id: id,
                coreId: coreId,
                storageKey: storageKey,
                filename: filename,
                originalExtension: originalExtension,
                contentType: contentType,
                byteSize: byteSize,
                checksumSha256: checksumSha256,
                mediaType: mediaType,
                duration: duration,
                uploadState: uploadState,
                uploadGeneration: uploadGeneration,
                uploadedAt: uploadedAt,
                multipartContext: multipartContext,
                openPolicy: openPolicy,
                blobId: blobId,
                blobState: blobState,
                cipherFormat: cipherFormat,
                cipherVersion: cipherVersion,
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
                Value<String?> originalExtension = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> checksumSha256 = const Value.absent(),
                required String mediaType,
                Value<int?> duration = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> uploadGeneration = const Value.absent(),
                Value<int?> uploadedAt = const Value.absent(),
                Value<String?> multipartContext = const Value.absent(),
                Value<String> openPolicy = const Value.absent(),
                Value<String?> blobId = const Value.absent(),
                Value<String> blobState = const Value.absent(),
                Value<String> cipherFormat = const Value.absent(),
                Value<int> cipherVersion = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FileBlobsCompanion.insert(
                id: id,
                coreId: coreId,
                storageKey: storageKey,
                filename: filename,
                originalExtension: originalExtension,
                contentType: contentType,
                byteSize: byteSize,
                checksumSha256: checksumSha256,
                mediaType: mediaType,
                duration: duration,
                uploadState: uploadState,
                uploadGeneration: uploadGeneration,
                uploadedAt: uploadedAt,
                multipartContext: multipartContext,
                openPolicy: openPolicy,
                blobId: blobId,
                blobState: blobState,
                cipherFormat: cipherFormat,
                cipherVersion: cipherVersion,
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
typedef $$VaultRetentionPoliciesTableCreateCompanionBuilder =
    VaultRetentionPoliciesCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<int?> expiryDays,
      required int updatedAt,
    });
typedef $$VaultRetentionPoliciesTableUpdateCompanionBuilder =
    VaultRetentionPoliciesCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<int?> expiryDays,
      Value<int> updatedAt,
    });

class $$VaultRetentionPoliciesTableFilterComposer
    extends Composer<_$AppDatabase, $VaultRetentionPoliciesTable> {
  $$VaultRetentionPoliciesTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiryDays => $composableBuilder(
    column: $table.expiryDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultRetentionPoliciesTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultRetentionPoliciesTable> {
  $$VaultRetentionPoliciesTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiryDays => $composableBuilder(
    column: $table.expiryDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultRetentionPoliciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultRetentionPoliciesTable> {
  $$VaultRetentionPoliciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get expiryDays => $composableBuilder(
    column: $table.expiryDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VaultRetentionPoliciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultRetentionPoliciesTable,
          VaultRetentionPolicyRow,
          $$VaultRetentionPoliciesTableFilterComposer,
          $$VaultRetentionPoliciesTableOrderingComposer,
          $$VaultRetentionPoliciesTableAnnotationComposer,
          $$VaultRetentionPoliciesTableCreateCompanionBuilder,
          $$VaultRetentionPoliciesTableUpdateCompanionBuilder,
          (
            VaultRetentionPolicyRow,
            BaseReferences<
              _$AppDatabase,
              $VaultRetentionPoliciesTable,
              VaultRetentionPolicyRow
            >,
          ),
          VaultRetentionPolicyRow,
          PrefetchHooks Function()
        > {
  $$VaultRetentionPoliciesTableTableManager(
    _$AppDatabase db,
    $VaultRetentionPoliciesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultRetentionPoliciesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$VaultRetentionPoliciesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VaultRetentionPoliciesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> expiryDays = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => VaultRetentionPoliciesCompanion(
                id: id,
                mode: mode,
                expiryDays: expiryDays,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> expiryDays = const Value.absent(),
                required int updatedAt,
              }) => VaultRetentionPoliciesCompanion.insert(
                id: id,
                mode: mode,
                expiryDays: expiryDays,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultRetentionPoliciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultRetentionPoliciesTable,
      VaultRetentionPolicyRow,
      $$VaultRetentionPoliciesTableFilterComposer,
      $$VaultRetentionPoliciesTableOrderingComposer,
      $$VaultRetentionPoliciesTableAnnotationComposer,
      $$VaultRetentionPoliciesTableCreateCompanionBuilder,
      $$VaultRetentionPoliciesTableUpdateCompanionBuilder,
      (
        VaultRetentionPolicyRow,
        BaseReferences<
          _$AppDatabase,
          $VaultRetentionPoliciesTable,
          VaultRetentionPolicyRow
        >,
      ),
      VaultRetentionPolicyRow,
      PrefetchHooks Function()
    >;
typedef $$BlobGcDecisionsTableCreateCompanionBuilder =
    BlobGcDecisionsCompanion Function({
      required String blobId,
      required String decision,
      required String reason,
      required int decidedAt,
      Value<int> rowid,
    });
typedef $$BlobGcDecisionsTableUpdateCompanionBuilder =
    BlobGcDecisionsCompanion Function({
      Value<String> blobId,
      Value<String> decision,
      Value<String> reason,
      Value<int> decidedAt,
      Value<int> rowid,
    });

class $$BlobGcDecisionsTableFilterComposer
    extends Composer<_$AppDatabase, $BlobGcDecisionsTable> {
  $$BlobGcDecisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlobGcDecisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlobGcDecisionsTable> {
  $$BlobGcDecisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlobGcDecisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlobGcDecisionsTable> {
  $$BlobGcDecisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get decision =>
      $composableBuilder(column: $table.decision, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get decidedAt =>
      $composableBuilder(column: $table.decidedAt, builder: (column) => column);
}

class $$BlobGcDecisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlobGcDecisionsTable,
          BlobGcDecisionRow,
          $$BlobGcDecisionsTableFilterComposer,
          $$BlobGcDecisionsTableOrderingComposer,
          $$BlobGcDecisionsTableAnnotationComposer,
          $$BlobGcDecisionsTableCreateCompanionBuilder,
          $$BlobGcDecisionsTableUpdateCompanionBuilder,
          (
            BlobGcDecisionRow,
            BaseReferences<
              _$AppDatabase,
              $BlobGcDecisionsTable,
              BlobGcDecisionRow
            >,
          ),
          BlobGcDecisionRow,
          PrefetchHooks Function()
        > {
  $$BlobGcDecisionsTableTableManager(
    _$AppDatabase db,
    $BlobGcDecisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlobGcDecisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlobGcDecisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlobGcDecisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blobId = const Value.absent(),
                Value<String> decision = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> decidedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlobGcDecisionsCompanion(
                blobId: blobId,
                decision: decision,
                reason: reason,
                decidedAt: decidedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blobId,
                required String decision,
                required String reason,
                required int decidedAt,
                Value<int> rowid = const Value.absent(),
              }) => BlobGcDecisionsCompanion.insert(
                blobId: blobId,
                decision: decision,
                reason: reason,
                decidedAt: decidedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlobGcDecisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlobGcDecisionsTable,
      BlobGcDecisionRow,
      $$BlobGcDecisionsTableFilterComposer,
      $$BlobGcDecisionsTableOrderingComposer,
      $$BlobGcDecisionsTableAnnotationComposer,
      $$BlobGcDecisionsTableCreateCompanionBuilder,
      $$BlobGcDecisionsTableUpdateCompanionBuilder,
      (
        BlobGcDecisionRow,
        BaseReferences<_$AppDatabase, $BlobGcDecisionsTable, BlobGcDecisionRow>,
      ),
      BlobGcDecisionRow,
      PrefetchHooks Function()
    >;
typedef $$TextContentsTableCreateCompanionBuilder =
    TextContentsCompanion Function({
      required String id,
      Value<int?> coreId,
      required String body,
      Value<String?> acceptedBody,
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
      Value<String?> acceptedBody,
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

  ColumnFilters<String> get acceptedBody => $composableBuilder(
    column: $table.acceptedBody,
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

  ColumnOrderings<String> get acceptedBody => $composableBuilder(
    column: $table.acceptedBody,
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

  GeneratedColumn<String> get acceptedBody => $composableBuilder(
    column: $table.acceptedBody,
    builder: (column) => column,
  );

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
                Value<String?> acceptedBody = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextContentsCompanion(
                id: id,
                coreId: coreId,
                body: body,
                acceptedBody: acceptedBody,
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
                Value<String?> acceptedBody = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TextContentsCompanion.insert(
                id: id,
                coreId: coreId,
                body: body,
                acceptedBody: acceptedBody,
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
      Value<int> processingAttempt,
      Value<int> sourceRevision,
      Value<int> acceptedSourceRevision,
      Value<int?> processingConfigRevision,
      Value<String> processingOutputs,
      Value<String> processingRequestedOutputs,
      Value<String?> processingError,
      Value<String?> processingErrorCode,
      Value<String?> fileBlobId,
      Value<String?> textContentId,
      Value<bool> isDirty,
      Value<String> syncState,
      Value<bool> isDeleted,
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
      Value<int> processingAttempt,
      Value<int> sourceRevision,
      Value<int> acceptedSourceRevision,
      Value<int?> processingConfigRevision,
      Value<String> processingOutputs,
      Value<String> processingRequestedOutputs,
      Value<String?> processingError,
      Value<String?> processingErrorCode,
      Value<String?> fileBlobId,
      Value<String?> textContentId,
      Value<bool> isDirty,
      Value<String> syncState,
      Value<bool> isDeleted,
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

  ColumnFilters<int> get processingAttempt => $composableBuilder(
    column: $table.processingAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acceptedSourceRevision => $composableBuilder(
    column: $table.acceptedSourceRevision,
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

  ColumnFilters<String> get processingRequestedOutputs => $composableBuilder(
    column: $table.processingRequestedOutputs,
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

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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

  ColumnOrderings<int> get processingAttempt => $composableBuilder(
    column: $table.processingAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acceptedSourceRevision => $composableBuilder(
    column: $table.acceptedSourceRevision,
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

  ColumnOrderings<String> get processingRequestedOutputs => $composableBuilder(
    column: $table.processingRequestedOutputs,
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

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
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

  GeneratedColumn<int> get processingAttempt => $composableBuilder(
    column: $table.processingAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acceptedSourceRevision => $composableBuilder(
    column: $table.acceptedSourceRevision,
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

  GeneratedColumn<String> get processingRequestedOutputs => $composableBuilder(
    column: $table.processingRequestedOutputs,
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

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

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
                Value<int> processingAttempt = const Value.absent(),
                Value<int> sourceRevision = const Value.absent(),
                Value<int> acceptedSourceRevision = const Value.absent(),
                Value<int?> processingConfigRevision = const Value.absent(),
                Value<String> processingOutputs = const Value.absent(),
                Value<String> processingRequestedOutputs = const Value.absent(),
                Value<String?> processingError = const Value.absent(),
                Value<String?> processingErrorCode = const Value.absent(),
                Value<String?> fileBlobId = const Value.absent(),
                Value<String?> textContentId = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
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
                processingAttempt: processingAttempt,
                sourceRevision: sourceRevision,
                acceptedSourceRevision: acceptedSourceRevision,
                processingConfigRevision: processingConfigRevision,
                processingOutputs: processingOutputs,
                processingRequestedOutputs: processingRequestedOutputs,
                processingError: processingError,
                processingErrorCode: processingErrorCode,
                fileBlobId: fileBlobId,
                textContentId: textContentId,
                isDirty: isDirty,
                syncState: syncState,
                isDeleted: isDeleted,
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
                Value<int> processingAttempt = const Value.absent(),
                Value<int> sourceRevision = const Value.absent(),
                Value<int> acceptedSourceRevision = const Value.absent(),
                Value<int?> processingConfigRevision = const Value.absent(),
                Value<String> processingOutputs = const Value.absent(),
                Value<String> processingRequestedOutputs = const Value.absent(),
                Value<String?> processingError = const Value.absent(),
                Value<String?> processingErrorCode = const Value.absent(),
                Value<String?> fileBlobId = const Value.absent(),
                Value<String?> textContentId = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
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
                processingAttempt: processingAttempt,
                sourceRevision: sourceRevision,
                acceptedSourceRevision: acceptedSourceRevision,
                processingConfigRevision: processingConfigRevision,
                processingOutputs: processingOutputs,
                processingRequestedOutputs: processingRequestedOutputs,
                processingError: processingError,
                processingErrorCode: processingErrorCode,
                fileBlobId: fileBlobId,
                textContentId: textContentId,
                isDirty: isDirty,
                syncState: syncState,
                isDeleted: isDeleted,
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
typedef $$WorkQueueTableCreateCompanionBuilder =
    WorkQueueCompanion Function({
      required String id,
      required String kind,
      required String itemId,
      Value<String?> blobId,
      Value<int?> blobRevision,
      required String dedupeKey,
      required String state,
      required String stage,
      Value<String?> dependsOn,
      Value<String?> operationBody,
      Value<int?> submittedSourceRevision,
      Value<int?> expectedSourceRevision,
      Value<int> attempt,
      required int availableAt,
      Value<String?> leaseOwner,
      Value<int?> leaseUntil,
      Value<double> progress,
      Value<String?> errorCode,
      Value<String?> blockedReason,
      Value<int> configRevision,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$WorkQueueTableUpdateCompanionBuilder =
    WorkQueueCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> itemId,
      Value<String?> blobId,
      Value<int?> blobRevision,
      Value<String> dedupeKey,
      Value<String> state,
      Value<String> stage,
      Value<String?> dependsOn,
      Value<String?> operationBody,
      Value<int?> submittedSourceRevision,
      Value<int?> expectedSourceRevision,
      Value<int> attempt,
      Value<int> availableAt,
      Value<String?> leaseOwner,
      Value<int?> leaseUntil,
      Value<double> progress,
      Value<String?> errorCode,
      Value<String?> blockedReason,
      Value<int> configRevision,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$WorkQueueTableFilterComposer
    extends Composer<_$AppDatabase, $WorkQueueTable> {
  $$WorkQueueTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blobRevision => $composableBuilder(
    column: $table.blobRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationBody => $composableBuilder(
    column: $table.operationBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get submittedSourceRevision => $composableBuilder(
    column: $table.submittedSourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedSourceRevision => $composableBuilder(
    column: $table.expectedSourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockedReason => $composableBuilder(
    column: $table.blockedReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get configRevision => $composableBuilder(
    column: $table.configRevision,
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

class $$WorkQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkQueueTable> {
  $$WorkQueueTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blobRevision => $composableBuilder(
    column: $table.blobRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationBody => $composableBuilder(
    column: $table.operationBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get submittedSourceRevision => $composableBuilder(
    column: $table.submittedSourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedSourceRevision => $composableBuilder(
    column: $table.expectedSourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockedReason => $composableBuilder(
    column: $table.blockedReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get configRevision => $composableBuilder(
    column: $table.configRevision,
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

class $$WorkQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkQueueTable> {
  $$WorkQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<int> get blobRevision => $composableBuilder(
    column: $table.blobRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get dependsOn =>
      $composableBuilder(column: $table.dependsOn, builder: (column) => column);

  GeneratedColumn<String> get operationBody => $composableBuilder(
    column: $table.operationBody,
    builder: (column) => column,
  );

  GeneratedColumn<int> get submittedSourceRevision => $composableBuilder(
    column: $table.submittedSourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedSourceRevision => $composableBuilder(
    column: $table.expectedSourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<int> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get blockedReason => $composableBuilder(
    column: $table.blockedReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get configRevision => $composableBuilder(
    column: $table.configRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkQueueTable,
          WorkQueueRow,
          $$WorkQueueTableFilterComposer,
          $$WorkQueueTableOrderingComposer,
          $$WorkQueueTableAnnotationComposer,
          $$WorkQueueTableCreateCompanionBuilder,
          $$WorkQueueTableUpdateCompanionBuilder,
          (
            WorkQueueRow,
            BaseReferences<_$AppDatabase, $WorkQueueTable, WorkQueueRow>,
          ),
          WorkQueueRow,
          PrefetchHooks Function()
        > {
  $$WorkQueueTableTableManager(_$AppDatabase db, $WorkQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> blobId = const Value.absent(),
                Value<int?> blobRevision = const Value.absent(),
                Value<String> dedupeKey = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String?> dependsOn = const Value.absent(),
                Value<String?> operationBody = const Value.absent(),
                Value<int?> submittedSourceRevision = const Value.absent(),
                Value<int?> expectedSourceRevision = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<int> availableAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> blockedReason = const Value.absent(),
                Value<int> configRevision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkQueueCompanion(
                id: id,
                kind: kind,
                itemId: itemId,
                blobId: blobId,
                blobRevision: blobRevision,
                dedupeKey: dedupeKey,
                state: state,
                stage: stage,
                dependsOn: dependsOn,
                operationBody: operationBody,
                submittedSourceRevision: submittedSourceRevision,
                expectedSourceRevision: expectedSourceRevision,
                attempt: attempt,
                availableAt: availableAt,
                leaseOwner: leaseOwner,
                leaseUntil: leaseUntil,
                progress: progress,
                errorCode: errorCode,
                blockedReason: blockedReason,
                configRevision: configRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String itemId,
                Value<String?> blobId = const Value.absent(),
                Value<int?> blobRevision = const Value.absent(),
                required String dedupeKey,
                required String state,
                required String stage,
                Value<String?> dependsOn = const Value.absent(),
                Value<String?> operationBody = const Value.absent(),
                Value<int?> submittedSourceRevision = const Value.absent(),
                Value<int?> expectedSourceRevision = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                required int availableAt,
                Value<String?> leaseOwner = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> blockedReason = const Value.absent(),
                Value<int> configRevision = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkQueueCompanion.insert(
                id: id,
                kind: kind,
                itemId: itemId,
                blobId: blobId,
                blobRevision: blobRevision,
                dedupeKey: dedupeKey,
                state: state,
                stage: stage,
                dependsOn: dependsOn,
                operationBody: operationBody,
                submittedSourceRevision: submittedSourceRevision,
                expectedSourceRevision: expectedSourceRevision,
                attempt: attempt,
                availableAt: availableAt,
                leaseOwner: leaseOwner,
                leaseUntil: leaseUntil,
                progress: progress,
                errorCode: errorCode,
                blockedReason: blockedReason,
                configRevision: configRevision,
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

typedef $$WorkQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkQueueTable,
      WorkQueueRow,
      $$WorkQueueTableFilterComposer,
      $$WorkQueueTableOrderingComposer,
      $$WorkQueueTableAnnotationComposer,
      $$WorkQueueTableCreateCompanionBuilder,
      $$WorkQueueTableUpdateCompanionBuilder,
      (
        WorkQueueRow,
        BaseReferences<_$AppDatabase, $WorkQueueTable, WorkQueueRow>,
      ),
      WorkQueueRow,
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
  $$VaultRetentionPoliciesTableTableManager get vaultRetentionPolicies =>
      $$VaultRetentionPoliciesTableTableManager(
        _db,
        _db.vaultRetentionPolicies,
      );
  $$BlobGcDecisionsTableTableManager get blobGcDecisions =>
      $$BlobGcDecisionsTableTableManager(_db, _db.blobGcDecisions);
  $$TextContentsTableTableManager get textContents =>
      $$TextContentsTableTableManager(_db, _db.textContents);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$WorkQueueTableTableManager get workQueue =>
      $$WorkQueueTableTableManager(_db, _db.workQueue);
  $$ItemContactsTableTableManager get itemContacts =>
      $$ItemContactsTableTableManager(_db, _db.itemContacts);
}
