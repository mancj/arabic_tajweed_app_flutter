// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_database.dart';

// ignore_for_file: type=lint
class $LogRowsTable extends LogRows with TableInfo<$LogRowsTable, LogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atomIdMeta = const VerificationMeta('atomId');
  @override
  late final GeneratedColumn<String> atomId = GeneratedColumn<String>(
    'atom_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fastEnoughMeta = const VerificationMeta(
    'fastEnough',
  );
  @override
  late final GeneratedColumn<bool> fastEnough = GeneratedColumn<bool>(
    'fast_enough',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fast_enough" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    atomId,
    sessionId,
    at,
    mode,
    correct,
    attempt,
    fastEnough,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('atom_id')) {
      context.handle(
        _atomIdMeta,
        atomId.isAcceptableOrUnknown(data['atom_id']!, _atomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_atomIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('fast_enough')) {
      context.handle(
        _fastEnoughMeta,
        fastEnough.isAcceptableOrUnknown(data['fast_enough']!, _fastEnoughMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      atomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}atom_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      ),
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      ),
      fastEnough: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fast_enough'],
      ),
    );
  }

  @override
  $LogRowsTable createAlias(String alias) {
    return $LogRowsTable(attachedDatabase, alias);
  }
}

class LogRow extends DataClass implements Insertable<LogRow> {
  final int id;

  /// 'introduced' или 'answer'. Дискриминатор подтипа LogEntry.
  final String kind;
  final String atomId;
  final int sessionId;
  final DateTime at;

  /// Дальше — поля только для 'answer'.
  final String? mode;
  final bool? correct;
  final int? attempt;
  final bool? fastEnough;
  const LogRow({
    required this.id,
    required this.kind,
    required this.atomId,
    required this.sessionId,
    required this.at,
    this.mode,
    this.correct,
    this.attempt,
    this.fastEnough,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['atom_id'] = Variable<String>(atomId);
    map['session_id'] = Variable<int>(sessionId);
    map['at'] = Variable<DateTime>(at);
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || correct != null) {
      map['correct'] = Variable<bool>(correct);
    }
    if (!nullToAbsent || attempt != null) {
      map['attempt'] = Variable<int>(attempt);
    }
    if (!nullToAbsent || fastEnough != null) {
      map['fast_enough'] = Variable<bool>(fastEnough);
    }
    return map;
  }

  LogRowsCompanion toCompanion(bool nullToAbsent) {
    return LogRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      atomId: Value(atomId),
      sessionId: Value(sessionId),
      at: Value(at),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      correct: correct == null && nullToAbsent
          ? const Value.absent()
          : Value(correct),
      attempt: attempt == null && nullToAbsent
          ? const Value.absent()
          : Value(attempt),
      fastEnough: fastEnough == null && nullToAbsent
          ? const Value.absent()
          : Value(fastEnough),
    );
  }

  factory LogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      atomId: serializer.fromJson<String>(json['atomId']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      at: serializer.fromJson<DateTime>(json['at']),
      mode: serializer.fromJson<String?>(json['mode']),
      correct: serializer.fromJson<bool?>(json['correct']),
      attempt: serializer.fromJson<int?>(json['attempt']),
      fastEnough: serializer.fromJson<bool?>(json['fastEnough']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'atomId': serializer.toJson<String>(atomId),
      'sessionId': serializer.toJson<int>(sessionId),
      'at': serializer.toJson<DateTime>(at),
      'mode': serializer.toJson<String?>(mode),
      'correct': serializer.toJson<bool?>(correct),
      'attempt': serializer.toJson<int?>(attempt),
      'fastEnough': serializer.toJson<bool?>(fastEnough),
    };
  }

  LogRow copyWith({
    int? id,
    String? kind,
    String? atomId,
    int? sessionId,
    DateTime? at,
    Value<String?> mode = const Value.absent(),
    Value<bool?> correct = const Value.absent(),
    Value<int?> attempt = const Value.absent(),
    Value<bool?> fastEnough = const Value.absent(),
  }) => LogRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    atomId: atomId ?? this.atomId,
    sessionId: sessionId ?? this.sessionId,
    at: at ?? this.at,
    mode: mode.present ? mode.value : this.mode,
    correct: correct.present ? correct.value : this.correct,
    attempt: attempt.present ? attempt.value : this.attempt,
    fastEnough: fastEnough.present ? fastEnough.value : this.fastEnough,
  );
  LogRow copyWithCompanion(LogRowsCompanion data) {
    return LogRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      atomId: data.atomId.present ? data.atomId.value : this.atomId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      at: data.at.present ? data.at.value : this.at,
      mode: data.mode.present ? data.mode.value : this.mode,
      correct: data.correct.present ? data.correct.value : this.correct,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      fastEnough: data.fastEnough.present
          ? data.fastEnough.value
          : this.fastEnough,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('atomId: $atomId, ')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('mode: $mode, ')
          ..write('correct: $correct, ')
          ..write('attempt: $attempt, ')
          ..write('fastEnough: $fastEnough')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    atomId,
    sessionId,
    at,
    mode,
    correct,
    attempt,
    fastEnough,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.atomId == this.atomId &&
          other.sessionId == this.sessionId &&
          other.at == this.at &&
          other.mode == this.mode &&
          other.correct == this.correct &&
          other.attempt == this.attempt &&
          other.fastEnough == this.fastEnough);
}

