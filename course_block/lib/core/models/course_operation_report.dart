class CourseOperationFailure {
  const CourseOperationFailure({required this.label, required this.reason});

  final String label;
  final String reason;
}

class CourseImportReport {
  const CourseImportReport({
    required this.sourceLabel,
    required this.added,
    required this.failed,
    this.notes = const [],
    this.failures = const [],
  });

  final String sourceLabel;
  final int added;
  final int failed;
  final List<String> notes;
  final List<CourseOperationFailure> failures;

  bool get hasFailures => failed > 0 || failures.isNotEmpty;
}

class CourseSyncReport {
  const CourseSyncReport({
    required this.termLabel,
    required this.sourceLabel,
    required this.added,
    required this.updated,
    required this.skipped,
    required this.failed,
    this.notes = const [],
    this.failures = const [],
  });

  final String termLabel;
  final String sourceLabel;
  final int added;
  final int updated;
  final int skipped;
  final int failed;
  final List<String> notes;
  final List<CourseOperationFailure> failures;

  int get changed => added + updated;
  bool get hasFailures => failed > 0 || failures.isNotEmpty;
  bool get isEmpty => added == 0 && updated == 0 && skipped == 0 && failed == 0;
}
