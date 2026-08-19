part of '../cerqle_runtime.dart';

/// Coordinates session state, delivery, polling, typing, and handoff.
///
/// Listening to [states] or [events] acquires a synchronization lease. Polling
/// stops when no lease is active or the application is backgrounded. Call
/// [dispose] when finished.
class CerqleChatController with WidgetsBindingObserver {
  /// Creates a controller backed by [client].
  CerqleChatController({required CerqleClient client}) : _client = client {
    _statesController = StreamController<CerqleChatState>.broadcast(
      sync: true,
      onListen: () => _setStateLease(true),
      onCancel: () => _setStateLease(false),
    );
    _eventsController = StreamController<CerqleChatEvent>.broadcast(
      sync: true,
      onListen: () => _setEventLease(true),
      onCancel: () => _setEventLease(false),
    );
  }

  final CerqleClient _client;
  final MessageReconciler _messageReconciler = const MessageReconciler();
  final PollingCoordinator _pollingCoordinator = PollingCoordinator();
  final PreChatValidator _preChatValidator = const PreChatValidator();
  late final StreamController<CerqleChatState> _statesController;
  late final StreamController<CerqleChatEvent> _eventsController;
  final ChatStateMachine _stateMachine = ChatStateMachine();
  final WidgetOneSignalService _oneSignalService =
      WidgetOneSignalService.instance;
  Future<void>? _initializing;
  Future<void>? _pollInFlight;
  Future<void> _sendQueue = Future<void>.value();
  final Map<int, CerqleMessage> _deferredVisitorPollMessages =
      <int, CerqleMessage>{};
  Timer? _typingIdleTimer;
  DateTime? _lastTypingSentAt;
  DateTime _lastActivity = DateTime.now();
  int _pollCursor = 0;
  int? _conversationId;
  int _pollFailures = 0;
  int _sessionRevision = 0;
  Duration? _pollRetryAfter;
  CerqleRealtimeConfig? _realtimeConfig;
  bool _realtimeActive = false;
  bool _observingLifecycle = false;
  bool _disposed = false;
  bool _recoveryAttempted = false;
  String? _activeSendLocalId;

  /// Latest immutable state snapshot.
  CerqleChatState get state => _stateMachine.state;

  CerqleChatState get _state => _stateMachine.state;

  /// Broadcast state updates and a foreground polling lease.
  Stream<CerqleChatState> get states => _statesController.stream;

  /// Broadcast lifecycle and message events and a polling lease.
  Stream<CerqleChatEvent> get events => _eventsController.stream;

  /// Configuration owned by the backing client.
  CerqleConfig get config => _client.config;

  /// Resolves the current OneSignal Push Subscription ID if enabled.
  Future<String?> currentPushToken() => _oneSignalService.currentPushToken();

