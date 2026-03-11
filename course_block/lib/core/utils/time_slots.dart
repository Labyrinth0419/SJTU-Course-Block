const List<String> kClassStartTimes = [
  '8:00',
  '8:55',
  '10:00',
  '10:55',
  '12:00',
  '12:55',
  '14:00',
  '14:55',
  '16:00',
  '16:55',
  '18:00',
  '18:55',
  '20:00',
  '20:55',
];

const List<String> kClassEndTimes = [
  '8:45',
  '9:40',
  '10:45',
  '11:40',
  '12:45',
  '13:40',
  '14:45',
  '15:40',
  '16:45',
  '17:40',
  '18:45',
  '19:40',
  '20:45',
  '21:40',
];

/// Drop the time portion so date math stays stable across timezones.
DateTime normalizeDate(DateTime input) =>
    DateTime(input.year, input.month, input.day);

DateTime classStartDateTime(DateTime baseDate, int startNode) {
  final idx = (startNode - 1).clamp(0, kClassStartTimes.length - 1);
  final parts = kClassStartTimes[idx].split(':');
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final normalized = normalizeDate(baseDate);
  return DateTime(
    normalized.year,
    normalized.month,
    normalized.day,
    hour,
    minute,
  );
}

DateTime classEndDateTime(DateTime baseDate, int startNode, int step) {
  final idx = (startNode + step - 2).clamp(0, kClassEndTimes.length - 1);
  final parts = kClassEndTimes[idx].split(':');
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final normalized = normalizeDate(baseDate);
  return DateTime(
    normalized.year,
    normalized.month,
    normalized.day,
    hour,
    minute,
  );
}

int resolveStartNode(DateTime dt) {
  final minutes = dt.hour * 60 + dt.minute;
  int node = 1;
  for (var i = 0; i < kClassStartTimes.length; i++) {
    final parts = kClassStartTimes[i].split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final value = h * 60 + m;
    if (minutes >= value) {
      node = i + 1;
    } else {
      break;
    }
  }
  return node;
}

int resolveEndNode(DateTime dt) {
  final minutes = dt.hour * 60 + dt.minute;
  for (var i = 0; i < kClassEndTimes.length; i++) {
    final parts = kClassEndTimes[i].split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final value = h * 60 + m;
    if (minutes <= value) {
      return i + 1;
    }
  }
  return kClassEndTimes.length;
}
