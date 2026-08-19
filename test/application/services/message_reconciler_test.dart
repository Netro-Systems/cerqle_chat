import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/application/services/message_reconciler.dart';

void main() {
  const reconciler = MessageReconciler();

  test('deduplicates by server ID and preserves the existing local ID', () {
    final upload = CerqleUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      filename: 'local.png',
      mimeType: 'image/png',
    );
    final existing = _message(
      localId: 'pending-1',
      serverId: 4,
      body: 'old',
      localUpload: upload,
    );
    final replacement = _message(
      localId: 'server-4',
      serverId: 4,
      body: 'authoritative',
    );

    final result = reconciler
        .merge(<CerqleMessage>[existing], <CerqleMessage>[replacement]);

    expect(result, hasLength(1));
    expect(result.single.localId, 'pending-1');
    expect(result.single.localUpload?.filename, 'local.png');
    expect(result.single.body, 'authoritative');
  });

  test('orders server messages before pending local messages', () {
    final result = reconciler.merge(
      <CerqleMessage>[_message(localId: 'pending', serverId: null)],
      <CerqleMessage>[
        _message(localId: 'two', serverId: 2),
        _message(localId: 'one', serverId: 1),
      ],
    );

    expect(result.map((message) => message.localId),
        <String>['one', 'two', 'pending']);
    expect(reconciler.greatestServerId(result, fallback: 0), 2);
  });
}

CerqleMessage _message({
  required String localId,
  required int? serverId,
  String body = 'message',
  CerqleUpload? localUpload,
}) =>
    CerqleMessage(
      localId: localId,
      serverId: serverId,
      role: CerqleMessageRole.agent,
      type: CerqleMessageType.text,
      body: body,
      status: CerqleMessageStatus.sent,
      createdAt: DateTime.utc(2026, 8, 6),
      localUpload: localUpload,
    );