  /// Creates or restores the identity-scoped session.
  ///
  /// Concurrent calls share one initialization. The resulting phase is
  /// [CerqleChatPhase.ready], [CerqleChatPhase.awaitingPreChat], or
  /// [CerqleChatPhase.failure]. Throws a typed [CerqleException] when
  /// configuration, storage, transport, or response validation fails.
  Future<void> initialize() {
    _ensureNotDisposed();
    if (_state.phase == CerqleChatPhase.ready) {
      return Future<void>.value();
    }
    final active = _initializing;
    if (active != null) return active;
    final future = _initializeInternal();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) _initializing = null;
    });
  }

  Future<void> _initializeInternal() async {
    final started = DateTime.now();
    _observeLifecycle();
    _emit(
      _state.copyWith(
        phase: CerqleChatPhase.initializing,
        connection: CerqleConnectionState.connecting,
        error: null,
      ),
    );
    try {
      String? deviceId;
      if (config.enableOneSignal && config.oneSignalAppId.isNotEmpty) {
        await _oneSignalService.initialize(appId: config.oneSignalAppId);
        final activeExternalId = _client._activeUser?.externalId;
        if (activeExternalId != null && activeExternalId.isNotEmpty) {
          await _oneSignalService.login(activeExternalId);
        }
        deviceId = await _oneSignalService.currentPushToken();
      }

      final result = await _client._startSession(deviceId: deviceId);
      _validatePreChatFields(result.widget);
      final preChatSatisfied =
          result.session.preChatCompleted ||
          _activeUserSatisfiesPreChat(result.widget);
      if (result.widget.requiresPreChat && !preChatSatisfied) {
        _emit(
          _state.copyWith(
            phase: CerqleChatPhase.awaitingPreChat,
            messages: const <CerqleMessage>[],
            connection: CerqleConnectionState.connected,
            widget: result.widget,
            handoff: result.handoff,
            supportAvailability: result.supportAvailability,
            visitorTyping: false,
            agentTyping: null,
            pendingCount: 0,
            error: null,
          ),
        );
        _diagnostic(
          CerqleDiagnosticKind.initialization,
          duration: DateTime.now().difference(started),
        );
        return;
      }
      if (result.widget.requiresPreChat && !result.session.preChatCompleted) {
        await _client._markPreChatCompleted();
      }
      await _acceptSession(result);
      _diagnostic(
        CerqleDiagnosticKind.initialization,
        duration: DateTime.now().difference(started),
      );
    } on Object catch (error) {
      final exception = _asCerqleException(error);
      _emit(
        _state.copyWith(
          phase: CerqleChatPhase.failure,
          connection: CerqleConnectionState.disconnected,
          error: exception,
        ),
      );
      _diagnostic(
        CerqleDiagnosticKind.initialization,
        duration: DateTime.now().difference(started),
        exception: exception,
      );
      rethrow;
    }
  }

  Future<void> _acceptSession(WidgetSessionResult result) async {
    var messages = _mergeMessages(
      const <CerqleMessage>[],
      result.messages,
      emitReceivedEvents: false,
    );
    _pollCursor = _greatestServerId(result.messages, fallback: 0);
    var latestBatchLength = result.messages.length;
    var catchUpPages = 0;
    while (latestBatchLength == 100 && catchUpPages < 50) {
      final page = await _client._poll(_pollCursor);
      messages = _mergeMessages(
        messages,
        page.messages,
        emitReceivedEvents: false,
      );
      _pollCursor = _greatestServerId(page.messages, fallback: _pollCursor);
      latestBatchLength = page.messages.length;
      catchUpPages++;
    }

    _pollFailures = 0;
    _pollRetryAfter = null;
    _lastActivity = DateTime.now();
    _conversationId = result.conversationId;
    _realtimeConfig = result.widget.realtime;
    _emit(
      _state.copyWith(
        phase: CerqleChatPhase.ready,
        messages: messages,
        connection: CerqleConnectionState.connected,
        widget: result.widget,
        handoff: result.handoff,
        supportAvailability: result.supportAvailability,
        visitorTyping: false,
        agentTyping: null,
        pendingCount: _pendingCount(messages),
        error: null,
      ),
    );
    _addEvent(const CerqleSessionReady());
    unawaited(_syncRealtime());
    _schedulePoll();
  }

  /// Submits backend-required values using the token-bound session.
  ///
  /// Throws [CerqleException] for missing fields, unsupported backend
  /// requirements, or request failures. Submitted identity values are not
  /// persisted by the package.
  Future<void> submitPreChat(CerqlePreChatData data) async {
    _ensureNotDisposed();
    if (_state.phase != CerqleChatPhase.awaitingPreChat ||
        _state.widget == null) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Pre-chat information is not currently required.',
        retryable: false,
      );
    }
    final widget = _state.widget!;
    _validatePreChatSubmission(widget, data);
    _emit(_state.copyWith(connection: CerqleConnectionState.connecting));
    try {
      String? deviceId;
      if (config.enableOneSignal && config.oneSignalAppId.isNotEmpty) {
        deviceId = await _oneSignalService.currentPushToken();
      }
      final result = await _client._submitPreChat(
        CerqlePreChatData(name: data.name?.trim(), email: data.email?.trim()),
        deviceId: deviceId,
      );
      _validatePreChatFields(result.widget);
      await _acceptSession(result);
    } on Object catch (error) {
      final exception = _asCerqleException(error);
      _emit(
        _state.copyWith(
          phase: CerqleChatPhase.awaitingPreChat,
          connection: CerqleConnectionState.connected,
          error: exception,
        ),
      );
      rethrow;
    }
  }

  bool _activeUserSatisfiesPreChat(CerqleWidgetConfig widget) {
    return _preChatValidator.isSatisfiedBy(widget, _client._activeUser);
  }

  void _validatePreChatFields(CerqleWidgetConfig widget) {
    _preChatValidator.validateConfiguration(widget);
  }

  void _validatePreChatSubmission(
    CerqleWidgetConfig widget,
    CerqlePreChatData data,
  ) {
    _preChatValidator.validateSubmission(widget, data);
  }

  /// Performs one non-overlapping reconciliation poll immediately.
  ///
  /// Concurrent callers share the in-flight poll. A session-expired response
  /// permits one controlled restoration; other failures are exposed as typed
  /// [CerqleException] values and reflected in [state].
  Future<void> refresh() {
    _ensureNotDisposed();
    final active = _pollInFlight;
    if (active != null) return active;
    if (_state.phase != CerqleChatPhase.ready &&
        _state.phase != CerqleChatPhase.reconnecting) {
      return initialize();
    }
    final future = _refreshInternal(_sessionRevision);
    _pollInFlight = future;
    return future.whenComplete(() {
      if (identical(_pollInFlight, future)) _pollInFlight = null;
    });
  }

  Future<void> _refreshInternal(int revision) async {
    _cancelPoll();
    try {
      final result = await _client._poll(_pollCursor);
      if (_disposed || revision != _sessionRevision) return;
      final messages = _mergePollMessages(
        _state.messages,
        result.messages,
        emitReceivedEvents: true,
      );
      // Only authoritative session/poll batches advance the receive cursor.
      // A send response can have a newer ID than an unseen incoming reply.
      _pollCursor = _greatestServerId(result.messages, fallback: _pollCursor);
      if (result.messages.isNotEmpty) _lastActivity = DateTime.now();
      _pollFailures = 0;
      _pollRetryAfter = null;
      _recoveryAttempted = false;
      _emit(
        _state.copyWith(
          phase: CerqleChatPhase.ready,
          messages: messages,
          connection: CerqleConnectionState.connected,
          handoff: result.handoff,
          supportAvailability: result.supportAvailability,
          agentTyping: result.agentTyping,
          pendingCount: _pendingCount(messages),
          error: null,
        ),
      );
      _pollingCoordinator.updateAgentTyping(
        active: result.agentTyping != null,
        onExpired: _expireAgentTyping,
      );
      _diagnostic(CerqleDiagnosticKind.poll);
      if (result.messages.length == 100) {
        await _refreshInternal(revision);
        return;
      }
    } on CerqleException catch (exception) {
      if (_disposed || revision != _sessionRevision) return;
      if ((exception.code == CerqleErrorCode.sessionExpired ||
              exception.code == CerqleErrorCode.unauthorized) &&
          !_recoveryAttempted) {
        _recoveryAttempted = true;
        _emit(
          _state.copyWith(
            phase: CerqleChatPhase.expired,
            connection: CerqleConnectionState.disconnected,
            error: exception,
          ),
        );
        await _client._clearSession();
        await _initializeInternal();
        return;
      }
      _pollFailures++;
      _pollRetryAfter = exception.retryAfter;
      _emit(
        _state.copyWith(
          phase: !exception.retryable
              ? CerqleChatPhase.failure
              : CerqleChatPhase.reconnecting,
          connection: !exception.retryable
              ? CerqleConnectionState.disconnected
              : CerqleConnectionState.reconnecting,
          error: exception,
        ),
      );
      _diagnostic(CerqleDiagnosticKind.poll, exception: exception);
      rethrow;
    } finally {
      if (revision == _sessionRevision) _schedulePoll();
    }
  }

  /// Sends trimmed text and returns its latest delivery representation.
  ///
  /// Ambiguous outcomes remain unconfirmed and are not retried automatically.
  /// Throws [CerqleException] for empty text, invalid lifecycle state, or
  /// delivery failures; the corresponding local message remains in [state].
  Future<CerqleMessage> sendText(String text) {
    final body = text.trim();
    if (body.isEmpty || body.length > 4000) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Messages must contain between 1 and 4,000 characters.',
        retryable: false,
      );
    }
    return _enqueueSend(() => _sendTextInternal(body));
  }

  Future<CerqleMessage> _sendTextInternal(
    String text, {
    String? existingLocalId,
  }) async {
    _ensureReady();
    final pending = CerqleMessage(
      localId: existingLocalId ?? _newLocalId(),
      role: CerqleMessageRole.visitor,
      type: CerqleMessageType.text,
      body: text,
      status: CerqleMessageStatus.pending,
      createdAt: DateTime.now(),
      sentBy: CerqleSenderKind.visitor,
    );
    _upsertLocal(pending);
    unawaited(setTyping(false).catchError((_) {}));
    return _performSend(pending, () => _client._sendText(text));
  }

  /// Uploads an image with an optional text [caption].
  ///
  /// Throws [CerqleException] when the controller is not ready or the
  /// attachment is rejected or cannot be delivered.
  Future<CerqleMessage> sendImage(CerqleUpload upload, {String? caption}) =>
      _enqueueSend(
        () => _sendUploadInternal(
          upload,
          CerqleMessageType.image,
          caption?.trim(),
        ),
      );

  /// Uploads audio with an optional text [caption].
  ///
  /// Throws [CerqleException] when the controller is not ready or the
  /// attachment is rejected or cannot be delivered.
  Future<CerqleMessage> sendAudio(CerqleUpload upload, {String? caption}) =>
      _enqueueSend(
        () => _sendUploadInternal(
          upload,
          CerqleMessageType.audio,
          caption?.trim(),
        ),
      );

  /// Loads protected attachment bytes through the active widget session.
  Future<Uint8List> loadAttachmentBytes(CerqleAttachment attachment) {
    _ensureReady();
    return _client._loadAttachmentBytes(attachment);
  }

  Future<CerqleMessage> _sendUploadInternal(
    CerqleUpload upload,
    CerqleMessageType type,
    String? caption,
  ) async {
    _ensureReady();
    final pending = CerqleMessage(
      localId: _newLocalId(),
      role: CerqleMessageRole.visitor,
      type: type,
      body: caption?.isNotEmpty == true
          ? caption!
          : type == CerqleMessageType.image
          ? 'Image attachment'
          : 'Voice message',
      status: CerqleMessageStatus.pending,
      createdAt: DateTime.now(),
      localUpload: upload,
      sentBy: CerqleSenderKind.visitor,
    );
    _upsertLocal(pending);
    return _performSend(
      pending,
      () => _client._sendUpload(upload, type, caption),
    );
  }

  Future<CerqleMessage> _performSend(
    CerqleMessage pending,
    Future<WidgetSendResult> Function() operation,
  ) async {
    final started = DateTime.now();
    _activeSendLocalId = pending.localId;
    try {
      final result = await operation();
      final confirmed = result.message.copyWith(
        localId: pending.localId,
        status: CerqleMessageStatus.sent,
        localUpload: pending.localUpload,
        clearError: true,
      );
      _replaceLocal(pending.localId, confirmed);
      _updateHandoff(result.handoff);
      _lastActivity = DateTime.now();
      _addEvent(CerqleMessageSent(message: confirmed));
      _diagnostic(
        CerqleDiagnosticKind.send,
        duration: DateTime.now().difference(started),
      );
      return confirmed;
    } on Object catch (error) {
      final exception = _asCerqleException(error);
      // The backend may have stored a request before the connection failed.
      // Without an idempotency key, retrying or declaring failure can duplicate
      // a visitor message or misrepresent its delivery state.
      final ambiguous =
          exception.code == CerqleErrorCode.network ||
          exception.code == CerqleErrorCode.server;
      final failed = pending.copyWith(
        status: ambiguous
            ? CerqleMessageStatus.unconfirmed
            : CerqleMessageStatus.failed,
        error: exception,
      );
      _replaceLocal(pending.localId, failed);
      _diagnostic(
        CerqleDiagnosticKind.send,
        duration: DateTime.now().difference(started),
        exception: exception,
      );
      if (exception.code == CerqleErrorCode.sessionExpired ||
          exception.code == CerqleErrorCode.unauthorized) {
        unawaited(_recoverAfterSend());
      }
      throw exception;
    } finally {
      if (_activeSendLocalId == pending.localId) {
        _activeSendLocalId = null;
        _flushDeferredVisitorPollMessages();
      }
    }
  }

  Future<void> _recoverAfterSend() async {
    if (_recoveryAttempted || _disposed) return;
    _recoveryAttempted = true;
    _emit(
      _state.copyWith(
        phase: CerqleChatPhase.expired,
        connection: CerqleConnectionState.disconnected,
      ),
    );
    try {
      await _client._clearSession();
      await _initializeInternal();
    } on Object {
      // The state emitted by initialization remains authoritative.
    }
  }

  /// Retries a definitively failed, retryable message identified by [localId].
  ///
  /// Unconfirmed messages cannot be retried because the first request may have
  /// reached the server. Throws [CerqleException] when retry is unsafe.
  Future<CerqleMessage> retryMessage(String localId) {
    final message = _findLocal(localId);
    if (message.status != CerqleMessageStatus.failed ||
        message.error?.retryable != true ||
        message.type != CerqleMessageType.text) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'This message cannot be retried safely.',
        retryable: false,
      );
    }
    return _enqueueSend(
      () => _sendTextInternal(message.body, existingLocalId: localId),
    );
  }

  /// Removes a failed or unconfirmed local message from visible state.
  ///
  /// Throws [CerqleException] when [localId] identifies a pending or sent
  /// message whose removal would misrepresent delivery state.
  Future<void> removeMessage(String localId) async {
    final message = _findLocal(localId);
    if (message.status != CerqleMessageStatus.failed &&
        message.status != CerqleMessageStatus.unconfirmed) {
      throw const CerqleException(
        code: CerqleErrorCode.validation,
        message: 'Only failed or unconfirmed messages can be removed.',
        retryable: false,
      );
    }
    final messages = _state.messages
        .where((item) => item.localId != localId)
        .toList();
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  /// Publishes throttled visitor typing state when enabled and ready.
  Future<void> setTyping(bool isTyping) async {
    if (!_client.config.enableTyping || _state.phase != CerqleChatPhase.ready) {
      return;
    }
    _typingIdleTimer?.cancel();
    if (isTyping) {
      _emit(_state.copyWith(visitorTyping: true));
      _typingIdleTimer = Timer(const Duration(seconds: 4), () {
        unawaited(setTyping(false).catchError((_) {}));
      });
      final now = DateTime.now();
      if (_lastTypingSentAt != null &&
          now.difference(_lastTypingSentAt!) < const Duration(seconds: 2)) {
        return;
      }
      _lastTypingSentAt = now;
    } else {
      if (!_state.visitorTyping) return;
      _emit(_state.copyWith(visitorTyping: false));
    }
    try {
      await _client._setTyping(isTyping);
    } on Object {
      if (!isTyping) _emit(_state.copyWith(visitorTyping: false));
    }
  }

  /// Requests human support when the backend reports handoff eligibility.
  ///
  /// Throws [CerqleException] when handoff is unavailable or the request
  /// fails; [state] retains the corresponding failed handoff status.
  Future<void> requestHumanAgent() async {
    _ensureReady();
    if (_state.handoff.status != CerqleHandoffStatus.eligible) {
      throw const CerqleException(
        code: CerqleErrorCode.unsupported,
        message: 'Human handoff is not available.',
        retryable: false,
      );
    }
    _updateHandoff(
      const CerqleHandoffState(status: CerqleHandoffStatus.requesting),
    );
    try {
      _updateHandoff(await _client._requestHandoff());
    } on Object catch (error) {
      final exception = _asCerqleException(error);
      _updateHandoff(
        CerqleHandoffState(
          status: CerqleHandoffStatus.failed,
          error: exception,
        ),
      );
      throw exception;
    }
  }

  /// Switches identity before restoring that identity's isolated session.
  ///
  /// The previous identity's token is never reused for [user]. Throws a typed
  /// [CerqleException] when validation, storage, or initialization fails.
  /// Passing `null` is treated as host-application logout: polling and typing
  /// stop, credentials and in-memory messages are cleared, and no anonymous
  /// session is created until [initialize] is called again.
  Future<void> updateUser(CerqleUser? user) async {
    _ensureNotDisposed();
    _cancelPoll();
    _sessionRevision++;
    if (_realtimeActive) {
      await _client._stopRealtime();
      _realtimeActive = false;
    }
    _conversationId = null;
    _realtimeConfig = null;
    if (user == null) {
      await _stopTypingBestEffort();
      await _oneSignalService.logout();
    } else if (user.externalId != null && user.externalId!.isNotEmpty) {
      await _oneSignalService.login(user.externalId!);
    }
    final changed = await _client._switchUser(user);
    if (!changed) return;
    _deferredVisitorPollMessages.clear();
    _pollCursor = 0;
    _recoveryAttempted = false;
    _emit(CerqleChatState.initial());
    if (user == null) return;
    _emit(
      _state.copyWith(
        phase: CerqleChatPhase.initializing,
        connection: CerqleConnectionState.connecting,
      ),
    );
    await initialize();
  }

  /// Deletes active credentials and initializes a fresh session.
  ///
  /// A fresh session is created immediately only while a stream listener holds
  /// a synchronization lease. Storage failures surface as [CerqleException].
  Future<void> resetSession() async {
    _ensureNotDisposed();
    _cancelPoll();
    _sessionRevision++;
    if (_realtimeActive) {
      await _client._stopRealtime();
      _realtimeActive = false;
    }
    _conversationId = null;
    _realtimeConfig = null;
    await _stopTypingBestEffort();
    await _oneSignalService.logout();
    await _client._clearSession();
    _deferredVisitorPollMessages.clear();
    _pollCursor = 0;
    _recoveryAttempted = false;
    _addEvent(
      const CerqleChatClosed(reason: CerqleChatCloseReason.sessionReset),
    );
    _emit(CerqleChatState.initial());
    if (_hasLease) await initialize();
  }

  Future<void> _stopTypingBestEffort() async {
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
    _lastTypingSentAt = null;
    if (_state.phase != CerqleChatPhase.ready &&
        _state.phase != CerqleChatPhase.reconnecting) {
      return;
    }
    if (_state.visitorTyping) {
      _emit(_state.copyWith(visitorTyping: false));
    }
    try {
      await _client._setTyping(false);
    } on Object {
      // Logout/reset must continue even when the best-effort typing update
      // cannot reach the server.
    }
  }

  @internal
  /// Records that a prebuilt chat presentation opened.
  void handlePresentationOpened() {
    _addEvent(const CerqleChatOpened());
  }

  @internal
  /// Records that a prebuilt presentation closed for [reason].
  void handlePresentationClosed(CerqleChatCloseReason reason) {
    _addEvent(CerqleChatClosed(reason: reason));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _pollingCoordinator.updateLifecycle(state);
    _diagnostic(CerqleDiagnosticKind.lifecycle);
    if (_pollingCoordinator.isForeground) {
      unawaited(_syncRealtime());
      if (_hasLease && _state.phase == CerqleChatPhase.ready) {
        unawaited(refresh().catchError((_) {}));
      }
    } else {
      _typingIdleTimer?.cancel();
      if (_realtimeActive) {
        unawaited(_client._stopRealtime());
        _realtimeActive = false;
      }
    }
  }

  /// Stops timers/lifecycle observation and closes state/event streams.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_realtimeActive) {
      await _client._stopRealtime();
      _realtimeActive = false;
    }
    _pollingCoordinator.dispose();
    _typingIdleTimer?.cancel();
    _deferredVisitorPollMessages.clear();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _stateMachine.replace(
      _state.copyWith(
        phase: CerqleChatPhase.disposed,
        connection: CerqleConnectionState.disconnected,
        visitorTyping: false,
        agentTyping: null,
      ),
    );
    if (!_statesController.isClosed) _statesController.add(_state);
    await _statesController.close();
    await _eventsController.close();
  }

  void _setStateLease(bool active) {
    if (_pollingCoordinator.setStateLease(active)) _leaseChanged();
  }

  void _setEventLease(bool active) {
    if (_pollingCoordinator.setEventLease(active)) _leaseChanged();
  }

  bool get _hasLease => _pollingCoordinator.hasLease;

  void _leaseChanged() {
    if (_disposed) return;
    // Poll only while someone consumes state/events. This keeps headless and
    // hidden integrations from spending network and battery in the background.
    unawaited(_syncRealtime());
    _schedulePoll();
  }

  void _schedulePoll() {
    _pollingCoordinator.schedule(
      phase: _state.phase,
      config: _client.config.polling,
      failures: _pollFailures,
      retryAfter: _pollRetryAfter,
      lastActivity: _lastActivity,
      now: DateTime.now(),
      poll: () => refresh().catchError((_) {}),
    );
  }

  void _cancelPoll() => _pollingCoordinator.cancelPoll();

  void _expireAgentTyping() {
    if (_disposed || _state.agentTyping == null) return;
    _emit(_state.copyWith(agentTyping: null));
  }

  Future<void> _syncRealtime() async {
    if (_disposed ||
        !_hasLease ||
        !_pollingCoordinator.isForeground ||
        _state.phase != CerqleChatPhase.ready ||
        _conversationId == null ||
        _conversationId == 0 ||
        _realtimeConfig == null ||
        !_realtimeConfig!.isEnabled) {
      if (_realtimeActive) {
        await _client._stopRealtime();
        _realtimeActive = false;
      }
      return;
    }

    await _client._startRealtime(
      realtime: _realtimeConfig!,
      conversationId: _conversationId!,
      onConnected: () {
        if (!_disposed && _state.phase == CerqleChatPhase.ready) {
          unawaited(refresh().catchError((_) {}));
        }
      },
      onMessageCreated: _handleRealtimeMessageCreated,
      onTypingChanged: _handleRealtimeTypingChanged,
      onHandoffUpdated: _handleRealtimeHandoffUpdated,
      onError: (error, _) {
        _diagnostic(
          CerqleDiagnosticKind.connection,
          exception: _asCerqleException(error),
        );
      },
    );
    _realtimeActive = true;
  }

  void _handleRealtimeMessageCreated(Object? payload) {
    final message = const WidgetResponseDecoder().realtimeMessage(payload);
    if (message == null) return;
    final messages = _mergePollMessages(
      _state.messages,
      <CerqleMessage>[message],
      emitReceivedEvents: true,
    );
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  void _handleRealtimeTypingChanged(Object? payload) {
    final typing = const WidgetResponseDecoder().realtimeTyping(payload);
    _emit(_state.copyWith(agentTyping: typing));
    _pollingCoordinator.updateAgentTyping(
      active: typing != null,
      onExpired: _expireAgentTyping,
    );
  }

  void _handleRealtimeHandoffUpdated(Object? payload) {
    final handoff = const WidgetResponseDecoder().realtimeHandoff(payload);
    if (handoff == null) return;
    _updateHandoff(handoff);
  }

  void _observeLifecycle() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  Future<T> _enqueueSend<T>(Future<T> Function() operation) {
    _ensureNotDisposed();
    final completer = Completer<T>();
    _sendQueue = _sendQueue.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  List<CerqleMessage> _mergeMessages(
    List<CerqleMessage> existing,
    List<CerqleMessage> incoming, {
    required bool emitReceivedEvents,
  }) => _messageReconciler.merge(
    existing,
    incoming,
    onNewAgentMessage: emitReceivedEvents
        ? (message) => _addEvent(CerqleMessageReceived(message: message))
        : null,
  );

  List<CerqleMessage> _mergePollMessages(
    List<CerqleMessage> existing,
    List<CerqleMessage> incoming, {
    required bool emitReceivedEvents,
  }) {
    if (_activeSendLocalId == null) {
      return _mergeMessages(
        existing,
        incoming,
        emitReceivedEvents: emitReceivedEvents,
      );
    }

    final knownServerIds = existing
        .map((message) => message.serverId)
        .whereType<int>()
        .toSet();
    final immediate = <CerqleMessage>[];
    for (final message in incoming) {
      final serverId = message.serverId;
      // A poll can observe the server echo before the matching send completes.
      // Delay only that visitor echo so request ownership—not body/time
      // similarity—reconciles the pending local message first.
      if (message.role == CerqleMessageRole.visitor &&
          serverId != null &&
          !knownServerIds.contains(serverId)) {
        _deferredVisitorPollMessages[serverId] = message;
      } else {
        immediate.add(message);
      }
    }
    return _mergeMessages(
      existing,
      immediate,
      emitReceivedEvents: emitReceivedEvents,
    );
  }

  void _flushDeferredVisitorPollMessages() {
    if (_deferredVisitorPollMessages.isEmpty) return;
    final deferred = _deferredVisitorPollMessages.values.toList();
    _deferredVisitorPollMessages.clear();
    final messages = _mergeMessages(
      _state.messages,
      deferred,
      emitReceivedEvents: false,
    );
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  int _greatestServerId(
    List<CerqleMessage> messages, {
    required int fallback,
  }) => _messageReconciler.greatestServerId(messages, fallback: fallback);

  int _compareMessages(CerqleMessage a, CerqleMessage b) =>
      _messageReconciler.compare(a, b);

  void _upsertLocal(CerqleMessage message) {
    final messages = <CerqleMessage>[..._state.messages];
    final index = messages.indexWhere(
      (item) => item.localId == message.localId,
    );
    if (index == -1) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
    messages.sort(_compareMessages);
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  void _replaceLocal(String localId, CerqleMessage replacement) {
    final messages = <CerqleMessage>[];
    final replacementServerId = replacement.serverId;
    var replaced = false;
    for (final message in _state.messages) {
      if (message.localId == localId) {
        if (!replaced) {
          messages.add(replacement);
          replaced = true;
        }
        continue;
      }
      if (replacementServerId != null &&
          message.serverId == replacementServerId) {
        continue;
      }
      messages.add(message);
    }
    if (!replaced) messages.add(replacement);
    messages.sort(_compareMessages);
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  CerqleMessage _findLocal(String localId) {
    for (final message in _state.messages) {
      if (message.localId == localId) return message;
    }
    throw const CerqleException(
      code: CerqleErrorCode.validation,
      message: 'The local message no longer exists.',
      retryable: false,
    );
  }

  int _pendingCount(List<CerqleMessage> messages) => messages
      .where((message) => message.status == CerqleMessageStatus.pending)
      .length;

  void _updateHandoff(CerqleHandoffState handoff) {
    if (_state.handoff.status == handoff.status &&
        _state.handoff.error == handoff.error) {
      return;
    }
    _emit(_state.copyWith(handoff: handoff));
    _addEvent(CerqleHandoffChanged(handoff: handoff));
  }

  void _emit(CerqleChatState next) {
    if (_disposed) return;
    final connectionChanged = next.connection != _state.connection;
    _stateMachine.replace(next);
    if (!_statesController.isClosed) _statesController.add(next);
    if (connectionChanged) {
      _addEvent(CerqleConnectionChanged(connection: next.connection));
      _diagnostic(CerqleDiagnosticKind.connection);
    }
  }

  void _addEvent(CerqleChatEvent event) {
    if (!_disposed && !_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  void _diagnostic(
    CerqleDiagnosticKind kind, {
    Duration? duration,
    CerqleException? exception,
  }) {
    final callback = _client.config.diagnostics;
    if (callback == null) return;
    try {
      callback(
        CerqleDiagnosticEvent(
          kind: kind,
          occurredAt: DateTime.now().toUtc(),
          duration: duration,
          httpStatus: exception?.httpStatus,
          errorCode: exception?.code,
        ),
      );
    } on Object {
      // Diagnostics must never alter chat behavior.
    }
  }

  void _ensureReady() {
    _ensureNotDisposed();
    if (_state.phase != CerqleChatPhase.ready &&
        _state.phase != CerqleChatPhase.reconnecting) {
      throw const CerqleException(
        code: CerqleErrorCode.unauthorized,
        message: 'Chat is not ready to send a message.',
        retryable: true,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'The chat controller is disposed.',
        retryable: false,
      );
    }
  }

  String _newLocalId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
}

CerqleException _asCerqleException(Object error) => error is CerqleException
    ? error
    : const CerqleException(
        code: CerqleErrorCode.unknown,
        message: 'The chat operation could not be completed.',
        retryable: false,
      );
