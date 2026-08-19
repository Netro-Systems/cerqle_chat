part of '../cerqle_runtime.dart';

/// Owns HTTP and secure-session resources for one widget configuration.
///
/// Create a controller with [CerqleChatController] and call [close] after
/// every controller using this client has been disposed.
class CerqleClient {
  /// Creates a client with injectable transport and credential storage.
  ///
  /// The client owns a default HTTP client and secure store. Injected
  /// dependencies remain caller-owned. Throws [CerqleException] when the
  /// configuration is invalid.
  CerqleClient({
    required this.config,
    http.Client? httpClient,
    CerqleSessionStore? sessionStore,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    validateCerqleConfig(config);
    final baseUrl = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
    _remoteDataSource = _createWidgetRemoteDataSource(
      baseUrl: baseUrl,
      httpClient: _httpClient,
    );
    _sessions = _SessionCoordinator(
      config: config,
      remoteDataSource: _remoteDataSource,
      sessionStore: sessionStore ?? FlutterSecureCerqleSessionStore(),
    );
  }

  /// Immutable configuration used for every operation.
  final CerqleConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  late final WidgetRemoteDataSource _remoteDataSource;
  late final _SessionCoordinator _sessions;
  bool _closed = false;

  CerqleUser? get _activeUser => _sessions.activeUser;

  Future<WidgetSessionResult> _startSession() {
    _ensureOpen();
    return _sessions.start();
  }

  Future<WidgetPollResult> _poll(int after) {
    final session = _requireSession();
    return _remoteDataSource.poll(
      widgetKey: config.widgetKey,
      token: session.token,
      after: after,
    );
  }

  Future<WidgetSendResult> _sendText(String text) {
    final session = _requireSession();
    return _remoteDataSource.sendText(
      widgetKey: config.widgetKey,
      token: session.token,
      text: text,
    );
  }

  Future<WidgetSendResult> _sendUpload(
    CerqleUpload upload,
    CerqleMessageType type,
    String? caption,
  ) {
    final session = _requireSession();
    return _remoteDataSource.sendUpload(
      widgetKey: config.widgetKey,
      token: session.token,
      upload: upload,
      type: type,
      caption: caption,
    );
  }

  Future<Uint8List> _loadAttachmentBytes(CerqleAttachment attachment) {
    final session = _requireSession();
    return _remoteDataSource.loadAttachmentBytes(
      token: session.token,
      attachment: attachment,
    );
  }

  Future<void> _setTyping(bool isTyping) {
    final session = _requireSession();
    return _remoteDataSource.setTyping(
      widgetKey: config.widgetKey,
      token: session.token,
      isTyping: isTyping,
    );
  }

  Future<CerqleHandoffState> _requestHandoff() {
    final session = _requireSession();
    return _remoteDataSource.requestHandoff(
      widgetKey: config.widgetKey,
      token: session.token,
    );
  }

  Future<WidgetSessionResult> _submitPreChat(CerqlePreChatData preChat) =>
      _sessions.submitPreChat(preChat);

  Future<void> _markPreChatCompleted() => _sessions.markPreChatCompleted();

  Future<bool> _switchUser(CerqleUser? user) => _sessions.switchUser(user);

  Future<void> _clearSession() => _sessions.clear();

  CerqleStoredSession _requireSession() {
    _ensureOpen();
    return _sessions.requireSession();
  }

  void _ensureOpen() {
    if (_closed) {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'The Cerqle client is closed.',
        retryable: false,
      );
    }
  }

  /// Releases resources owned by this client.
  ///
  /// An injected HTTP client remains owned by the caller and is not closed.
  /// Calling this method repeatedly is safe.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sessions.disposeMemory();
    if (_ownsHttpClient) _httpClient.close();
  }
}
