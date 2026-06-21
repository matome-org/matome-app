// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, RecordingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<String> timestamp = GeneratedColumn<String>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<String> duration = GeneratedColumn<String>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _badgeMeta = const VerificationMeta('badge');
  @override
  late final GeneratedColumn<String> badge = GeneratedColumn<String>(
    'badge',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Inbox'),
  );
  static const VerificationMeta _isProcessingMeta = const VerificationMeta(
    'isProcessing',
  );
  @override
  late final GeneratedColumn<int> isProcessing = GeneratedColumn<int>(
    'isProcessing',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _audioFilePathMeta = const VerificationMeta(
    'audioFilePath',
  );
  @override
  late final GeneratedColumn<String> audioFilePath = GeneratedColumn<String>(
    'audioFilePath',
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
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspaceId',
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
    'mediaType',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('audio'),
  );
  static const VerificationMeta _processingStatusMeta = const VerificationMeta(
    'processingStatus',
  );
  @override
  late final GeneratedColumn<String> processingStatus = GeneratedColumn<String>(
    'processingStatus',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('done'),
  );
  static const VerificationMeta _coreIdMeta = const VerificationMeta('coreId');
  @override
  late final GeneratedColumn<int> coreId = GeneratedColumn<int>(
    'coreId',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesLegacyRawMeta = const VerificationMeta(
    'notesLegacyRaw',
  );
  @override
  late final GeneratedColumn<String> notesLegacyRaw = GeneratedColumn<String>(
    'notes_legacy_raw',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    summary,
    timestamp,
    duration,
    badge,
    isProcessing,
    audioFilePath,
    createdAt,
    notes,
    workspaceId,
    mediaType,
    processingStatus,
    coreId,
    matomeId,
    transcript,
    notesLegacyRaw,
    originalExtension,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('badge')) {
      context.handle(
        _badgeMeta,
        badge.isAcceptableOrUnknown(data['badge']!, _badgeMeta),
      );
    }
    if (data.containsKey('isProcessing')) {
      context.handle(
        _isProcessingMeta,
        isProcessing.isAcceptableOrUnknown(
          data['isProcessing']!,
          _isProcessingMeta,
        ),
      );
    }
    if (data.containsKey('audioFilePath')) {
      context.handle(
        _audioFilePathMeta,
        audioFilePath.isAcceptableOrUnknown(
          data['audioFilePath']!,
          _audioFilePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioFilePathMeta);
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('workspaceId')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspaceId']!,
          _workspaceIdMeta,
        ),
      );
    }
    if (data.containsKey('mediaType')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['mediaType']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('processingStatus')) {
      context.handle(
        _processingStatusMeta,
        processingStatus.isAcceptableOrUnknown(
          data['processingStatus']!,
          _processingStatusMeta,
        ),
      );
    }
    if (data.containsKey('coreId')) {
      context.handle(
        _coreIdMeta,
        coreId.isAcceptableOrUnknown(data['coreId']!, _coreIdMeta),
      );
    }
    if (data.containsKey('matome_id')) {
      context.handle(
        _matomeIdMeta,
        matomeId.isAcceptableOrUnknown(data['matome_id']!, _matomeIdMeta),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('notes_legacy_raw')) {
      context.handle(
        _notesLegacyRawMeta,
        notesLegacyRaw.isAcceptableOrUnknown(
          data['notes_legacy_raw']!,
          _notesLegacyRawMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timestamp'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration'],
      )!,
      badge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}badge'],
      )!,
      isProcessing: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isProcessing'],
      )!,
      audioFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audioFilePath'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspaceId'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mediaType'],
      )!,
      processingStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processingStatus'],
      )!,
      coreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coreId'],
      ),
      matomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matome_id'],
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      notesLegacyRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes_legacy_raw'],
      ),
      originalExtension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_extension'],
      ),
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }
}

