import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/profile_import.dart';
import 'package:shelf/shelf.dart' as shelf;

shelf.Request _request(Object? body) => shelf.Request(
      'POST',
      Uri.parse('http://localhost/add-profile'),
      body: jsonEncode(body),
    );

void main() {
  test('only one of two concurrent streamed requests can claim an import',
      () async {
    var busy = false;
    final received = <String>[];
    final handler = createProfileImportHandler(
      isAvailable: () => true,
      isBusy: () => busy,
      onReceive: (url) {
        busy = true;
        received.add(url);
      },
    );
    final firstBody = StreamController<List<int>>();
    final secondBody = StreamController<List<int>>();
    final first = handler(shelf.Request('POST', Uri.parse('http://localhost/'),
        body: firstBody.stream));
    final second = handler(shelf.Request('POST', Uri.parse('http://localhost/'),
        body: secondBody.stream));
    firstBody.add(utf8.encode('{"url":"https://example.com/first"}'));
    await firstBody.close();
    expect((await first).statusCode, 200);
    secondBody.add(utf8.encode('{"url":"https://example.com/second"}'));
    await secondBody.close();
    expect((await second).statusCode, 409);
    expect(received, ['https://example.com/first']);
  });

  test('a view closed while reading a request cannot add a profile', () async {
    var available = true;
    final received = <String>[];
    final handler = createProfileImportHandler(
      isAvailable: () => available,
      isBusy: () => false,
      onReceive: received.add,
    );
    final body = StreamController<List<int>>();
    final response = handler(shelf.Request(
        'POST', Uri.parse('http://localhost/'),
        body: body.stream));
    available = false;
    body.add(utf8.encode('{"url":"https://example.com/profile"}'));
    await body.close();
    expect((await response).statusCode, 410);
    expect(received, isEmpty);
  });

  test('malformed and empty payloads do not consume an import attempt',
      () async {
    final received = <String>[];
    final handler = createProfileImportHandler(
      isAvailable: () => true,
      isBusy: () => false,
      onReceive: received.add,
    );
    for (final body in [
      null,
      [],
      {'url': 1},
      {'url': '   '}
    ]) {
      expect((await handler(_request(body))).statusCode, 400);
    }
    expect(
        (await handler(shelf.Request('POST', Uri.parse('http://localhost/'),
                body: 'broken json')))
            .statusCode,
        400);
    expect(received, isEmpty);
    expect(
        (await handler(_request({'url': '  https://example.com/profile  '})))
            .statusCode,
        200);
    expect(received, ['https://example.com/profile']);
  });
}
