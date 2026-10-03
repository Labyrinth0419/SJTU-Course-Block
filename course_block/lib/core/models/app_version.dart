class AppVersion implements Comparable<AppVersion> {
  AppVersion._(this.parts, this.prerelease);

  final List<int> parts;
  final List<String> prerelease;

  static AppVersion parse(String value) {
    final match = RegExp(
      r'^v?([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(value.trim());
    if (match == null || value.length > 160) {
      throw FormatException('Invalid application version');
    }
    final parts = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
    final prerelease = match.group(4)?.split('.') ?? <String>[];
    if (prerelease.any((part) => part.isEmpty)) {
      throw FormatException('Invalid prerelease version');
    }
    return AppVersion._(parts, prerelease);
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < parts.length; i++) {
      final comparison = parts[i].compareTo(other.parts[i]);
      if (comparison != 0) return comparison;
    }
    if (prerelease.isEmpty || other.prerelease.isEmpty) {
      if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
      return prerelease.isEmpty ? 1 : -1;
    }
    for (var i = 0; i < prerelease.length && i < other.prerelease.length; i++) {
      final left = int.tryParse(prerelease[i]);
      final right = int.tryParse(other.prerelease[i]);
      final comparison = left != null && right != null
          ? left.compareTo(right)
          : left != null
          ? -1
          : right != null
          ? 1
          : prerelease[i].compareTo(other.prerelease[i]);
      if (comparison != 0) return comparison;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }
}
