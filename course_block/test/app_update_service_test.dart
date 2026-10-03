import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:course_block/core/models/app_version.dart';
import 'package:course_block/core/services/app_update_service.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options, cancelFuture);

  @override
  void close({bool force = false}) {}
}

ResponseBody _release({
  String tag = 'v1.1.3',
  bool draft = false,
  bool prerelease = false,
  String? url,
}) => ResponseBody.fromString(
  jsonEncode({
    'tag_name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'html_url': url ?? '${AppUpdateService.repositoryUrl}/releases/tag/$tag',
    'body': '修复与改进',
  }),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('version comparison is numeric and ignores build metadata', () {
    expect(
      AppVersion.parse('v1.10.0').compareTo(AppVersion.parse('1.9.9')),
      greaterThan(0),
    );
    expect(
      AppVersion.parse('1.1.2+2003').compareTo(AppVersion.parse('v1.1.2+3')),
      0,
    );
    expect(
      AppVersion.parse('1.2.0').compareTo(AppVersion.parse('1.2.0-rc.1')),
      greaterThan(0),
    );
    expect(
      AppVersion.parse('1.2.0-rc.10').compareTo(AppVersion.parse('1.2.0-rc.2')),
      greaterThan(0),
    );
    expect(
      AppVersion.parse(
        '1.2.0-alpha.1',
      ).compareTo(AppVersion.parse('1.2.0-beta')),
      lessThan(0),
    );
  });

  test('malformed versions are rejected', () {
    for (final value in ['latest', '1.2', '1.2.3.4', '1.2.3-rc..1', '-1.2.3']) {
      expect(() => AppVersion.parse(value), throwsFormatException);
    }
  });

  test('only a newer stable release is offered, never a downgrade', () async {
    for (final tag in ['v1.1.1', 'v1.1.2', 'v1.1.3', 'v1.10.0']) {
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_, _) async => _release(tag: tag));
      final service = AppUpdateService(
        dio: dio,
        currentVersion: () async => '1.1.2',
      );
      final update = await service.checkForUpdate();
      expect(
        update?.version,
        tag == 'v1.1.3' || tag == 'v1.10.0' ? tag.substring(1) : null,
      );
    }
  });

  test('drafts and prereleases are not offered', () async {
    for (final body in [
      _release(draft: true),
      _release(prerelease: true),
      _release(tag: 'v1.2.0-beta'),
    ]) {
      final dio = Dio()..httpClientAdapter = _Adapter((_, _) async => body);
      expect(
        await AppUpdateService(
          dio: dio,
          currentVersion: () async => '1.1.2',
        ).checkForUpdate(),
        isNull,
      );
    }
  });

  test(
    'disabled automatic checks do not make requests; manual checks still work',
    () async {
      SharedPreferences.setMockInitialValues({
        CourseSettingsStore.autoUpdateEnabledKey: false,
      });
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_, _) async {
          calls++;
          return _release();
        });
      final service = AppUpdateService(
        dio: dio,
        currentVersion: () async => '1.1.2',
      );
      expect(await service.checkForUpdate(automatic: true), isNull);
      expect(calls, 0);
      expect(await service.isAutomaticCheckEnabled(), isFalse);
      expect((await service.checkForUpdate())?.version, '1.1.3');
      expect(calls, 1);
    },
  );

  test(
    'automatic checks run once per successful local day; manual checks bypass',
    () async {
      var day = DateTime(2026, 10, 3);
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_, _) async {
          calls++;
          return _release();
        });
      final service = AppUpdateService(
        dio: dio,
        currentVersion: () async => '1.1.2',
        now: () => day,
      );
      expect(await service.isAutomaticCheckEnabled(), isTrue);
      expect(await service.checkForUpdate(automatic: true), isNotNull);
      expect(await service.checkForUpdate(automatic: true), isNull);
      expect(calls, 1);
      await service.checkForUpdate();
      expect(calls, 2);
      day = DateTime(2026, 10, 4);
      await service.checkForUpdate(automatic: true);
      expect(calls, 3);
    },
  );

  test('a failed check can be retried the same day', () async {
    var calls = 0;
    final dio = Dio()
      ..httpClientAdapter = _Adapter((_, _) async {
        calls++;
        return calls == 1
            ? ResponseBody.fromString('unavailable', 503)
            : _release();
      });
    final service = AppUpdateService(
      dio: dio,
      currentVersion: () async => '1.1.2',
    );
    await expectLater(
      service.checkForUpdate(automatic: true),
      throwsA(isA<DioException>()),
    );
    expect(await service.checkForUpdate(automatic: true), isNotNull);
    expect(calls, 2);
  });

  test('missing releases are handled without offering an update', () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter(
        (_, _) async => ResponseBody.fromString('{}', 404),
      );
    expect(
      await AppUpdateService(
        dio: dio,
        currentVersion: () async => '1.1.2',
      ).checkForUpdate(),
      isNull,
    );
  });

  test('foreign or non-HTTPS release links are rejected', () async {
    for (final url in [
      'http://github.com/Labyrinth0419/SJTU-Course-Block/releases/latest',
      'https://example.com/app.apk',
      'https://github.com/other/repo/releases/latest',
    ]) {
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_, _) async => _release(url: url));
      await expectLater(
        AppUpdateService(
          dio: dio,
          currentVersion: () async => '1.1.2',
        ).checkForUpdate(),
        throwsFormatException,
      );
    }
  });

  test('simultaneous checks share a request', () async {
    var calls = 0;
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    final dio = Dio()
      ..httpClientAdapter = _Adapter((_, _) {
        calls++;
        started.complete();
        return response.future;
      });
    final service = AppUpdateService(
      dio: dio,
      currentVersion: () async => '1.1.2',
    );
    final first = service.checkForUpdate();
    await started.future;
    final second = service.checkForUpdate();
    response.complete(_release());
    expect((await first)?.version, '1.1.3');
    expect((await second)?.version, '1.1.3');
    expect(calls, 1);
  });

  test(
    'overall deadline cancels a stalled request and releases the next check',
    () async {
      final cancelled = Completer<void>();
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_, cancelFuture) {
          cancelFuture?.then((_) {
            if (!cancelled.isCompleted) cancelled.complete();
          });
          return Completer<ResponseBody>().future;
        });
      final service = AppUpdateService(
        dio: dio,
        currentVersion: () async => '1.1.2',
        requestTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        service.checkForUpdate(),
        throwsA(isA<TimeoutException>()),
      );
      await cancelled.future.timeout(const Duration(seconds: 1));
      dio.httpClientAdapter = _Adapter((_, _) async => _release());
      expect(await service.checkForUpdate(), isNotNull);
    },
  );
}
