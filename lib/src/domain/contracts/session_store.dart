/// Credential record used to restore one identity-scoped visitor session.
///
/// The token is a bearer credential. Implementations must store it securely
/// and must not log or expose it through diagnostics.
class CerqleStoredSession {
  /// Creates a stored session record.
  const CerqleStoredSession({
    required this.visitorId,
    required this.token,
    required this.savedAt,
    this.preChatCompleted = false,
    this.schemaVersion = 1,
  });

  /// Backend visitor identifier bound to [token].
  final String visitorId;

  /// Encrypted visitor bearer token.
  final String token;

  /// Time this record was last persisted.
  final DateTime savedAt;

  /// Whether required pre-chat was previously accepted for this session.
  final bool preChatCompleted;

  /// Storage schema used to reject incompatible records safely.
  final int schemaVersion;

  @override
  String toString() =>
      'CerqleStoredSession(visitorId: [redacted], token: [redacted], '
      'savedAt: $savedAt, preChatCompleted: $preChatCompleted, '
      'schemaVersion: $schemaVersion)';
}

/// Secure persistence contract for visitor credentials.
///
/// Namespaces are already scoped by API origin, widget key, identity, and
/// schema. Implementations must keep the visitor ID and token atomic.
abstract interface class CerqleSessionStore {
  /// Reads a stored session for [namespace], or returns null when absent.
  Future<CerqleStoredSession?> read(String namespace);

  /// Atomically writes [session] under [namespace].
  Future<void> write(String namespace, CerqleStoredSession session);

  /// Deletes the record under [namespace].
  Future<void> delete(String namespace);
}
