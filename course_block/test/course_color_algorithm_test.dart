import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:course_block/core/theme/app_theme.dart';

int _channel(int argb, int shift) => (argb >> shift) & 0xFF;

double _circularHueDistance(double left, double right) {
  final diff = (left - right).abs();
  return diff <= 180.0 ? diff : 360.0 - diff;
}

double _contrastDistance(Color left, Color right) {
  final leftArgb = left.toARGB32();
  final rightArgb = right.toARGB32();
  final dr = (_channel(leftArgb, 16) - _channel(rightArgb, 16)).abs() / 255.0;
  final dg = (_channel(leftArgb, 8) - _channel(rightArgb, 8)).abs() / 255.0;
  final db = (_channel(leftArgb, 0) - _channel(rightArgb, 0)).abs() / 255.0;

  final leftHsv = HSVColor.fromColor(left);
  final rightHsv = HSVColor.fromColor(right);
  final hue = _circularHueDistance(leftHsv.hue, rightHsv.hue) / 180.0;
  final saturation = (leftHsv.saturation - rightHsv.saturation).abs();
  final value = (leftHsv.value - rightHsv.value).abs();

  return hue * 2.8 +
      saturation * 0.9 +
      value * 0.6 +
      dr * 0.7 +
      dg * 1.1 +
      db * 0.8;
}

void main() {
  group('course color algorithm', () {
    test('seed normalization keeps same course identity stable', () {
      expect(
        buildCourseColorSeed(' Linear Algebra ', 'Alice'),
        buildCourseColorSeed('linear algebra', ' alice '),
      );
    });

    test('auto token is deterministic and differs for different courses', () {
      final first = AppCourseColorPalette.candyBox.autoColorToken(
        buildCourseColorSeed('Data Structures', 'Alice'),
      );
      final sameAgain = AppCourseColorPalette.candyBox.autoColorToken(
        buildCourseColorSeed('data structures', 'alice'),
      );
      final second = AppCourseColorPalette.candyBox.autoColorToken(
        buildCourseColorSeed('Operating Systems', 'Alice'),
      );

      expect(first, sameAgain);
      expect(first, isNot(second));
    });

    test('manual palette token still resolves to exact swatch', () {
      final swatches = AppCourseColorPalette.jellySoda.colors(Brightness.light);
      final resolved = resolveCourseCardColor(
        colorValue: buildCourseColorToken(3),
        palette: AppCourseColorPalette.jellySoda,
        brightness: Brightness.light,
        seed: buildCourseColorSeed('Physics', 'Bob'),
      );

      expect(resolved.toARGB32(), swatches[3].toARGB32());
    });

    test(
      'generated color stays stable for same seed and differs by course',
      () {
        final firstSeed = buildCourseColorSeed('Physics', 'Bob');
        final secondSeed = buildCourseColorSeed('Chemistry', 'Bob');

        final first = resolveCourseCardColor(
          colorValue: AppCourseColorPalette.tokyoNeon.autoColorToken(firstSeed),
          palette: AppCourseColorPalette.tokyoNeon,
          brightness: Brightness.dark,
          seed: firstSeed,
        );
        final firstAgain = resolveCourseCardColor(
          colorValue: null,
          palette: AppCourseColorPalette.tokyoNeon,
          brightness: Brightness.dark,
          seed: firstSeed,
        );
        final second = resolveCourseCardColor(
          colorValue: AppCourseColorPalette.tokyoNeon.autoColorToken(
            secondSeed,
          ),
          palette: AppCourseColorPalette.tokyoNeon,
          brightness: Brightness.dark,
          seed: secondSeed,
        );

        expect(first.toARGB32(), firstAgain.toARGB32());
        expect(first.toARGB32(), isNot(second.toARGB32()));
      },
    );

    test(
      'schedule assignment keeps same identity same color and unique base slots',
      () {
        final assignments = assignScheduledCourseColorTokens(const [
          CourseColorIdentityEntry(identity: 'math|alice', colorValue: ''),
          CourseColorIdentityEntry(identity: 'math|alice', colorValue: ''),
          CourseColorIdentityEntry(identity: 'physics|bob', colorValue: ''),
          CourseColorIdentityEntry(identity: 'chemistry|cathy', colorValue: ''),
        ], swatches: AppCourseColorPalette.candyBox.colors(Brightness.light));

        expect(assignments['math|alice'], isNotNull);
        expect(assignments['math|alice'], assignments['math|alice']);
        expect(assignments['math|alice'], isNot(assignments['physics|bob']));
        expect(
          assignments['physics|bob'],
          isNot(assignments['chemistry|cathy']),
        );
      },
    );

    test('schedule assignment derives overflow colors after pool is full', () {
      final entries = List.generate(
        19,
        (index) => CourseColorIdentityEntry(
          identity: 'course$index|teacher$index',
          colorValue: '',
        ),
      );
      final assignments = assignScheduledCourseColorTokens(
        entries,
        swatches: AppCourseColorPalette.candyBox.colors(Brightness.light),
      );

      final overflow = assignments.values.where(
        (value) => value.contains(':1'),
      );
      expect(overflow, isNotEmpty);
    });

    test('two courses get the highest contrast pair in the pool', () {
      final swatches = AppCourseColorPalette.candyBox.colors(Brightness.light);
      final assignments = assignScheduledCourseColorTokens(const [
        CourseColorIdentityEntry(identity: 'math|alice', colorValue: ''),
        CourseColorIdentityEntry(identity: 'physics|bob', colorValue: ''),
      ], swatches: swatches);

      final selected = assignments.values
          .map((value) => parseScheduledCourseColorToken(value)!)
          .toList();
      final selectedPair = {selected[0].slot, selected[1].slot};

      var bestLeft = 0;
      var bestRight = 1;
      var bestDistance = -1.0;
      for (var left = 0; left < swatches.length - 1; left++) {
        for (var right = left + 1; right < swatches.length; right++) {
          final distance = _contrastDistance(swatches[left], swatches[right]);
          if (distance > bestDistance) {
            bestDistance = distance;
            bestLeft = left;
            bestRight = right;
          }
        }
      }

      expect(selectedPair, {bestLeft, bestRight});
    });
  });
}
