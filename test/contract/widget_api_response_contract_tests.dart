part of 'widget_api_contract_test.dart';

void _registerResponseContractTests() {
  group('backend response contract', () {
    test('preserves every backend sender kind', () async {
      final response = sessionResponse(messages: <Map<String, Object?>>[
        message(id: 1, sentBy: 'bot'),
        message(id: 2, sentBy: 'human'),
        message(id: 3, sentBy: 'automation'),
        message(id: 4, sentBy: 'broadcast'),
      ]);
      final api = _remoteDataSource(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient((_) async => _jsonResponse(response)),
      );

      final result = await api.startSession(
        widgetKey: 'test-widget',
        user: null,
        storedSession: null,
      );

      expect(
        result.messages.map((item) => item.sentBy),
        <CerqleSenderKind>[
          CerqleSenderKind.bot,
          CerqleSenderKind.human,
          CerqleSenderKind.automation,
          CerqleSenderKind.broadcast,
        ],
      );
    });

    test('rejects malformed required message fields', () async {
      final response = sessionResponse(messages: <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'role': 'agent',
          'type': 'text',
          'body': 'Missing timestamp',
        },
      ]);
      final api = _remoteDataSource(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient((_) async => _jsonResponse(response)),
      );

      await expectLater(
        api.startSession(
          widgetKey: 'test-widget',
          user: null,
          storedSession: null,
        ),
        throwsA(
          isA<CerqleException>().having(
            (error) => error.code,
            'code',
            CerqleErrorCode.server,
          ),
        ),
      );
    });

    test('requires a positive numeric server id for send confirmation',
        () async {
      Future<CerqleException> sendFailure(Object? id) async {
        final api = _remoteDataSource(
          baseUrl: Uri.parse('https://chat.example.com'),
          httpClient: _RecordingClient(
            (_) async => _jsonResponse(<String, Object?>{
              'message': message(id: 7)..['id'] = id,
              'handoff': <String, Object?>{
                'enabled': true,
                'eligible': false,
                'status': 'bot',
              },
            }),
          ),
        );
        try {
          await api.sendText(
            widgetKey: 'test-widget',
            token: 'token-1',
            text: 'Hello',
          );
        } on CerqleException catch (error) {
          return error;
        }
        throw StateError('Expected malformed send response to fail.');
      }

      for (final id in <Object?>[null, '7', 0, -1]) {
        final error = await sendFailure(id);
        expect(error.code, CerqleErrorCode.server);
        expect(error.retryable, isFalse);
      }
    });

    test('rejects absent authoritative session and poll state', () async {
      final malformedSession = sessionResponse()..remove('handoff');
      final sessionApi = _remoteDataSource(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient(
          (_) async => _jsonResponse(malformedSession),
        ),
      );
      await expectLater(
        sessionApi.startSession(
          widgetKey: 'test-widget',
          user: null,
          storedSession: null,
        ),
        throwsA(
          isA<CerqleException>().having(
            (error) => error.code,
            'code',
            CerqleErrorCode.server,
          ),
        ),
      );

      final malformedPoll = pollResponse()..remove('messages');
      final pollApi = _remoteDataSource(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient(
          (_) async => _jsonResponse(malformedPoll),
        ),
      );
      await expectLater(
        pollApi.poll(
          widgetKey: 'test-widget',
          token: 'token-1',
          after: 0,
        ),
        throwsA(
          isA<CerqleException>().having(
            (error) => error.code,
            'code',
            CerqleErrorCode.server,
          ),
        ),
      );
    });

    test('keeps unknown message enums safe and parses poll state', () async {
      final api = _remoteDataSource(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient(
          (_) async => _jsonResponse(<String, Object?>{
            ...pollResponse(),
            'online': false,
            'agent_typing': <String, Object?>{
              'is_typing': true,
              'name': 'Taylor',
            },
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': false,
              'status': 'future_status',
            },
            'messages': <Map<String, Object?>>[
              message(
                id: 9,
                role: 'future_role',
                type: 'future_type',
                sentBy: 'future_sender',
              ),
            ],
            'future_field': 'ignored',
          }),
        ),
      );

      final result = await api.poll(
        widgetKey: 'test-widget',
        token: 'token-1',
        after: 0,
      );

      expect(
        result.supportAvailability,
        CerqleSupportAvailability.unavailable,
      );
      expect(result.agentTyping, isNotNull);
      expect(result.handoff.status, CerqleHandoffStatus.unavailable);
      expect(result.messages.single.role, CerqleMessageRole.unknown);
      expect(result.messages.single.type, CerqleMessageType.unknown);
      expect(result.messages.single.sentBy, CerqleSenderKind.unknown);
    });

    test('maps operation-aware HTTP failures and Retry-After', () async {
      Future<CerqleException> sessionFailure(int status) async {
        final api = _remoteDataSource(
          baseUrl: Uri.parse('https://chat.example.com'),
          httpClient: _RecordingClient(
            (_) async => _jsonResponse(<String, Object?>{}, status: status),
          ),
        );
        try {
          await api.startSession(
            widgetKey: 'test-widget',
            user: null,
            storedSession: null,
          );
        } on CerqleException catch (error) {
          return error;
        }
        throw StateError('Expected session request to fail.');
      }

      final missingWidget = await sessionFailure(404);
      expect(missingWidget.code, CerqleErrorCode.configuration);
      expect(missingWidget.retryable, isFalse);

      final forbidden = await sessionFailure(403);
      expect(forbidden.code, CerqleErrorCode.forbidden);

      final expired = await sessionFailure(401);
      expect(expired.code, CerqleErrorCode.sessionExpired);
      expect(expired.retryable, isFalse);

      final authenticatedApi = _remoteDataSource(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient((request) async {
          if (request.url.queryParameters['after'] == '1') {
            return http.StreamedResponse(
              Stream<List<int>>.value(utf8.encode('{}')),
              429,
              headers: <String, String>{
                'content-type': 'application/json',
                'retry-after': '17',
              },
            );
          }
          return _jsonResponse(<String, Object?>{}, status: 404);
        }),
      );

      await expectLater(
        authenticatedApi.poll(
          widgetKey: 'test-widget',
          token: 'token-1',
          after: 0,
        ),
        throwsA(
          isA<CerqleException>()
              .having(
                (error) => error.code,
                'code',
                CerqleErrorCode.sessionExpired,
              )
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
      await expectLater(
        authenticatedApi.poll(
          widgetKey: 'test-widget',
          token: 'token-1',
          after: 1,
        ),
        throwsA(
          isA<CerqleException>()
              .having(
                (error) => error.code,
                'code',
                CerqleErrorCode.rateLimited,
              )
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 17),
              ),
        ),
      );
    });
  });
}
