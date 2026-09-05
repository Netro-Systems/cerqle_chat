import 'package:cerqle_chat/cerqle_chat.dart';

/// In-memory credential store that records persistence interactions.
final class MemorySessionStore implements CerqleSessionStore {
  final Map<String, CerqleStoredSession> values =
      <String, CerqleStoredSession>{};
  final List<String> reads = <String>[];
  final List<String> writes = <String>[];
  final List<String> deletes = <String>[];

  @override
  Future<CerqleStoredSession?> read(String namespace) async {
    reads.add(namespace);
    return values[namespace];
  }

  @override
  Future<void> write(
    String namespace,
    CerqleStoredSession session,
  ) async {
    writes.add(namespace);
    values[namespace] = session;
  }

  @override
  Future<void> delete(String namespace) async {
    deletes.add(namespace);
    values.remove(namespace);
  }
}
