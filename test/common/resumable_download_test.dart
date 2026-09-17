import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/resumable_download.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('resumable-download-');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('continues a partial download after the connection is interrupted',
      () async {
    final payload = List<int>.generate(64 * 1024, (index) => index % 251);
    final firstChunkSize = payload.length ~/ 4;
    var requestCount = 0;
    int? requestedOffset;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      requestCount++;
      if (requestCount == 1) {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket
          ..write('HTTP/1.1 200 OK\r\n')
          ..write('Content-Length: ${payload.length}\r\n')
          ..write('Connection: close\r\n\r\n')
          ..add(payload.sublist(0, firstChunkSize));
        await socket.flush();
        socket.destroy();
        return;
      }

      final range = request.headers.value(HttpHeaders.rangeHeader)!;
      requestedOffset =
          int.parse(range.substring('bytes='.length, range.length - 1));
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $requestedOffset-${payload.length - 1}/${payload.length}',
        )
        ..contentLength = payload.length - requestedOffset!
        ..add(payload.sublist(requestedOffset!));
      await request.response.close();
    });

    final target = File('${tempDirectory.path}/update.apk');
    await ResumableDownloader(
      Dio(),
      maxAttempts: 2,
      retryDelay: Duration.zero,
    ).download(
      urls: ['http://${server.address.host}:${server.port}/update.apk'],
      targetPath: target.path,
      expectedSize: payload.length,
      onProgress: (_, __) {},
    );

    expect(requestCount, 2);
    expect(requestedOffset, firstChunkSize);
    expect(await target.readAsBytes(), payload);
  });

  test('replaces a partial file when the server ignores Range', () async {
    final payload = List<int>.generate(4096, (index) => index % 239);
    final target = File('${tempDirectory.path}/update.apk');
    await target.writeAsBytes(payload.sublist(0, 512));
    String? requestedRange;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      requestedRange = request.headers.value(HttpHeaders.rangeHeader);
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = payload.length
        ..add(payload);
      await request.response.close();
    });

    await ResumableDownloader(Dio()).download(
      urls: ['http://${server.address.host}:${server.port}/update.apk'],
      targetPath: target.path,
      expectedSize: payload.length,
      onProgress: (_, __) {},
    );

    expect(requestedRange, 'bytes=512-');
    expect(await target.readAsBytes(), payload);
  });

  test('falls back to the next source after a failed attempt', () async {
    final payload = List<int>.generate(4096, (index) => index % 227);
    var failedSourceRequests = 0;
    final failedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final workingServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(failedServer.close);
    addTearDown(workingServer.close);
    failedServer.listen((request) async {
      failedSourceRequests++;
      request.response.statusCode = HttpStatus.badGateway;
      await request.response.close();
    });
    workingServer.listen((request) async {
      request.response
        ..contentLength = payload.length
        ..add(payload);
      await request.response.close();
    });

    final target = File('${tempDirectory.path}/update.apk');
    await ResumableDownloader(
      Dio(),
      maxAttempts: 2,
      retryDelay: Duration.zero,
    ).download(
      urls: [
        'http://${failedServer.address.host}:${failedServer.port}/update.apk',
        'http://${workingServer.address.host}:${workingServer.port}/update.apk',
      ],
      targetPath: target.path,
      expectedSize: payload.length,
      onProgress: (_, __) {},
    );

    expect(failedSourceRequests, 1);
    expect(await target.readAsBytes(), payload);
  });
}
