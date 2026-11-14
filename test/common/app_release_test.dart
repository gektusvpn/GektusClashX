import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/app_release.dart';
import 'package:gektusclashx/models/config.dart';

Map<String, dynamic> release(String tag,
        {bool pre = false, bool draft = false}) =>
    {'tag_name': tag, 'prerelease': pre, 'draft': draft, 'assets': []};

void main() {
  late Dio dio;
  late AppReleaseUpdates updates;
  late List<RequestOptions> calls;
  late Object Function(RequestOptions) respond;

  setUp(() {
    calls = [];
    dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(options);
      final data = respond(options);
      if (data is DioException) {
        handler.reject(data);
      } else {
        handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200));
      }
    }));
    updates = AppReleaseUpdates(dio,
        repository: 'owner/repo', githubUrl: (url) => url);
  });
  tearDown(() => dio.close(force: true));

  test('old and unknown settings default to stable; selection round-trips', () {
    expect(AppSettingProps.fromJson({}).updateChannel, AppUpdateChannel.stable);
    expect(AppSettingProps.fromJson({'updateChannel': 'future'}).updateChannel,
        AppUpdateChannel.stable);
    const settings = AppSettingProps(updateChannel: AppUpdateChannel.testing);
    expect(AppSettingProps.fromJson(settings.toJson()).updateChannel,
        AppUpdateChannel.testing);
  });

  test('SemVer orders numbered previews and the final release; ignores builds',
      () {
    final versions = ['v0.6.0-pre.2', '0.6.0-pre.10', '0.6.0-rc.1', '0.6.0'];
    for (var i = 1; i < versions.length; i++) {
      expect(parseAppVersion(versions[i])! > parseAppVersion(versions[i - 1])!,
          isTrue);
    }
    expect(parseAppVersion('0.6.0+123'), parseAppVersion('0.6.0+456'));
    for (final invalid in [
      'core-1.2.3',
      'garbage',
      '1.2',
      '01.2.3',
      '1.2.3-pre.01',
      '1.2.3+',
      '1.2.3+bad metadata'
    ]) {
      expect(parseAppVersion(invalid), isNull, reason: invalid);
    }
  });

  test('stable retains the legacy manifest endpoint and payload', () async {
    respond = (_) => release('v0.6.0');
    expect(
        (await updates.check(
            channel: AppUpdateChannel.stable,
            currentVersion: '0.5.6'))?['tag_name'],
        'v0.6.0');
    expect(calls.single.uri.toString(),
        'https://github.com/owner/repo/releases/latest/download/update.json');
  });

  for (final badManifest in [
    release('v0.7.0-pre.1', pre: true),
    release('v0.7.0', pre: true),
    release('v0.7.0', draft: true),
    release('core-1.2.3'),
  ]) {
    test('stable rejects unsafe manifest $badManifest and uses stable API',
        () async {
      respond = (options) =>
          options.uri.host == 'github.com' ? badManifest : release('v0.6.0');
      expect(
          (await updates.check(
              channel: AppUpdateChannel.stable,
              currentVersion: '0.5.6'))?['tag_name'],
          'v0.6.0');
      expect(calls.last.uri.path, '/repos/owner/repo/releases/latest');
    });
  }

  test('missing manifest falls back; unsafe API results are not offered',
      () async {
    respond = (options) => options.uri.host == 'github.com'
        ? DioException(
            requestOptions: options, type: DioExceptionType.connectionError)
        : release('v0.7.0-pre.1', pre: true);
    expect(
        await updates.check(
            channel: AppUpdateChannel.stable, currentVersion: '0.5.6'),
        isNull);
    expect(calls.length, 2);
  });

  test(
      'testing searches every page and selects by version, excluding drafts and core',
      () async {
    respond = (options) => options.queryParameters['page'] == 1
        ? List.generate(100, (_) => release('core-99.0.0'))
        : [
            release('v0.6.0-pre.10', pre: true),
            release('v0.6.0-pre.2', pre: true),
            release('v99.0.0', draft: true),
            release('bad'),
            release('v0.5.6')
          ];
    expect(
        (await updates.check(
            channel: AppUpdateChannel.testing,
            currentVersion: '0.5.6'))?['tag_name'],
        'v0.6.0-pre.10');
    expect(calls.length, 2);
    expect(calls.last.queryParameters['page'], 2);
  });

  test('testing offers the final stable release after previews', () async {
    respond = (_) => [release('v0.6.0-pre.10', pre: true), release('v0.6.0')];
    expect(
        (await updates.check(
            channel: AppUpdateChannel.testing,
            currentVersion: '0.6.0-pre.10'))?['tag_name'],
        'v0.6.0');
  });

  for (final current in ['0.6.0', '0.7.0-pre.1', '0.7.0']) {
    test('stable never offers equal or older version to $current', () async {
      respond = (_) => release('v0.6.0');
      expect(
          await updates.check(
              channel: AppUpdateChannel.stable, currentVersion: current),
          isNull);
    });
  }
}
