import 'dart:convert';

import '../models/course.dart';

class CourseSyncPlan {
  const CourseSyncPlan({
    required this.inserts,
    required this.updates,
    required this.deletes,
    required this.notes,
    required this.skipped,
  });

  final List<Course> inserts;
  final List<Course> updates;
  final List<int> deletes;
  final List<String> notes;
  final int skipped;
}

/// Plans a scoped sync without replacing local rows or changing existing IDs.
CourseSyncPlan planCourseSync({
  required List<Course> existing,
  required List<Course> incoming,
  required String sourceSystem,
  required bool allowRemoval,
}) {
  final remote = <String, List<Course>>{};
  final legacy = <String, List<Course>>{};
  final fetched = <String, List<Course>>{};
  final notes = <String>[];
  final inserts = <Course>[];
  final updates = <Course>[];
  final deletes = <int>[];
  var skipped = 0;

  for (final row in existing) {
    if (row.sourceSystem == sourceSystem) {
      final key = row.remoteCourseKey?.trim() ?? '';
      if (key.isNotEmpty) remote.putIfAbsent(key, () => []).add(row);
    } else if (row.sourceSystem == 'legacy') {
      final key = row.courseId.trim();
      if (key.isNotEmpty) legacy.putIfAbsent(key, () => []).add(row);
    }
  }
  for (final row in incoming) {
    final key = row.courseId.trim();
    if (key.isEmpty) {
      notes.add('课程 ${row.courseName} 缺少教务课程编号，已跳过以免重复导入。');
      skipped++;
    } else {
      fetched.putIfAbsent(key, () => []).add(row);
    }
  }

  final keys = {...remote.keys, ...legacy.keys, ...fetched.keys};
  for (final key in keys) {
    final oldRemote = remote[key] ?? const <Course>[];
    final oldLegacy = legacy[key] ?? const <Course>[];
    final next = fetched[key] ?? const <Course>[];

    if (next.isEmpty) {
      if (allowRemoval) {
        deletes.addAll(
          oldRemote.where((row) => row.id != null).map((row) => row.id!),
        );
      }
      for (final row in oldLegacy) {
        updates.add(row.copyWith(sourceSystem: 'local'));
      }
      continue;
    }

    final matches = <Course, Course>{};
    final unpairedOld = [...oldRemote];
    final unpairedNext = [...next];
    if (oldRemote.length == 1 && next.length == 1) {
      matches[oldRemote.single] = next.single;
      unpairedOld.clear();
      unpairedNext.clear();
    } else if (oldRemote.isNotEmpty) {
      // The upstream API supplies only a courseId, not a meeting ID. Compare
      // incoming meetings to the last remote baseline, never to edited display.
      for (final fields in _meetingFingerprints) {
        final oldByKey = <String, List<Course>>{};
        final nextByKey = <String, List<Course>>{};
        for (final row in unpairedOld) {
          if (row.remoteBaseline == null) continue;
          final baseline =
              jsonDecode(row.remoteBaseline!) as Map<String, dynamic>;
          oldByKey
              .putIfAbsent(_fingerprint(baseline, fields), () => [])
              .add(row);
        }
        for (final row in unpairedNext) {
          nextByKey
              .putIfAbsent(_fingerprint(row.syncFields, fields), () => [])
              .add(row);
        }
        for (final entry in oldByKey.entries) {
          final candidate = nextByKey[entry.key];
          if (entry.value.length == 1 && candidate?.length == 1) {
            final old = entry.value.single;
            final nextRow = candidate!.single;
            matches[old] = nextRow;
            unpairedOld.remove(old);
            unpairedNext.remove(nextRow);
          }
        }
      }
    }

    if (unpairedOld.isNotEmpty && unpairedNext.isNotEmpty) {
      notes.add('教务课程 $key 有多条排课且无法唯一对应，已保留原记录并跳过该组；请手动核对排课。');
      skipped += next.length;
      continue;
    }

    // V1 rows have no source/baseline. Require a unique courseId AND a
    // recognizable meeting (name, teacher and time) before binding them.
    final legacyMatches = <Course, Course>{};
    var ambiguousLegacy = false;
    for (final old in oldLegacy) {
      final candidates = unpairedNext
          .where(
            (row) =>
                row.courseName == old.courseName &&
                row.teacher == old.teacher &&
                row.dayOfWeek == old.dayOfWeek &&
                row.startNode == old.startNode &&
                row.step == old.step,
          )
          .toList();
      if (candidates.length > 1 ||
          (candidates.length == 1 &&
              oldLegacy
                      .where(
                        (other) =>
                            other.courseName == old.courseName &&
                            other.teacher == old.teacher &&
                            other.dayOfWeek == old.dayOfWeek &&
                            other.startNode == old.startNode &&
                            other.step == old.step,
                      )
                      .length >
                  1)) {
        ambiguousLegacy = true;
        break;
      }
      if (candidates.length == 1) {
        legacyMatches[old] = candidates.single;
        unpairedNext.remove(candidates.single);
      }
    }
    if (ambiguousLegacy) {
      notes.add('教务课程 $key 的旧版排课无法唯一识别，已保留原记录并跳过该组；请手动核对排课。');
      skipped += next.length;
      continue;
    }

    for (final entry in matches.entries) {
      final merged = entry.key.mergeRemote(entry.value);
      if (jsonEncode(entry.key.toMap()) == jsonEncode(merged.toMap())) {
        skipped++;
      } else {
        updates.add(merged);
      }
    }
    for (final entry in legacyMatches.entries) {
      final old = entry.key;
      final bound = old.copyWith(
        sourceSystem: sourceSystem,
        remoteCourseKey: key,
        remoteBaseline: jsonEncode(entry.value.syncFields),
        editedFields: Course.syncFieldNames,
      );
      updates.add(bound);
    }
    for (final row in oldLegacy) {
      if (!legacyMatches.containsKey(row)) {
        updates.add(row.copyWith(sourceSystem: 'local'));
      }
    }
    for (final row in unpairedNext) {
      inserts.add(row.bindRemote(sourceSystem));
    }
    if (allowRemoval) {
      deletes.addAll(
        unpairedOld.where((row) => row.id != null).map((row) => row.id!),
      );
    }
  }

  for (final row in existing) {
    if (row.sourceSystem == 'legacy' && row.courseId.trim().isEmpty) {
      updates.add(row.copyWith(sourceSystem: 'local'));
    }
  }

  return CourseSyncPlan(
    inserts: inserts,
    updates: updates,
    deletes: deletes,
    notes: notes,
    skipped: skipped,
  );
}

const _meetingFingerprints = <List<String>>[
  [
    'dayOfWeek',
    'startNode',
    'step',
    'classRoom',
    'weekCode',
    'startWeek',
    'endWeek',
    'isOddWeek',
    'isEvenWeek',
  ],
  ['dayOfWeek', 'startNode', 'step', 'classRoom'],
  ['dayOfWeek', 'startNode', 'step', 'weekCode', 'startWeek', 'endWeek'],
  ['dayOfWeek', 'startNode', 'step'],
  ['classRoom', 'weekCode', 'startWeek', 'endWeek'],
  ['classRoom'],
];

String _fingerprint(Map<String, dynamic> row, List<String> fields) =>
    jsonEncode([for (final field in fields) row[field]]);
