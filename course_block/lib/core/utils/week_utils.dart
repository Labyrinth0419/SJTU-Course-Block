class WeekUtils {
  static const int maxWeeks = 24; // Assuming 24 weeks max

  /// Extract week expressions like `1-16`, `9-12(单)` from mixed text while
  /// ignoring unrelated numbers such as class periods.
  static List<String> extractWeekExpressions(String rawText) {
    if (rawText.trim().isEmpty) {
      return const [];
    }

    var normalized = rawText
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll('；', ',')
        .replaceAll(';', ',')
        .replaceAll('至', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('～', '-')
        .replaceAll('~', '-')
        .replaceAll('单周', '(单)')
        .replaceAll('双周', '(双)')
        .replaceAll('周(', '(')
        .replaceAll(' ', '');

    final cutPoints = [
      normalized.indexOf('星期'),
      normalized.indexOf('['),
    ].where((index) => index >= 0).toList();
    if (cutPoints.isNotEmpty) {
      final cutoff = cutPoints.reduce((a, b) => a < b ? a : b);
      normalized = normalized.substring(0, cutoff);
    }

    final matches = RegExp(
      r'(\d{1,2}(?:-\d{1,2})?(?:\((?:单|双)\))?)',
    ).allMatches(normalized);

    final expressions = <String>[];
    for (final match in matches) {
      final token = match.group(1);
      if (token == null || token.isEmpty) {
        continue;
      }

      final cleanToken = token.replaceAll('(单)', '').replaceAll('(双)', '');
      final parts = cleanToken.split('-');
      final start = int.tryParse(parts.first);
      final end = int.tryParse(parts.length > 1 ? parts[1] : parts.first);
      if (start == null || end == null) {
        continue;
      }
      if (start < 1 || end < 1 || start > maxWeeks || end > maxWeeks) {
        continue;
      }
      if (start > end) {
        continue;
      }

      expressions.add(token);
    }

    return expressions;
  }

  /// Parses a week string like "1-16(双), 3-5" into a binary string of length maxWeeks.
  /// '1' means has course, '0' means no course.
  static String parseWeekCode(String weekStr) {
    if (weekStr.isEmpty) {
      return '0' * maxWeeks;
    }

    final List<String> items = weekStr.split(',');
    final List<String> codeList = List.generate(maxWeeks, (index) => '0');

    for (String rawItem in items) {
      if (rawItem.trim().isEmpty) continue;

      int step = 1;
      String item = rawItem.trim();

      bool isOdd = false;
      bool isEven = false;

      item = item.replaceAll('周', '');

      if (item.contains('(单)')) {
        step = 2;
        isOdd = true;
        item = item.replaceAll('(单)', '');
      } else if (item.contains('(双)')) {
        step = 2;
        isEven = true;
        item = item.replaceAll('(双)', '');
      }

      int start = 1;
      int end = 1;
      if (item.contains('-')) {
        final parts = item.split('-');
        start = int.tryParse(parts[0]) ?? 1;
        end = int.tryParse(parts[1]) ?? start;
      } else {
        start = int.tryParse(item) ?? 1;
        end = start;
      }

      if (isOdd && start % 2 == 0) start++;
      if (isEven && start % 2 != 0) start++;

      for (int i = start; i <= end; i += step) {
        if (i > 0 && i <= maxWeeks) {
          codeList[i - 1] = '1';
        }
      }
    }

    return codeList.join('');
  }

  /// The input string might contain "节" or "周" characters which should be ignored.
  static List<int> getStartAndStep(String jcor) {
    if (jcor.isEmpty) return [1, 2];

    String cleanJcor = jcor.replaceAll(RegExp(r'[^0-9\-]'), '');

    final parts = cleanJcor.split('-');
    if (parts.length >= 2) {
      final start = int.tryParse(parts[0]) ?? 1;
      final end = int.tryParse(parts[1]) ?? start;
      return [start, end - start + 1];
    } else {
      final start = int.tryParse(cleanJcor) ?? 1;
      return [start, 1];
    }
  }
}
