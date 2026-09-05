import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/data/storage/secure_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const namespace = 'cerqle.test.session';
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('round trips versioned session credentials', () async {
    final store = FlutterSecureCerqleSessionStore(storage: storage);
    final session = CerqleStoredSession(
      visitorId: 'visitor-1',
      token: 'secret-token',
      savedAt: DateTime.utc(2026, 8, 8),
      preChatCompleted: true,
    );

    await store.write(namespace, session);
    final restored = await store.read(namespace);

    expect(restored?.visitorId, session.visitorId);
    expect(restored?.token, session.token);
    expect(restored?.preChatCompleted, isTrue);
    expect(restored?.schemaVersion, 1);
  });

  test('malformed or obsolete records are deleted during restoration',
      () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      namespace: jsonEncode(<String, Object>{
        'visitor_id': 'visitor-1',
        'token': 'secret-token',
        'saved_at': 'not-a-date',
        'schema_version': 1,
      }),
    });
    final store = FlutterSecureCerqleSessionStore(storage: storage);

    expect(await store.read(namespace), isNull);
    expect(await storage.read(key: namespace), isNull);
  });

  test('keeps only the fifteen newest secure sessions', () async {
    final store = FlutterSecureCerqleSessionStore(storage: storage);

    for (var index = 0; index < 16; index++) {
      await store.write(
        'cerqle.test.session.$index',
        CerqleStoredSession(
          visitorId: 'visitor-$index',
          token: 'token-$index',
          savedAt: DateTime.utc(2026, 8, 8, 12, index),
        ),
      );
    }

    expect(await store.read('cerqle.test.session.0'), isNull);
    expect(await store.read('cerqle.test.session.1'), isNotNull);
    expect(await store.read('cerqle.test.session.15'), isNotNull);
  });

  test('rewriting an old session keeps it inside the fifteen-session limit',
      () async {
    final store = FlutterSecureCerqleSessionStore(storage: storage);

    for (var index = 0; index < 15; index++) {
      await store.write(
        'cerqle.test.session.$index',
        CerqleStoredSession(
          visitorId: 'visitor-$index',
          token: 'token-$index',
          savedAt: DateTime.utc(2026, 8, 8, 12, index),
        ),
      );
    }
    await store.write(
      'cerqle.test.session.0',
      CerqleStoredSession(
        visitorId: 'visitor-0-new',
        token: 'token-0-new',
        savedAt: DateTime.utc(2026, 8, 8, 13),
      ),
    );
    await store.write(
      'cerqle.test.session.15',
      CerqleStoredSession(
        visitorId: 'visitor-15',
        token: 'token-15',
        savedAt: DateTime.utc(2026, 8, 8, 14),
      ),
    );

    final rewritten = await store.read('cerqle.test.session.0');
    expect(rewritten?.visitorId, 'visitor-0-new');
    expect(await store.read('cerqle.test.session.1'), isNull);
    expect(await store.read('cerqle.test.session.15'), isNotNull);
  });

  test('delete removes a secure session from the pruning index', () async {
    final store = FlutterSecureCerqleSessionStore(storage: storage);

    await store.write(
      namespace,
      CerqleStoredSession(
        visitorId: 'visitor-1',
        token: 'token-1',
        savedAt: DateTime.utc(2026, 8, 8),
      ),
    );
    await store.delete(namespace);

    for (var index = 0; index < 15; index++) {
      await store.write(
        'cerqle.test.session.$index',
        CerqleStoredSession(
          visitorId: 'visitor-$index',
          token: 'token-$index',
          savedAt: DateTime.utc(2026, 8, 9, 12, index),
        ),
      );
    }

    expect(await store.read(namespace), isNull);
    expect(await store.read('cerqle.test.session.0'), isNotNull);
  });
}