class LogRowsCompanion extends UpdateCompanion<LogRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> atomId;
  final Value<int> sessionId;
  final Value<DateTime> at;
  final Value<String?> mode;
  final Value<bool?> correct;
  final Value<int?> attempt;
  final Value<bool?> fastEnough;
  const LogRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.atomId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.at = const Value.absent(),
    this.mode = const Value.absent(),
    this.correct = const Value.absent(),
    this.attempt = const Value.absent(),
    this.fastEnough = const Value.absent(),
  });
  LogRowsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String atomId,
    required int sessionId,
    required DateTime at,
    this.mode = const Value.absent(),
    this.correct = const Value.absent(),
    this.attempt = const Value.absent(),
    this.fastEnough = const Value.absent(),
  }) : kind = Value(kind),
       atomId = Value(atomId),
       sessionId = Value(sessionId),
       at = Value(at);
  static Insertable<LogRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? atomId,
    Expression<int>? sessionId,
    Expression<DateTime>? at,
    Expression<String>? mode,
    Expression<bool>? correct,
    Expression<int>? attempt,
    Expression<bool>? fastEnough,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (atomId != null) 'atom_id': atomId,
      if (sessionId != null) 'session_id': sessionId,
      if (at != null) 'at': at,
      if (mode != null) 'mode': mode,
      if (correct != null) 'correct': correct,
      if (attempt != null) 'attempt': attempt,
      if (fastEnough != null) 'fast_enough': fastEnough,
    });
  }

  LogRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? atomId,
    Value<int>? sessionId,
    Value<DateTime>? at,
    Value<String?>? mode,
    Value<bool?>? correct,
    Value<int?>? attempt,
    Value<bool?>? fastEnough,
  }) {
    return LogRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      atomId: atomId ?? this.atomId,
      sessionId: sessionId ?? this.sessionId,
      at: at ?? this.at,
      mode: mode ?? this.mode,
      correct: correct ?? this.correct,
      attempt: attempt ?? this.attempt,
      fastEnough: fastEnough ?? this.fastEnough,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (atomId.present) {
      map['atom_id'] = Variable<String>(atomId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (fastEnough.present) {
      map['fast_enough'] = Variable<bool>(fastEnough.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('atomId: $atomId, ')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('mode: $mode, ')
          ..write('correct: $correct, ')
          ..write('attempt: $attempt, ')
          ..write('fastEnough: $fastEnough')
          ..write(')'))
        .toString();
  }
}

class $TopicCompletionsTable extends TopicCompletions
    with TableInfo<$TopicCompletionsTable, TopicCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byTestMeta = const VerificationMeta('byTest');
  @override
  late final GeneratedColumn<bool> byTest = GeneratedColumn<bool>(
    'by_test',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("by_test" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [topicId, sessionId, at, byTest];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topic_completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TopicCompletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('by_test')) {
      context.handle(
        _byTestMeta,
        byTest.isAcceptableOrUnknown(data['by_test']!, _byTestMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {topicId};
  @override
  TopicCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TopicCompletion(
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      byTest: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}by_test'],
      )!,
    );
  }

  @override
  $TopicCompletionsTable createAlias(String alias) {
    return $TopicCompletionsTable(attachedDatabase, alias);
  }
}

class TopicCompletion extends DataClass implements Insertable<TopicCompletion> {
  final String topicId;
  final int sessionId;
  final DateTime at;

  /// Урок не проходили, а сдали тест «Уже знаю».
  final bool byTest;
  const TopicCompletion({
    required this.topicId,
    required this.sessionId,
    required this.at,
    required this.byTest,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['topic_id'] = Variable<String>(topicId);
    map['session_id'] = Variable<int>(sessionId);
    map['at'] = Variable<DateTime>(at);
    map['by_test'] = Variable<bool>(byTest);
    return map;
  }

  TopicCompletionsCompanion toCompanion(bool nullToAbsent) {
    return TopicCompletionsCompanion(
      topicId: Value(topicId),
      sessionId: Value(sessionId),
      at: Value(at),
      byTest: Value(byTest),
    );
  }

  factory TopicCompletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TopicCompletion(
      topicId: serializer.fromJson<String>(json['topicId']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      at: serializer.fromJson<DateTime>(json['at']),
      byTest: serializer.fromJson<bool>(json['byTest']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'topicId': serializer.toJson<String>(topicId),
      'sessionId': serializer.toJson<int>(sessionId),
      'at': serializer.toJson<DateTime>(at),
      'byTest': serializer.toJson<bool>(byTest),
    };
  }

  TopicCompletion copyWith({
    String? topicId,
    int? sessionId,
    DateTime? at,
    bool? byTest,
  }) => TopicCompletion(
    topicId: topicId ?? this.topicId,
    sessionId: sessionId ?? this.sessionId,
    at: at ?? this.at,
    byTest: byTest ?? this.byTest,
  );
  TopicCompletion copyWithCompanion(TopicCompletionsCompanion data) {
    return TopicCompletion(
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      at: data.at.present ? data.at.value : this.at,
      byTest: data.byTest.present ? data.byTest.value : this.byTest,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopicCompletion(')
          ..write('topicId: $topicId, ')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('byTest: $byTest')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(topicId, sessionId, at, byTest);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicCompletion &&
          other.topicId == this.topicId &&
          other.sessionId == this.sessionId &&
          other.at == this.at &&
          other.byTest == this.byTest);
}

class TopicCompletionsCompanion extends UpdateCompanion<TopicCompletion> {
  final Value<String> topicId;
  final Value<int> sessionId;
  final Value<DateTime> at;
  final Value<bool> byTest;
  final Value<int> rowid;
  const TopicCompletionsCompanion({
    this.topicId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.at = const Value.absent(),
    this.byTest = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicCompletionsCompanion.insert({
    required String topicId,
    required int sessionId,
    required DateTime at,
    this.byTest = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : topicId = Value(topicId),
       sessionId = Value(sessionId),
       at = Value(at);
  static Insertable<TopicCompletion> custom({
    Expression<String>? topicId,
    Expression<int>? sessionId,
    Expression<DateTime>? at,
    Expression<bool>? byTest,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (topicId != null) 'topic_id': topicId,
      if (sessionId != null) 'session_id': sessionId,
      if (at != null) 'at': at,
      if (byTest != null) 'by_test': byTest,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicCompletionsCompanion copyWith({
    Value<String>? topicId,
    Value<int>? sessionId,
    Value<DateTime>? at,
    Value<bool>? byTest,
    Value<int>? rowid,
  }) {
    return TopicCompletionsCompanion(
      topicId: topicId ?? this.topicId,
      sessionId: sessionId ?? this.sessionId,
      at: at ?? this.at,
      byTest: byTest ?? this.byTest,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (byTest.present) {
      map['by_test'] = Variable<bool>(byTest.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicCompletionsCompanion(')
          ..write('topicId: $topicId, ')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('byTest: $byTest, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionSummariesTable extends SessionSummaries
    with TableInfo<$SessionSummariesTable, SessionSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseCountMeta = const VerificationMeta(
    'exerciseCount',
  );
  @override
  late final GeneratedColumn<int> exerciseCount = GeneratedColumn<int>(
    'exercise_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstTryCorrectMeta = const VerificationMeta(
    'firstTryCorrect',
  );
  @override
  late final GeneratedColumn<int> firstTryCorrect = GeneratedColumn<int>(
    'first_try_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointLettersMeta = const VerificationMeta(
    'checkpointLetters',
  );
  @override
  late final GeneratedColumn<int> checkpointLetters = GeneratedColumn<int>(
    'checkpoint_letters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    at,
    purpose,
    exerciseCount,
    firstTryCorrect,
    checkpointLetters,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('exercise_count')) {
      context.handle(
        _exerciseCountMeta,
        exerciseCount.isAcceptableOrUnknown(
          data['exercise_count']!,
          _exerciseCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseCountMeta);
    }
    if (data.containsKey('first_try_correct')) {
      context.handle(
        _firstTryCorrectMeta,
        firstTryCorrect.isAcceptableOrUnknown(
          data['first_try_correct']!,
          _firstTryCorrectMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstTryCorrectMeta);
    }
    if (data.containsKey('checkpoint_letters')) {
      context.handle(
        _checkpointLettersMeta,
        checkpointLetters.isAcceptableOrUnknown(
          data['checkpoint_letters']!,
          _checkpointLettersMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionSummary(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      exerciseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_count'],
      )!,
      firstTryCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_try_correct'],
      )!,
      checkpointLetters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checkpoint_letters'],
      ),
    );
  }

  @override
  $SessionSummariesTable createAlias(String alias) {
    return $SessionSummariesTable(attachedDatabase, alias);
  }
}

class SessionSummary extends DataClass implements Insertable<SessionSummary> {
  final int sessionId;
  final DateTime at;
  final String purpose;
  final int exerciseCount;
  final int firstTryCorrect;
  final int? checkpointLetters;
  const SessionSummary({
    required this.sessionId,
    required this.at,
    required this.purpose,
    required this.exerciseCount,
    required this.firstTryCorrect,
    this.checkpointLetters,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<int>(sessionId);
    map['at'] = Variable<DateTime>(at);
    map['purpose'] = Variable<String>(purpose);
    map['exercise_count'] = Variable<int>(exerciseCount);
    map['first_try_correct'] = Variable<int>(firstTryCorrect);
    if (!nullToAbsent || checkpointLetters != null) {
      map['checkpoint_letters'] = Variable<int>(checkpointLetters);
    }
    return map;
  }

  SessionSummariesCompanion toCompanion(bool nullToAbsent) {
    return SessionSummariesCompanion(
      sessionId: Value(sessionId),
      at: Value(at),
      purpose: Value(purpose),
      exerciseCount: Value(exerciseCount),
      firstTryCorrect: Value(firstTryCorrect),
      checkpointLetters: checkpointLetters == null && nullToAbsent
          ? const Value.absent()
          : Value(checkpointLetters),
    );
  }

  factory SessionSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionSummary(
      sessionId: serializer.fromJson<int>(json['sessionId']),
      at: serializer.fromJson<DateTime>(json['at']),
      purpose: serializer.fromJson<String>(json['purpose']),
      exerciseCount: serializer.fromJson<int>(json['exerciseCount']),
      firstTryCorrect: serializer.fromJson<int>(json['firstTryCorrect']),
      checkpointLetters: serializer.fromJson<int?>(json['checkpointLetters']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<int>(sessionId),
      'at': serializer.toJson<DateTime>(at),
      'purpose': serializer.toJson<String>(purpose),
      'exerciseCount': serializer.toJson<int>(exerciseCount),
      'firstTryCorrect': serializer.toJson<int>(firstTryCorrect),
      'checkpointLetters': serializer.toJson<int?>(checkpointLetters),
    };
  }

  SessionSummary copyWith({
    int? sessionId,
    DateTime? at,
    String? purpose,
    int? exerciseCount,
    int? firstTryCorrect,
    Value<int?> checkpointLetters = const Value.absent(),
  }) => SessionSummary(
    sessionId: sessionId ?? this.sessionId,
    at: at ?? this.at,
    purpose: purpose ?? this.purpose,
    exerciseCount: exerciseCount ?? this.exerciseCount,
    firstTryCorrect: firstTryCorrect ?? this.firstTryCorrect,
    checkpointLetters: checkpointLetters.present
        ? checkpointLetters.value
        : this.checkpointLetters,
  );
  SessionSummary copyWithCompanion(SessionSummariesCompanion data) {
    return SessionSummary(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      at: data.at.present ? data.at.value : this.at,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      exerciseCount: data.exerciseCount.present
          ? data.exerciseCount.value
          : this.exerciseCount,
      firstTryCorrect: data.firstTryCorrect.present
          ? data.firstTryCorrect.value
          : this.firstTryCorrect,
      checkpointLetters: data.checkpointLetters.present
          ? data.checkpointLetters.value
          : this.checkpointLetters,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionSummary(')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('purpose: $purpose, ')
          ..write('exerciseCount: $exerciseCount, ')
          ..write('firstTryCorrect: $firstTryCorrect, ')
          ..write('checkpointLetters: $checkpointLetters')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    at,
    purpose,
    exerciseCount,
    firstTryCorrect,
    checkpointLetters,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionSummary &&
          other.sessionId == this.sessionId &&
          other.at == this.at &&
          other.purpose == this.purpose &&
          other.exerciseCount == this.exerciseCount &&
          other.firstTryCorrect == this.firstTryCorrect &&
          other.checkpointLetters == this.checkpointLetters);
}

class SessionSummariesCompanion extends UpdateCompanion<SessionSummary> {
  final Value<int> sessionId;
  final Value<DateTime> at;
  final Value<String> purpose;
  final Value<int> exerciseCount;
  final Value<int> firstTryCorrect;
  final Value<int?> checkpointLetters;
  const SessionSummariesCompanion({
    this.sessionId = const Value.absent(),
    this.at = const Value.absent(),
    this.purpose = const Value.absent(),
    this.exerciseCount = const Value.absent(),
    this.firstTryCorrect = const Value.absent(),
    this.checkpointLetters = const Value.absent(),
  });
  SessionSummariesCompanion.insert({
    this.sessionId = const Value.absent(),
    required DateTime at,
    required String purpose,
    required int exerciseCount,
    required int firstTryCorrect,
    this.checkpointLetters = const Value.absent(),
  }) : at = Value(at),
       purpose = Value(purpose),
       exerciseCount = Value(exerciseCount),
       firstTryCorrect = Value(firstTryCorrect);
  static Insertable<SessionSummary> custom({
    Expression<int>? sessionId,
    Expression<DateTime>? at,
    Expression<String>? purpose,
    Expression<int>? exerciseCount,
    Expression<int>? firstTryCorrect,
    Expression<int>? checkpointLetters,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (at != null) 'at': at,
      if (purpose != null) 'purpose': purpose,
      if (exerciseCount != null) 'exercise_count': exerciseCount,
      if (firstTryCorrect != null) 'first_try_correct': firstTryCorrect,
      if (checkpointLetters != null) 'checkpoint_letters': checkpointLetters,
    });
  }

  SessionSummariesCompanion copyWith({
    Value<int>? sessionId,
    Value<DateTime>? at,
    Value<String>? purpose,
    Value<int>? exerciseCount,
    Value<int>? firstTryCorrect,
    Value<int?>? checkpointLetters,
  }) {
    return SessionSummariesCompanion(
      sessionId: sessionId ?? this.sessionId,
      at: at ?? this.at,
      purpose: purpose ?? this.purpose,
      exerciseCount: exerciseCount ?? this.exerciseCount,
      firstTryCorrect: firstTryCorrect ?? this.firstTryCorrect,
      checkpointLetters: checkpointLetters ?? this.checkpointLetters,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (exerciseCount.present) {
      map['exercise_count'] = Variable<int>(exerciseCount.value);
    }
    if (firstTryCorrect.present) {
      map['first_try_correct'] = Variable<int>(firstTryCorrect.value);
    }
    if (checkpointLetters.present) {
      map['checkpoint_letters'] = Variable<int>(checkpointLetters.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionSummariesCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('purpose: $purpose, ')
          ..write('exerciseCount: $exerciseCount, ')
          ..write('firstTryCorrect: $firstTryCorrect, ')
          ..write('checkpointLetters: $checkpointLetters')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProgressDatabase extends GeneratedDatabase {
  _$ProgressDatabase(QueryExecutor e) : super(e);
  $ProgressDatabaseManager get managers => $ProgressDatabaseManager(this);
  late final $LogRowsTable logRows = $LogRowsTable(this);
  late final $TopicCompletionsTable topicCompletions = $TopicCompletionsTable(
    this,
  );
  late final $SessionSummariesTable sessionSummaries = $SessionSummariesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    logRows,
    topicCompletions,
    sessionSummaries,
  ];
}

typedef $$LogRowsTableCreateCompanionBuilder =
    LogRowsCompanion Function({
      Value<int> id,
      required String kind,
      required String atomId,
      required int sessionId,
      required DateTime at,
      Value<String?> mode,
      Value<bool?> correct,
      Value<int?> attempt,
      Value<bool?> fastEnough,
    });
typedef $$LogRowsTableUpdateCompanionBuilder =
    LogRowsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> atomId,
      Value<int> sessionId,
      Value<DateTime> at,
      Value<String?> mode,
      Value<bool?> correct,
      Value<int?> attempt,
      Value<bool?> fastEnough,
    });

class $$LogRowsTableFilterComposer
    extends Composer<_$ProgressDatabase, $LogRowsTable> {
  $$LogRowsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get atomId => $composableBuilder(
    column: $table.atomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fastEnough => $composableBuilder(
    column: $table.fastEnough,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LogRowsTableOrderingComposer
    extends Composer<_$ProgressDatabase, $LogRowsTable> {
  $$LogRowsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get atomId => $composableBuilder(
    column: $table.atomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fastEnough => $composableBuilder(
    column: $table.fastEnough,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogRowsTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $LogRowsTable> {
  $$LogRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get atomId =>
      $composableBuilder(column: $table.atomId, builder: (column) => column);

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<bool> get fastEnough => $composableBuilder(
    column: $table.fastEnough,
    builder: (column) => column,
  );
}

class $$LogRowsTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $LogRowsTable,
          LogRow,
          $$LogRowsTableFilterComposer,
          $$LogRowsTableOrderingComposer,
          $$LogRowsTableAnnotationComposer,
          $$LogRowsTableCreateCompanionBuilder,
          $$LogRowsTableUpdateCompanionBuilder,
          (LogRow, BaseReferences<_$ProgressDatabase, $LogRowsTable, LogRow>),
          LogRow,
          PrefetchHooks Function()
        > {
  $$LogRowsTableTableManager(_$ProgressDatabase db, $LogRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> atomId = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<bool?> correct = const Value.absent(),
                Value<int?> attempt = const Value.absent(),
                Value<bool?> fastEnough = const Value.absent(),
              }) => LogRowsCompanion(
                id: id,
                kind: kind,
                atomId: atomId,
                sessionId: sessionId,
                at: at,
                mode: mode,
                correct: correct,
                attempt: attempt,
                fastEnough: fastEnough,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String atomId,
                required int sessionId,
                required DateTime at,
                Value<String?> mode = const Value.absent(),
                Value<bool?> correct = const Value.absent(),
                Value<int?> attempt = const Value.absent(),
                Value<bool?> fastEnough = const Value.absent(),
              }) => LogRowsCompanion.insert(
                id: id,
                kind: kind,
                atomId: atomId,
                sessionId: sessionId,
                at: at,
                mode: mode,
                correct: correct,
                attempt: attempt,
                fastEnough: fastEnough,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LogRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $LogRowsTable,
      LogRow,
      $$LogRowsTableFilterComposer,
      $$LogRowsTableOrderingComposer,
      $$LogRowsTableAnnotationComposer,
      $$LogRowsTableCreateCompanionBuilder,
      $$LogRowsTableUpdateCompanionBuilder,
      (LogRow, BaseReferences<_$ProgressDatabase, $LogRowsTable, LogRow>),
      LogRow,
      PrefetchHooks Function()
    >;
typedef $$TopicCompletionsTableCreateCompanionBuilder =
    TopicCompletionsCompanion Function({
      required String topicId,
      required int sessionId,
      required DateTime at,
      Value<bool> byTest,
      Value<int> rowid,
    });
typedef $$TopicCompletionsTableUpdateCompanionBuilder =
    TopicCompletionsCompanion Function({
      Value<String> topicId,
      Value<int> sessionId,
      Value<DateTime> at,
      Value<bool> byTest,
      Value<int> rowid,
    });

class $$TopicCompletionsTableFilterComposer
    extends Composer<_$ProgressDatabase, $TopicCompletionsTable> {
  $$TopicCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get byTest => $composableBuilder(
    column: $table.byTest,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TopicCompletionsTableOrderingComposer
    extends Composer<_$ProgressDatabase, $TopicCompletionsTable> {
  $$TopicCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get byTest => $composableBuilder(
    column: $table.byTest,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TopicCompletionsTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $TopicCompletionsTable> {
  $$TopicCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<bool> get byTest =>
      $composableBuilder(column: $table.byTest, builder: (column) => column);
}

class $$TopicCompletionsTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $TopicCompletionsTable,
          TopicCompletion,
          $$TopicCompletionsTableFilterComposer,
          $$TopicCompletionsTableOrderingComposer,
          $$TopicCompletionsTableAnnotationComposer,
          $$TopicCompletionsTableCreateCompanionBuilder,
          $$TopicCompletionsTableUpdateCompanionBuilder,
          (
            TopicCompletion,
            BaseReferences<
              _$ProgressDatabase,
              $TopicCompletionsTable,
              TopicCompletion
            >,
          ),
          TopicCompletion,
          PrefetchHooks Function()
        > {
  $$TopicCompletionsTableTableManager(
    _$ProgressDatabase db,
    $TopicCompletionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicCompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicCompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicCompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> topicId = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<bool> byTest = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicCompletionsCompanion(
                topicId: topicId,
                sessionId: sessionId,
                at: at,
                byTest: byTest,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String topicId,
                required int sessionId,
                required DateTime at,
                Value<bool> byTest = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicCompletionsCompanion.insert(
                topicId: topicId,
                sessionId: sessionId,
                at: at,
                byTest: byTest,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TopicCompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $TopicCompletionsTable,
      TopicCompletion,
      $$TopicCompletionsTableFilterComposer,
      $$TopicCompletionsTableOrderingComposer,
      $$TopicCompletionsTableAnnotationComposer,
      $$TopicCompletionsTableCreateCompanionBuilder,
      $$TopicCompletionsTableUpdateCompanionBuilder,
      (
        TopicCompletion,
        BaseReferences<
          _$ProgressDatabase,
          $TopicCompletionsTable,
          TopicCompletion
        >,
      ),
      TopicCompletion,
      PrefetchHooks Function()
    >;
typedef $$SessionSummariesTableCreateCompanionBuilder =
    SessionSummariesCompanion Function({
      Value<int> sessionId,
      required DateTime at,
      required String purpose,
      required int exerciseCount,
      required int firstTryCorrect,
      Value<int?> checkpointLetters,
    });
typedef $$SessionSummariesTableUpdateCompanionBuilder =
    SessionSummariesCompanion Function({
      Value<int> sessionId,
      Value<DateTime> at,
      Value<String> purpose,
      Value<int> exerciseCount,
      Value<int> firstTryCorrect,
      Value<int?> checkpointLetters,
    });

class $$SessionSummariesTableFilterComposer
    extends Composer<_$ProgressDatabase, $SessionSummariesTable> {
  $$SessionSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseCount => $composableBuilder(
    column: $table.exerciseCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstTryCorrect => $composableBuilder(
    column: $table.firstTryCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkpointLetters => $composableBuilder(
    column: $table.checkpointLetters,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionSummariesTableOrderingComposer
    extends Composer<_$ProgressDatabase, $SessionSummariesTable> {
  $$SessionSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseCount => $composableBuilder(
    column: $table.exerciseCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstTryCorrect => $composableBuilder(
    column: $table.firstTryCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkpointLetters => $composableBuilder(
    column: $table.checkpointLetters,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionSummariesTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $SessionSummariesTable> {
  $$SessionSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<int> get exerciseCount => $composableBuilder(
    column: $table.exerciseCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstTryCorrect => $composableBuilder(
    column: $table.firstTryCorrect,
    builder: (column) => column,
  );

  GeneratedColumn<int> get checkpointLetters => $composableBuilder(
    column: $table.checkpointLetters,
    builder: (column) => column,
  );
}

class $$SessionSummariesTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $SessionSummariesTable,
          SessionSummary,
          $$SessionSummariesTableFilterComposer,
          $$SessionSummariesTableOrderingComposer,
          $$SessionSummariesTableAnnotationComposer,
          $$SessionSummariesTableCreateCompanionBuilder,
          $$SessionSummariesTableUpdateCompanionBuilder,
          (
            SessionSummary,
            BaseReferences<
              _$ProgressDatabase,
              $SessionSummariesTable,
              SessionSummary
            >,
          ),
          SessionSummary,
          PrefetchHooks Function()
        > {
  $$SessionSummariesTableTableManager(
    _$ProgressDatabase db,
    $SessionSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sessionId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<int> exerciseCount = const Value.absent(),
                Value<int> firstTryCorrect = const Value.absent(),
                Value<int?> checkpointLetters = const Value.absent(),
              }) => SessionSummariesCompanion(
                sessionId: sessionId,
                at: at,
                purpose: purpose,
                exerciseCount: exerciseCount,
                firstTryCorrect: firstTryCorrect,
                checkpointLetters: checkpointLetters,
              ),
          createCompanionCallback:
              ({
                Value<int> sessionId = const Value.absent(),
                required DateTime at,
                required String purpose,
                required int exerciseCount,
                required int firstTryCorrect,
                Value<int?> checkpointLetters = const Value.absent(),
              }) => SessionSummariesCompanion.insert(
                sessionId: sessionId,
                at: at,
                purpose: purpose,
                exerciseCount: exerciseCount,
                firstTryCorrect: firstTryCorrect,
                checkpointLetters: checkpointLetters,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $SessionSummariesTable,
      SessionSummary,
      $$SessionSummariesTableFilterComposer,
      $$SessionSummariesTableOrderingComposer,
      $$SessionSummariesTableAnnotationComposer,
      $$SessionSummariesTableCreateCompanionBuilder,
      $$SessionSummariesTableUpdateCompanionBuilder,
      (
        SessionSummary,
        BaseReferences<
          _$ProgressDatabase,
          $SessionSummariesTable,
          SessionSummary
        >,
      ),
      SessionSummary,
      PrefetchHooks Function()
    >;

class $ProgressDatabaseManager {
  final _$ProgressDatabase _db;
  $ProgressDatabaseManager(this._db);
  $$LogRowsTableTableManager get logRows =>
      $$LogRowsTableTableManager(_db, _db.logRows);
  $$TopicCompletionsTableTableManager get topicCompletions =>
      $$TopicCompletionsTableTableManager(_db, _db.topicCompletions);
  $$SessionSummariesTableTableManager get sessionSummaries =>
      $$SessionSummariesTableTableManager(_db, _db.sessionSummaries);
}
