import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/data/network/response_decoder.dart';

import '../../support/support.dart';

void main() {
  const decoder = WidgetResponseDecoder();

  test('activity marker is decoded and preserved by message updates', () {
    final result = decoder.refresh(http.Response(
      jsonEncode(refreshResponse(messages: <Map<String, Object?>>[
        {...message(id: 1), 'kind': 'activity'},
        {...message(id: 2), 'kind': 'message'},
        message(id: 3),
      ])),
      200,
    ));

    expect(result.messages.first.isActivity, isTrue);
    expect(result.messages.first.copyWith(body: 'Updated').isActivity, isTrue);
    expect(result.messages[1].isActivity, isFalse);
    expect(result.messages[2].isActivity, isFalse);
  });

  test('session decoder ignores unknown fields and maps known values', () {
    final result = decoder.session(
      http.Response(
        jsonEncode(
          sessionResponse(messages: <Map<String, Object?>>[
            message(id: 4, body: 'Welcome'),
          ]),
        ),
        200,
      ),
      preChatCompleted: false,
    );

    expect(result.session.visitorId, 'visitor-1');
    expect(result.conversationId, 42);
    expect(result.messages.single.serverId, 4);
    expect(result.widget.title, 'Test support');
  });

  test('malformed responses become typed errors without leaking content', () {
    const secret = 'private-message-body';

    expect(
      () => decoder.refresh(http.Response('{"secret":"$secret"}', 200)),
      throwsA(
        isA<CerqleException>()
            .having((error) => error.code, 'code', CerqleErrorCode.server)
            .having(
              (error) => error.toString(),
              'redacted description',
              isNot(contains(secret)),
            ),
      ),
    );
  });
}
