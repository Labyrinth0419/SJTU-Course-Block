class Schedule {
  final int? id;
  final String name;
  final String year; // e.g., "2023-2024"
  final String term; // e.g., "1"
  final DateTime startDate;
  final bool isCurrent;

  Schedule({
    this.id,
    required this.name,
    required this.year,
    required this.term,
    required this.startDate,
    this.isCurrent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'year': year,
      'term': term,
      'startDate': startDate.toIso8601String(),
      'isCurrent': isCurrent ? 1 : 0,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      name: map['name'],
      year: map['year'],
      term: map['term'],
      startDate: DateTime.parse(map['startDate']),
      isCurrent: map['isCurrent'] == 1,
    );
  }

  Schedule copyWith({
    int? id,
    String? name,
    String? year,
    String? term,
    DateTime? startDate,
    bool? isCurrent,
  }) {
    return Schedule(
      id: id ?? this.id,
      name: name ?? this.name,
      year: year ?? this.year,
      term: term ?? this.term,
      startDate: startDate ?? this.startDate,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}
