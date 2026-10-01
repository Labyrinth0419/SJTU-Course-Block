import 'dart:convert';

class Course {
  final int? id;
  final int? scheduleId;
  final String courseId;
  final String courseName;
  final String teacher;
  final String classRoom;
  final int startWeek;
  final int endWeek;
  final int dayOfWeek; // 1-7 (Mon-Sun)
  final int startNode; // 1-14
  final int step; // Duration in nodes (e.g., 2)
  final bool isOddWeek; // Only odd weeks
  final bool isEvenWeek; // Only even weeks
  final String? weekCode;
  final String color; // Random color for display
  final bool isVirtual;

  // 'local' is the default for all new/manual/imported courses. Old rows have
  // 'legacy' until a conservative first-sync match identifies their source.
  final String sourceSystem;
  final String? remoteCourseKey;
  final String? remoteBaseline;
  final Set<String> editedFields;

  static const syncFieldNames = <String>{
    'courseName',
    'teacher',
    'classRoom',
    'startWeek',
    'endWeek',
    'dayOfWeek',
    'startNode',
    'step',
    'isOddWeek',
    'isEvenWeek',
    'weekCode',
    'color',
    'isVirtual',
  };

  static const List<String> colors = [
    '#FF758F', // Pink
    '#9B9BFF', // Periwinkle Blue
    '#4ADBC8', // Turquoise
    '#FF9F46', // Soft Orange
    '#A06CD5', // Purple
    '#FFB7B2', // Salmon
    '#B5EAD7', // Mint
    '#C7CEEA', // Lilac
    '#E2F0CB', // Pale Green
    '#FFDAC1', // Peach
    '#FF9AA2', // Light Red
    '#6EB5FF', // Sky Blue
  ];

  Course({
    this.id,
    this.scheduleId,
    required this.courseId,
    required this.courseName,
    required this.teacher,
    required this.classRoom,
    required this.startWeek,
    required this.endWeek,
    required this.dayOfWeek,
    required this.startNode,
    required this.step,
    this.isOddWeek = false,
    this.isEvenWeek = false,
    this.weekCode,
    this.color = '#FF5722',
    this.isVirtual = false,
    this.sourceSystem = 'local',
    this.remoteCourseKey,
    this.remoteBaseline,
    this.editedFields = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'courseId': courseId,
      'courseName': courseName,
      'teacher': teacher,
      'classRoom': classRoom,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'dayOfWeek': dayOfWeek,
      'startNode': startNode,
      'step': step,
      'isOddWeek': isOddWeek ? 1 : 0,
      'isEvenWeek': isEvenWeek ? 1 : 0,
      'weekCode': weekCode,
      'color': color,
      'isVirtual': isVirtual ? 1 : 0,
      'sourceSystem': sourceSystem,
      'remoteCourseKey': remoteCourseKey,
      'remoteBaseline': remoteBaseline,
      'editedFields': jsonEncode(editedFields.toList()..sort()),
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      scheduleId: map['scheduleId'],
      courseId: map['courseId'],
      courseName: map['courseName'],
      teacher: map['teacher'],
      classRoom: map['classRoom'],
      startWeek: map['startWeek'],
      endWeek: map['endWeek'],
      dayOfWeek: map['dayOfWeek'],
      startNode: map['startNode'],
      step: map['step'],
      isOddWeek: map['isOddWeek'] == 1,
      isEvenWeek: map['isEvenWeek'] == 1,
      weekCode: map['weekCode'],
      color: map['color'] ?? '#FF5722',
      isVirtual: (map['isVirtual'] as int? ?? 0) == 1,
      sourceSystem:
          map['sourceSystem'] as String? ??
          (map['id'] == null ? 'local' : 'legacy'),
      remoteCourseKey: map['remoteCourseKey'] as String?,
      remoteBaseline: map['remoteBaseline'] as String?,
      editedFields: (jsonDecode(map['editedFields'] as String? ?? '[]') as List)
          .whereType<String>()
          .toSet(),
    );
  }