class RecordingRow extends DataClass implements Insertable<RecordingRow> {
  final String id;
  final String title;
  final String? summary;
  final String timestamp;
  final String duration;
  final String badge;
  final int isProcessing;
  final String audioFilePath;
  final int createdAt;
  final String? notes;
  final String? workspaceId;
  final String mediaType;
  final String processingStatus;
  final int? coreId;
  final String? matomeId;
  final String? transcript;
  final String? notesLegacyRaw;
  final String? originalExtension;
  const RecordingRow({
    required this.id,
    required this.title,
    this.summary,
    required this.timestamp,
    required this.duration,
    required this.badge,
    required this.isProcessing,
    required this.audioFilePath,
    required this.createdAt,
    this.notes,
    this.workspaceId,
    required this.mediaType,
    required this.processingStatus,
    this.coreId,
    this.matomeId,
    this.transcript,
    this.notesLegacyRaw,
    this.originalExtension,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['timestamp'] = Variable<String>(timestamp);
    map['duration'] = Variable<String>(duration);
    map['badge'] = Variable<String>(badge);
    map['isProcessing'] = Variable<int>(isProcessing);
    map['audioFilePath'] = Variable<String>(audioFilePath);
    map['createdAt'] = Variable<int>(createdAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || workspaceId != null) {
      map['workspaceId'] = Variable<String>(workspaceId);
    }
    map['mediaType'] = Variable<String>(mediaType);
    map['processingStatus'] = Variable<String>(processingStatus);
    if (!nullToAbsent || coreId != null) {
      map['coreId'] = Variable<int>(coreId);
    }
    if (!nullToAbsent || matomeId != null) {
      map['matome_id'] = Variable<String>(matomeId);
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || notesLegacyRaw != null) {
      map['notes_legacy_raw'] = Variable<String>(notesLegacyRaw);
    }
    if (!nullToAbsent || originalExtension != null) {
      map['original_extension'] = Variable<String>(originalExtension);
    }
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      id: Value(id),
      title: Value(title),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      timestamp: Value(timestamp),
      duration: Value(duration),
      badge: Value(badge),
      isProcessing: Value(isProcessing),
      audioFilePath: Value(audioFilePath),
      createdAt: Value(createdAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      workspaceId: workspaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(workspaceId),
      mediaType: Value(mediaType),
      processingStatus: Value(processingStatus),
      coreId: coreId == null && nullToAbsent
          ? const Value.absent()
          : Value(coreId),
      matomeId: matomeId == null && nullToAbsent
          ? const Value.absent()
          : Value(matomeId),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      notesLegacyRaw: notesLegacyRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(notesLegacyRaw),
      originalExtension: originalExtension == null && nullToAbsent
          ? const Value.absent()
          : Value(originalExtension),
    );
  }

  factory RecordingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String?>(json['summary']),
      timestamp: serializer.fromJson<String>(json['timestamp']),
      duration: serializer.fromJson<String>(json['duration']),
      badge: serializer.fromJson<String>(json['badge']),
      isProcessing: serializer.fromJson<int>(json['isProcessing']),
      audioFilePath: serializer.fromJson<String>(json['audioFilePath']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      workspaceId: serializer.fromJson<String?>(json['workspaceId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      processingStatus: serializer.fromJson<String>(json['processingStatus']),
      coreId: serializer.fromJson<int?>(json['coreId']),
      matomeId: serializer.fromJson<String?>(json['matomeId']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      notesLegacyRaw: serializer.fromJson<String?>(json['notesLegacyRaw']),
      originalExtension: serializer.fromJson<String?>(
        json['originalExtension'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String?>(summary),
      'timestamp': serializer.toJson<String>(timestamp),
      'duration': serializer.toJson<String>(duration),
      'badge': serializer.toJson<String>(badge),
      'isProcessing': serializer.toJson<int>(isProcessing),
      'audioFilePath': serializer.toJson<String>(audioFilePath),
      'createdAt': serializer.toJson<int>(createdAt),
      'notes': serializer.toJson<String?>(notes),
      'workspaceId': serializer.toJson<String?>(workspaceId),
      'mediaType': serializer.toJson<String>(mediaType),
      'processingStatus': serializer.toJson<String>(processingStatus),
      'coreId': serializer.toJson<int?>(coreId),
      'matomeId': serializer.toJson<String?>(matomeId),
      'transcript': serializer.toJson<String?>(transcript),
      'notesLegacyRaw': serializer.toJson<String?>(notesLegacyRaw),
      'originalExtension': serializer.toJson<String?>(originalExtension),
    };
  }

  RecordingRow copyWith({
    String? id,
    String? title,
    Value<String?> summary = const Value.absent(),
    String? timestamp,
    String? duration,
    String? badge,
    int? isProcessing,
    String? audioFilePath,
    int? createdAt,
    Value<String?> notes = const Value.absent(),
    Value<String?> workspaceId = const Value.absent(),
    String? mediaType,
    String? processingStatus,
    Value<int?> coreId = const Value.absent(),
    Value<String?> matomeId = const Value.absent(),
    Value<String?> transcript = const Value.absent(),
    Value<String?> notesLegacyRaw = const Value.absent(),
    Value<String?> originalExtension = const Value.absent(),
  }) => RecordingRow(
    id: id ?? this.id,
    title: title ?? this.title,
    summary: summary.present ? summary.value : this.summary,
    timestamp: timestamp ?? this.timestamp,
    duration: duration ?? this.duration,
    badge: badge ?? this.badge,
    isProcessing: isProcessing ?? this.isProcessing,
    audioFilePath: audioFilePath ?? this.audioFilePath,
    createdAt: createdAt ?? this.createdAt,
    notes: notes.present ? notes.value : this.notes,
    workspaceId: workspaceId.present ? workspaceId.value : this.workspaceId,
    mediaType: mediaType ?? this.mediaType,
    processingStatus: processingStatus ?? this.processingStatus,
    coreId: coreId.present ? coreId.value : this.coreId,
    matomeId: matomeId.present ? matomeId.value : this.matomeId,
    transcript: transcript.present ? transcript.value : this.transcript,
    notesLegacyRaw: notesLegacyRaw.present
        ? notesLegacyRaw.value
        : this.notesLegacyRaw,
    originalExtension: originalExtension.present
        ? originalExtension.value
        : this.originalExtension,
  );
  RecordingRow copyWithCompanion(RecordingsCompanion data) {
    return RecordingRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      duration: data.duration.present ? data.duration.value : this.duration,
      badge: data.badge.present ? data.badge.value : this.badge,
      isProcessing: data.isProcessing.present
          ? data.isProcessing.value
          : this.isProcessing,
      audioFilePath: data.audioFilePath.present
          ? data.audioFilePath.value
          : this.audioFilePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      processingStatus: data.processingStatus.present
          ? data.processingStatus.value
          : this.processingStatus,
      coreId: data.coreId.present ? data.coreId.value : this.coreId,
      matomeId: data.matomeId.present ? data.matomeId.value : this.matomeId,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      notesLegacyRaw: data.notesLegacyRaw.present
          ? data.notesLegacyRaw.value
          : this.notesLegacyRaw,
      originalExtension: data.originalExtension.present
          ? data.originalExtension.value
          : this.originalExtension,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('timestamp: $timestamp, ')
          ..write('duration: $duration, ')
          ..write('badge: $badge, ')
          ..write('isProcessing: $isProcessing, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('mediaType: $mediaType, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('coreId: $coreId, ')
          ..write('matomeId: $matomeId, ')
          ..write('transcript: $transcript, ')
          ..write('notesLegacyRaw: $notesLegacyRaw, ')
          ..write('originalExtension: $originalExtension')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    summary,
    timestamp,
    duration,
    badge,
    isProcessing,
    audioFilePath,
    createdAt,
    notes,
    workspaceId,
    mediaType,
    processingStatus,
    coreId,
    matomeId,
    transcript,
    notesLegacyRaw,
    originalExtension,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.timestamp == this.timestamp &&
          other.duration == this.duration &&
          other.badge == this.badge &&
          other.isProcessing == this.isProcessing &&
          other.audioFilePath == this.audioFilePath &&
          other.createdAt == this.createdAt &&
          other.notes == this.notes &&
          other.workspaceId == this.workspaceId &&
          other.mediaType == this.mediaType &&
          other.processingStatus == this.processingStatus &&
          other.coreId == this.coreId &&
          other.matomeId == this.matomeId &&
          other.transcript == this.transcript &&
          other.notesLegacyRaw == this.notesLegacyRaw &&
          other.originalExtension == this.originalExtension);
}

class RecordingsCompanion extends UpdateCompanion<RecordingRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> summary;
  final Value<String> timestamp;
  final Value<String> duration;
  final Value<String> badge;
  final Value<int> isProcessing;
  final Value<String> audioFilePath;
  final Value<int> createdAt;
  final Value<String?> notes;
  final Value<String?> workspaceId;
  final Value<String> mediaType;
  final Value<String> processingStatus;
  final Value<int?> coreId;
  final Value<String?> matomeId;
  final Value<String?> transcript;
  final Value<String?> notesLegacyRaw;
  final Value<String?> originalExtension;
  final Value<int> rowid;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.duration = const Value.absent(),
    this.badge = const Value.absent(),
    this.isProcessing = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.coreId = const Value.absent(),
    this.matomeId = const Value.absent(),
    this.transcript = const Value.absent(),
    this.notesLegacyRaw = const Value.absent(),
    this.originalExtension = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordingsCompanion.insert({
    required String id,
    required String title,
    this.summary = const Value.absent(),
    required String timestamp,
    required String duration,
    this.badge = const Value.absent(),
    this.isProcessing = const Value.absent(),
    required String audioFilePath,
    required int createdAt,
    this.notes = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.coreId = const Value.absent(),
    this.matomeId = const Value.absent(),
    this.transcript = const Value.absent(),
    this.notesLegacyRaw = const Value.absent(),
    this.originalExtension = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       timestamp = Value(timestamp),
       duration = Value(duration),
       audioFilePath = Value(audioFilePath),
       createdAt = Value(createdAt);
  static Insertable<RecordingRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? timestamp,
    Expression<String>? duration,
    Expression<String>? badge,
    Expression<int>? isProcessing,
    Expression<String>? audioFilePath,
    Expression<int>? createdAt,
    Expression<String>? notes,
    Expression<String>? workspaceId,
    Expression<String>? mediaType,
    Expression<String>? processingStatus,
    Expression<int>? coreId,
    Expression<String>? matomeId,
    Expression<String>? transcript,
    Expression<String>? notesLegacyRaw,
    Expression<String>? originalExtension,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (timestamp != null) 'timestamp': timestamp,
      if (duration != null) 'duration': duration,
      if (badge != null) 'badge': badge,
      if (isProcessing != null) 'isProcessing': isProcessing,
      if (audioFilePath != null) 'audioFilePath': audioFilePath,
      if (createdAt != null) 'createdAt': createdAt,
      if (notes != null) 'notes': notes,
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (mediaType != null) 'mediaType': mediaType,
      if (processingStatus != null) 'processingStatus': processingStatus,
      if (coreId != null) 'coreId': coreId,
      if (matomeId != null) 'matome_id': matomeId,
      if (transcript != null) 'transcript': transcript,
      if (notesLegacyRaw != null) 'notes_legacy_raw': notesLegacyRaw,
      if (originalExtension != null) 'original_extension': originalExtension,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordingsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? summary,
    Value<String>? timestamp,
    Value<String>? duration,
    Value<String>? badge,
    Value<int>? isProcessing,
    Value<String>? audioFilePath,
    Value<int>? createdAt,
    Value<String?>? notes,
    Value<String?>? workspaceId,
    Value<String>? mediaType,
    Value<String>? processingStatus,
    Value<int?>? coreId,
    Value<String?>? matomeId,
    Value<String?>? transcript,
    Value<String?>? notesLegacyRaw,
    Value<String?>? originalExtension,
    Value<int>? rowid,
  }) {
    return RecordingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      badge: badge ?? this.badge,
      isProcessing: isProcessing ?? this.isProcessing,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      workspaceId: workspaceId ?? this.workspaceId,
      mediaType: mediaType ?? this.mediaType,
      processingStatus: processingStatus ?? this.processingStatus,
      coreId: coreId ?? this.coreId,
      matomeId: matomeId ?? this.matomeId,
      transcript: transcript ?? this.transcript,
      notesLegacyRaw: notesLegacyRaw ?? this.notesLegacyRaw,
      originalExtension: originalExtension ?? this.originalExtension,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<String>(timestamp.value);
    }
    if (duration.present) {
      map['duration'] = Variable<String>(duration.value);
    }
    if (badge.present) {
      map['badge'] = Variable<String>(badge.value);
    }
    if (isProcessing.present) {
      map['isProcessing'] = Variable<int>(isProcessing.value);
    }
    if (audioFilePath.present) {
      map['audioFilePath'] = Variable<String>(audioFilePath.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (workspaceId.present) {
      map['workspaceId'] = Variable<String>(workspaceId.value);
    }
    if (mediaType.present) {
      map['mediaType'] = Variable<String>(mediaType.value);
    }
    if (processingStatus.present) {
      map['processingStatus'] = Variable<String>(processingStatus.value);
    }
    if (coreId.present) {
      map['coreId'] = Variable<int>(coreId.value);
    }
    if (matomeId.present) {
      map['matome_id'] = Variable<String>(matomeId.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (notesLegacyRaw.present) {
      map['notes_legacy_raw'] = Variable<String>(notesLegacyRaw.value);
    }
    if (originalExtension.present) {
      map['original_extension'] = Variable<String>(originalExtension.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('timestamp: $timestamp, ')
          ..write('duration: $duration, ')
          ..write('badge: $badge, ')
          ..write('isProcessing: $isProcessing, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('mediaType: $mediaType, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('coreId: $coreId, ')
          ..write('matomeId: $matomeId, ')
          ..write('transcript: $transcript, ')
          ..write('notesLegacyRaw: $notesLegacyRaw, ')
          ..write('originalExtension: $originalExtension, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isDefault,
    createdAt,
    spaceType,
    ownerId,
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
  const WorkspaceRow({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.spaceType,
    this.ownerId,
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
    };
  }

  WorkspaceRow copyWith({
    String? id,
    String? name,
    int? isDefault,
    int? createdAt,
    String? spaceType,
    Value<String?> ownerId = const Value.absent(),
  }) => WorkspaceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    spaceType: spaceType ?? this.spaceType,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
  );
  WorkspaceRow copyWithCompanion(WorkspacesCompanion data) {
    return WorkspaceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      spaceType: data.spaceType.present ? data.spaceType.value : this.spaceType,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
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
          ..write('ownerId: $ownerId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, isDefault, createdAt, spaceType, ownerId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.spaceType == this.spaceType &&
          other.ownerId == this.ownerId);
}

class WorkspacesCompanion extends UpdateCompanion<WorkspaceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> isDefault;
  final Value<int> createdAt;
  final Value<String> spaceType;
  final Value<String?> ownerId;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.spaceType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    required String id,
    required String name,
    this.isDefault = const Value.absent(),
    required int createdAt,
    this.spaceType = const Value.absent(),
    this.ownerId = const Value.absent(),
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isDefault != null) 'isDefault': isDefault,
      if (createdAt != null) 'createdAt': createdAt,
      if (spaceType != null) 'space_type': spaceType,
      if (ownerId != null) 'owner_id': ownerId,
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
    Value<int>? rowid,
  }) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      spaceType: spaceType ?? this.spaceType,
      ownerId: ownerId ?? this.ownerId,
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
  final String metadata;
  final String? linkedUserId;
  final int createdAt;
  final int? coreId;
  const ContactRow({
    required this.id,
    required this.ownerId,
    required this.displayName,
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
    String? metadata,
    Value<String?> linkedUserId = const Value.absent(),
    int? createdAt,
    Value<int?> coreId = const Value.absent(),
  }) => ContactRow(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    displayName: displayName ?? this.displayName,
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
          other.metadata == this.metadata &&
          other.linkedUserId == this.linkedUserId &&
          other.createdAt == this.createdAt &&
          other.coreId == this.coreId);
}

class ContactsCompanion extends UpdateCompanion<ContactRow> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> displayName;
  final Value<String> metadata;
  final Value<String?> linkedUserId;
  final Value<int> createdAt;
  final Value<int?> coreId;
  final Value<int> rowid;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.displayName = const Value.absent(),
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecordingsTable recordings = $RecordingsTable(this);
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
  late final RecordingsDao recordingsDao = RecordingsDao(this as AppDatabase);
  late final WorkspacesDao workspacesDao = WorkspacesDao(this as AppDatabase);
  late final RecordingDraftsDao recordingDraftsDao = RecordingDraftsDao(
    this as AppDatabase,
  );
  late final SpacesDao spacesDao = SpacesDao(this as AppDatabase);
  late final MatomesDao matomesDao = MatomesDao(this as AppDatabase);
  late final ContactsDao contactsDao = ContactsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recordings,
    workspaces,
    recordingDrafts,
    spaceMembers,
    organizations,
    matomes,
    contacts,
    matomeContacts,
    spaceContacts,
    matomeShares,
  ];
}

typedef $$RecordingsTableCreateCompanionBuilder =
    RecordingsCompanion Function({
      required String id,
      required String title,
      Value<String?> summary,
      required String timestamp,
      required String duration,
      Value<String> badge,
      Value<int> isProcessing,
      required String audioFilePath,
      required int createdAt,
      Value<String?> notes,
      Value<String?> workspaceId,
      Value<String> mediaType,
      Value<String> processingStatus,
      Value<int?> coreId,
      Value<String?> matomeId,
      Value<String?> transcript,
      Value<String?> notesLegacyRaw,
      Value<String?> originalExtension,
      Value<int> rowid,
    });
typedef $$RecordingsTableUpdateCompanionBuilder =
    RecordingsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> summary,
      Value<String> timestamp,
      Value<String> duration,
      Value<String> badge,
      Value<int> isProcessing,
      Value<String> audioFilePath,
      Value<int> createdAt,
      Value<String?> notes,
      Value<String?> workspaceId,
      Value<String> mediaType,
      Value<String> processingStatus,
      Value<int?> coreId,
      Value<String?> matomeId,
      Value<String?> transcript,
      Value<String?> notesLegacyRaw,
      Value<String?> originalExtension,
      Value<int> rowid,
    });

class $$RecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get badge => $composableBuilder(
    column: $table.badge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isProcessing => $composableBuilder(
    column: $table.isProcessing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notesLegacyRaw => $composableBuilder(
    column: $table.notesLegacyRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalExtension => $composableBuilder(
    column: $table.originalExtension,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get badge => $composableBuilder(
    column: $table.badge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isProcessing => $composableBuilder(
    column: $table.isProcessing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coreId => $composableBuilder(
    column: $table.coreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matomeId => $composableBuilder(
    column: $table.matomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notesLegacyRaw => $composableBuilder(
    column: $table.notesLegacyRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalExtension => $composableBuilder(
    column: $table.originalExtension,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get badge =>
      $composableBuilder(column: $table.badge, builder: (column) => column);

  GeneratedColumn<int> get isProcessing => $composableBuilder(
    column: $table.isProcessing,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coreId =>
      $composableBuilder(column: $table.coreId, builder: (column) => column);

  GeneratedColumn<String> get matomeId =>
      $composableBuilder(column: $table.matomeId, builder: (column) => column);

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notesLegacyRaw => $composableBuilder(
    column: $table.notesLegacyRaw,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalExtension => $composableBuilder(
    column: $table.originalExtension,
    builder: (column) => column,
  );
}

class $$RecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingsTable,
          RecordingRow,
          $$RecordingsTableFilterComposer,
          $$RecordingsTableOrderingComposer,
          $$RecordingsTableAnnotationComposer,
          $$RecordingsTableCreateCompanionBuilder,
          $$RecordingsTableUpdateCompanionBuilder,
          (
            RecordingRow,
            BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>,
          ),
          RecordingRow,
          PrefetchHooks Function()
        > {
  $$RecordingsTableTableManager(_$AppDatabase db, $RecordingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> timestamp = const Value.absent(),
                Value<String> duration = const Value.absent(),
                Value<String> badge = const Value.absent(),
                Value<int> isProcessing = const Value.absent(),
                Value<String> audioFilePath = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> processingStatus = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<String?> matomeId = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> notesLegacyRaw = const Value.absent(),
                Value<String?> originalExtension = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingsCompanion(
                id: id,
                title: title,
                summary: summary,
                timestamp: timestamp,
                duration: duration,
                badge: badge,
                isProcessing: isProcessing,
                audioFilePath: audioFilePath,
                createdAt: createdAt,
                notes: notes,
                workspaceId: workspaceId,
                mediaType: mediaType,
                processingStatus: processingStatus,
                coreId: coreId,
                matomeId: matomeId,
                transcript: transcript,
                notesLegacyRaw: notesLegacyRaw,
                originalExtension: originalExtension,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> summary = const Value.absent(),
                required String timestamp,
                required String duration,
                Value<String> badge = const Value.absent(),
                Value<int> isProcessing = const Value.absent(),
                required String audioFilePath,
                required int createdAt,
                Value<String?> notes = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> processingStatus = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<String?> matomeId = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> notesLegacyRaw = const Value.absent(),
                Value<String?> originalExtension = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingsCompanion.insert(
                id: id,
                title: title,
                summary: summary,
                timestamp: timestamp,
                duration: duration,
                badge: badge,
                isProcessing: isProcessing,
                audioFilePath: audioFilePath,
                createdAt: createdAt,
                notes: notes,
                workspaceId: workspaceId,
                mediaType: mediaType,
                processingStatus: processingStatus,
                coreId: coreId,
                matomeId: matomeId,
                transcript: transcript,
                notesLegacyRaw: notesLegacyRaw,
                originalExtension: originalExtension,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingsTable,
      RecordingRow,
      $$RecordingsTableFilterComposer,
      $$RecordingsTableOrderingComposer,
      $$RecordingsTableAnnotationComposer,
      $$RecordingsTableCreateCompanionBuilder,
      $$RecordingsTableUpdateCompanionBuilder,
      (
        RecordingRow,
        BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>,
      ),
      RecordingRow,
      PrefetchHooks Function()
    >;
typedef $$WorkspacesTableCreateCompanionBuilder =
    WorkspacesCompanion Function({
      required String id,
      required String name,
      Value<int> isDefault,
      required int createdAt,
      Value<String> spaceType,
      Value<String?> ownerId,
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
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                spaceType: spaceType,
                ownerId: ownerId,
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
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion.insert(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                spaceType: spaceType,
                ownerId: ownerId,
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
                Value<String> metadata = const Value.absent(),
                Value<String?> linkedUserId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> coreId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                id: id,
                ownerId: ownerId,
                displayName: displayName,
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
                Value<String> metadata = const Value.absent(),
                Value<String?> linkedUserId = const Value.absent(),
                required int createdAt,
                Value<int?> coreId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                id: id,
                ownerId: ownerId,
                displayName: displayName,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
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
}
