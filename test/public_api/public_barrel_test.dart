import 'package:flutter_test/flutter_test.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

void main() {
  test('public barrel exposes the supported headless integration', () {
    const config = CerqleConfig(widgetKey: 'public-widget-key');
    final client = CerqleClient(
      config: config,
      sessionStore: _NoopSessionStore(),
    );
    final controller = CerqleChatController(client: client);

    expect(controller.config, same(config));

    controller.dispose();
    client.close();
  });
}

final class _NoopSessionStore implements CerqleSessionStore {
  @override
  Future<void> delete(String namespace) async {}

  @override
  Future<CerqleStoredSession?> read(String namespace) async => null;

  @override
  Future<void> write(
    String namespace,
    CerqleStoredSession session,
  ) async {}
}
