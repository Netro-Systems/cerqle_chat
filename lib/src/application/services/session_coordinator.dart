part of '../cerqle_runtime.dart';

/// Coordinates identity-scoped restoration and secure session persistence.
///
/// The active namespace changes before another identity can restore, ensuring
/// a token from one visitor scope is never sent for another visitor.
final class _SessionCoordinator {
  _SessionCoordinator({
    required this.config,
    required WidgetRemoteDataSource remoteDataSource,
    required CerqleSessionStore sessionStore,
  }) : _remoteDataSource = remoteDataSource,
       _sessionStore = sessionStore,
       _activeUser = config.user {
    _unsignedEphemeralScope = createEphemeralScopeId();
    _namespace = sessionNamespace(
      config: config,
      user: _activeUser,
      unsignedEphemeralScope: _unsignedEphemeralScope,
    );
  }

  final CerqleConfig config;
  final WidgetRemoteDataSource _remoteDataSource;
  final CerqleSessionStore _sessionStore;
  late String _unsignedEphemeralScope;
  late String _namespace;
  CerqleUser? _activeUser;
  CerqleStoredSession? _session;

  CerqleUser? get activeUser => _activeUser;

  Future<WidgetSessionResult> start({String? deviceId}) async {
    final stored = _session ?? await _readStoredSession();
    final result = await _remoteDataSource.startSession(
      widgetKey: config.widgetKey,
      user: _activeUser,
      storedSession: stored,
      preChatCompleted: stored?.preChatCompleted ?? false,
      deviceId: deviceId,
    );
    await _writeStoredSession(result.session);
    _session = result.session;
    return result;
  }

  Future<WidgetSessionResult> submitPreChat(
    CerqlePreChatData preChat, {
    String? deviceId,
  }) async {
    final current = requireSession();
    final active = _activeUser;
    final result = await _remoteDataSource.startSession(
      widgetKey: config.widgetKey,
      user: CerqleUser(
        externalId: active?.externalId,
        name: preChat.name ?? active?.name,
        email: preChat.email ?? active?.email,
        avatarUrl: active?.avatarUrl,
        signature: active?.signature,
      ),
      storedSession: current,
      preChatCompleted: true,
      deviceId: deviceId,
    );
    await _writeStoredSession(result.session);
    _session = result.session;
    return result;
  }

  Future<void> markPreChatCompleted() async {
    final current = requireSession();
    if (current.preChatCompleted) return;
    final completed = CerqleStoredSession(
      visitorId: current.visitorId,
      token: current.token,
      savedAt: current.savedAt,
      preChatCompleted: true,
      schemaVersion: current.schemaVersion,
    );
    await _writeStoredSession(completed);
    _session = completed;
  }

  Future<bool> switchUser(CerqleUser? user) async {
    // Passing null is the host application's logout signal, even when the
    // current chat scope is already anonymous. Always discard that scope so a
    // later initialize cannot restore pre-logout visitor credentials.
    if (user == null) {
      final previousNamespace = _namespace;
      await _deleteStoredSession(previousNamespace);
      _activeUser = null;
      _unsignedEphemeralScope = createEphemeralScopeId();
      _namespace = sessionNamespace(config: config, user: null);
      if (_namespace != previousNamespace) {
        await _deleteStoredSession(_namespace);
      }
      _session = null;
      return true;
    }
    if (_sameUser(_activeUser, user)) return false;
    final candidate = CerqleConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      user: user,
      theme: config.theme,
      useApiColors: config.useApiColors,
      presentation: config.presentation,
      enableTyping: config.enableTyping,
      mediaAdapter: config.mediaAdapter,
      polling: config.polling,
      diagnostics: config.diagnostics,
    );
    validateCerqleConfig(candidate);

    final previousNamespace = _namespace;
    final nextEphemeral = createEphemeralScopeId();
    final nextNamespace = sessionNamespace(
      config: config,
      user: user,
      unsignedEphemeralScope: nextEphemeral,
    );
    _activeUser = user;
    if (nextNamespace == previousNamespace) return true;
    _unsignedEphemeralScope = nextEphemeral;
    _namespace = nextNamespace;
    _session = null;
    return true;
  }

  Future<void> clear() async {
    await _deleteStoredSession(_namespace);
    _session = null;
  }

  CerqleStoredSession requireSession() {
    final session = _session;
    if (session == null) {
      throw const CerqleException(
        code: CerqleErrorCode.unauthorized,
        message: 'The chat session is not ready.',
        retryable: true,
      );
    }
    return session;
  }

  void disposeMemory() => _session = null;

  Future<CerqleStoredSession?> _readStoredSession() async {
    if (!_shouldPersistActiveSession) return null;
    try {
      return await _sessionStore.read(_namespace);
    } on CerqleException {
      rethrow;
    } on Object {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'Secure session storage is unavailable.',
        retryable: false,
      );
    }
  }

  Future<void> _writeStoredSession(CerqleStoredSession session) async {
    if (!_shouldPersistActiveSession) return;
    try {
      await _sessionStore.write(_namespace, session);
    } on CerqleException {
      rethrow;
    } on Object {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'Could not save the chat session securely.',
        retryable: false,
      );
    }
  }

  Future<void> _deleteStoredSession(String namespace) async {
    try {
      await _sessionStore.delete(namespace);
    } on CerqleException {
      rethrow;
    } on Object {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'Could not clear the secure chat session.',
        retryable: false,
      );
    }
  }

  bool get _shouldPersistActiveSession =>
      isAnonymousEquivalentUser(_activeUser) ||
      _activeUser?.signature != null ||
      unsignedStableIdentityValue(_activeUser) != null;

  bool _sameUser(CerqleUser? left, CerqleUser? right) =>
      left?.externalId == right?.externalId &&
      left?.name == right?.name &&
      left?.email == right?.email &&
      left?.avatarUrl == right?.avatarUrl &&
      left?.signature == right?.signature;
}

/// Validates configuration at the application composition boundary.
void validateCerqleRuntimeConfig(CerqleConfig config) {
  validateCerqleConfig(config);
}

/// Returns the identity-scoped key used to prevent duplicate presentations.
String cerqlePresentationScope(CerqleConfig config) =>
    presentationScopeKey(config);

/// Clears default secure credentials without exposing storage to presentation.
Future<void> resetCerqleStoredSession(CerqleConfig config) async {
  validateCerqleConfig(config);
  final user = config.user;
  if (user != null &&
      !isAnonymousEquivalentUser(user) &&
      user.signature == null &&
      unsignedStableIdentityValue(user) == null) {
    return;
  }
  final namespace = sessionNamespace(config: config, user: user);
  await FlutterSecureCerqleSessionStore().delete(namespace);
}