  Map<String, dynamic> get syncFields {
    final map = toMap();
    return {for (final field in syncFieldNames) field: map[field]};
  }

  /// Records only fields actually changed by the user, retaining prior overrides.
  Course withUserEdits(Course submitted) {
    if (sourceSystem == 'local' || sourceSystem == 'legacy') return submitted;
    final before = syncFields;
    final after = submitted.syncFields;
    final baseline = remoteBaseline == null
        ? <String, dynamic>{}
        : jsonDecode(remoteBaseline!) as Map<String, dynamic>;
    final edits = {...editedFields};
    for (final field in syncFieldNames) {
      if (before[field] != after[field]) {
        if (after[field] == baseline[field]) {
          edits.remove(field);
        } else {
          edits.add(field);
        }
      }
    }
    return submitted.copyWith(
      sourceSystem: sourceSystem,
      remoteCourseKey: remoteCourseKey,
      remoteBaseline: remoteBaseline,
      editedFields: edits,
    );
  }

  /// Binds a fetched row to its durable upstream identity and field baseline.
  Course bindRemote(String system) {
    return copyWith(
      sourceSystem: system,
      remoteCourseKey: courseId.trim(),
      remoteBaseline: jsonEncode(syncFields),
      editedFields: const {},
    );
  }

  /// Refreshes remote-owned fields without replacing the row or user overrides.
  Course mergeRemote(Course incoming) {
    final values = incoming.syncFields;
    final current = syncFields;
    final baseline = remoteBaseline == null
        ? <String, dynamic>{}
        : jsonDecode(remoteBaseline!) as Map<String, dynamic>;
    // Palette normalization can change a generated color without a user edit.
    // Keep that display assignment until the fetched color itself changes.
    if (!editedFields.contains('color') &&
        incoming.color == baseline['color'] &&
        color != baseline['color']) {
      values['color'] = color;
    }
    for (final field in editedFields) {
      if (syncFieldNames.contains(field)) values[field] = current[field];
    }
    return Course.fromMap({
      ...incoming.toMap(),
      ...values,
      'id': id,
      'scheduleId': scheduleId,
      'sourceSystem': sourceSystem,
      'remoteCourseKey': remoteCourseKey,
      'remoteBaseline': jsonEncode(incoming.syncFields),
      'editedFields': jsonEncode(editedFields.toList()..sort()),
    });
  }

  Course copyWith({
    int? id,
    int? scheduleId,
    String? courseId,
    String? courseName,
    String? teacher,
    String? classRoom,
    int? startWeek,
    int? endWeek,
    int? dayOfWeek,
    int? startNode,
    int? step,
    bool? isOddWeek,
    bool? isEvenWeek,
    Object? weekCode = _unchanged,
    String? color,
    bool? isVirtual,
    String? sourceSystem,
    Object? remoteCourseKey = _unchanged,
    Object? remoteBaseline = _unchanged,
    Set<String>? editedFields,
  }) {
    return Course(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      teacher: teacher ?? this.teacher,
      classRoom: classRoom ?? this.classRoom,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startNode: startNode ?? this.startNode,
      step: step ?? this.step,
      isOddWeek: isOddWeek ?? this.isOddWeek,
      isEvenWeek: isEvenWeek ?? this.isEvenWeek,
      weekCode: identical(weekCode, _unchanged)
          ? this.weekCode
          : weekCode as String?,
      color: color ?? this.color,
      isVirtual: isVirtual ?? this.isVirtual,
      sourceSystem: sourceSystem ?? this.sourceSystem,
      remoteCourseKey: identical(remoteCourseKey, _unchanged)
          ? this.remoteCourseKey
          : remoteCourseKey as String?,
      remoteBaseline: identical(remoteBaseline, _unchanged)
          ? this.remoteBaseline
          : remoteBaseline as String?,
      editedFields: editedFields ?? this.editedFields,
    );
  }

  @override
  String toString() {
    return 'Course{id: $id, name: $courseName, room: $classRoom, day: $dayOfWeek, time: $startNode-$step}';
  }
}

const _unchanged = Object();
