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

  static const List<String> COLORS = [
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
    );
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
    String? weekCode,
    String? color,
    bool? isVirtual,
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
      weekCode: weekCode ?? this.weekCode,
      color: color ?? this.color,
      isVirtual: isVirtual ?? this.isVirtual,
    );
  }

  @override
  String toString() {
    return 'Course{id: $id, name: $courseName, room: $classRoom, day: $dayOfWeek, time: $startNode-$step}';
  }
}
