// lib/core/utils/week_utils.dart

class WeekUtils {
  static const int MAX_WEEKS = 24; // Assuming 24 weeks max

  /// Parses a week string like "1-16(双), 3-5" into a binary string of length MAX_WEEKS.
  /// '1' means has course, '0' means no course.
  static String parseWeekCode(String weekStr) {
    if (weekStr.isEmpty) {
      return '0' * MAX_WEEKS;
    }

    final List<String> items = weekStr.split(',');
    final List<String> codeList = List.generate(MAX_WEEKS, (index) => '0');

    for (String rawItem in items) {
      if (rawItem.trim().isEmpty) continue;

      int step = 1;
      String item = rawItem.trim();

      bool isOdd = false;
      bool isEven = false;

      // Remove '周' first as it might appear before (单)/(双) or at the end
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

      // Adjust start if needed
      if (isOdd && start % 2 == 0) start++;
      if (isEven && start % 2 != 0) start++;

      for (int i = start; i <= end; i += step) {
        if (i > 0 && i <= MAX_WEEKS) {
          codeList[i - 1] = '1';
        }
      }
    }

    return codeList.join('');
  }

  /// The input string might contain "节" or "周" characters which should be ignored.
  static List<int> getStartAndStep(String jcor) {
    if (jcor.isEmpty) return [1, 2];

    // Clean up non-numeric characters except dash
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
