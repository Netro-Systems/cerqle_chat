part of 'chat_widgets_test.dart';

void registerComposerHandoffTests(CerqleConfig config) {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        '$platform Microphone denial is silent until the next blocked tap',
        (tester) async {
      const settingsChannel =
          MethodChannel('com.spencerccf.app_settings/methods');
      const permissionChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      const recordChannel = MethodChannel('com.llfbandit.record/messages');
      var status = 0; // denied but requestable
      var requests = 0;
      var settingsOpens = 0;
      final denialCount = platform == TargetPlatform.iOS ? 1 : 2;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        settingsOpens++;
        return null;
      });
      messenger.setMockMethodCallHandler(permissionChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return status;
        if (call.method == 'requestPermissions') {
          requests++;
          status = requests >= denialCount ? 4 : 0;
          return <int, int>{(call.arguments as List).single as int: status};
        }
        throw StateError('Unexpected permission call: ${call.method}');
      });
      messenger.setMockMethodCallHandler(recordChannel, (call) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(settingsChannel, null);
        messenger.setMockMethodCallHandler(permissionChannel, null);
        messenger.setMockMethodCallHandler(recordChannel, null);
      });
      final runtime = _runtime(config, MockClient((request) async {
        return http.Response(
            jsonEncode(request.url.path.endsWith('/session')
                ? sessionResponse()
                : refreshResponse()),
            200);
      }));
      await tester.pumpWidget(
          _app(CerqleChatView(config: config, controller: runtime.controller)));
      await tester.pumpAndSettle();
      Future<void> tapMedia() async {
        await tester.tap(find.byTooltip('Record voice message'));
        await tester.pumpAndSettle();
      }

      for (var attempt = 0; attempt < denialCount; attempt++) {
        await tapMedia();
        expect(find.byType(SnackBar), findsNothing);
        expect(requests, attempt + 1);
        expect(find.bySemanticsLabel(RegExp('Recording voice message')),
            findsNothing);
      }
      await tapMedia();
      expect(
          find.text('Enable Microphone access in Settings.'), findsOneWidget);
      expect(requests, denialCount);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(settingsOpens, 1);
      // A Settings change must be checked afresh rather than cached.
      status = 0;
      await tapMedia();
      expect(requests, denialCount + 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.controller.dispose();
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('default composer picks images and records voice through adapter',
      (tester) async {
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = CerqleConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      enableOneSignal: false,
      mediaAdapter: mediaAdapter,
    );
    var uploadCount = 0;
    final uploadedContentTypes = <String>[];
    final uploadedBodies = <List<int>>[];
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          uploadedContentTypes.add(request.headers['content-type'] ?? '');
          uploadedBodies.add(request.bodyBytes);
          uploadCount++;
          final type = uploadCount == 1 ? 'image' : 'audio';
          return http.Response(
            jsonEncode(<String, Object?>{
              'message': message(
                id: uploadCount,
                role: 'visitor',
                type: type,
                body: type == 'image' ? 'Image attachment' : 'Voice message',
                sentBy: 'human',
              ),
              'handoff': <String, Object?>{
                'enabled': true,
                'eligible': false,
                'status': 'bot',
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode(refreshResponse()), 200);
      }),
    );

    await tester.pumpWidget(_app(
      CerqleChatView(
        config: mediaConfig,
        controller: runtime.controller,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Attach file'), findsOneWidget);
    expect(find.byTooltip('Record voice message'), findsOneWidget);

    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPickerSheet), findsOneWidget);
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.imagePicks, 1);
    final preview = find.byKey(
      const ValueKey<String>('cerqle-image-preview'),
    );
    expect(preview, findsOneWidget);

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(uploadCount, 1);
    expect(uploadedContentTypes.single, startsWith('multipart/form-data;'));
    final imageBody = utf8.decode(uploadedBodies.single, allowMalformed: true);
    expect(imageBody, contains('name="key"'));
    expect(imageBody, contains('test-widget'));
    expect(imageBody, contains('name="type"'));
    expect(imageBody, contains('image'));
    expect(imageBody, contains('name="attachment"; filename="photo.png"'));
    expect(preview, findsNothing);

    await tester.tap(find.byTooltip('Record voice message'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mediaAdapter.recordingStarts, 1);
    expect(
      find.bySemanticsLabel(RegExp('Recording voice message')),
      findsOneWidget,
    );
    expect(find.byTooltip('Send voice message'), findsOneWidget);
    expect(find.byTooltip('Cancel recording'), findsOneWidget);

    await tester.tap(find.byTooltip('Send voice message'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mediaAdapter.recordingStops, 1);
    expect(uploadCount, 2);
    expect(uploadedContentTypes.last, startsWith('multipart/form-data;'));
    final audioBody = utf8.decode(uploadedBodies.last, allowMalformed: true);
    expect(audioBody, contains('audio'));
    expect(audioBody, contains('name="attachment"; filename="voice.wav"'));
    expect(find.byTooltip('Send voice message'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('cerqle-audio-preview')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('eligible handoff uses the human-agent prompt and connects',
      (tester) async {
    var handoffCalls = 0;
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          final response = sessionResponse();
          response['handoff'] = <String, Object?>{
            'enabled': true,
            'eligible': true,
            'status': 'bot',
          };
          return http.Response(jsonEncode(response), 200);
        }
        if (request.url.path.endsWith('/handoff')) {
          handoffCalls++;
          return http.Response(
            jsonEncode(<String, Object?>{
              'handoff': <String, Object?>{
                'enabled': true,
                'eligible': false,
                'status': 'connected',
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode(refreshResponse()), 200);
      }),
    );

    await tester.pumpWidget(_app(
      CerqleChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Prefer a person?'), findsOneWidget);
    expect(find.text('Human Agent'), findsOneWidget);
    await tester.tap(find.text('Human Agent'));
    await tester.pumpAndSettle();

    expect(handoffCalls, 1);
    expect(find.text('Connected to a human agent'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('terminal server failure is actionable and hides composer',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient((_) async => http.Response('{}', 404)),
    );

    await tester.pumpWidget(_app(
      CerqleChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('The widget is missing or disabled.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('custom empty builder receives immutable ready state',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      CerqleChatView(
        config: config,
        controller: runtime.controller,
        emptyBuilder: (_, state) => Text('Custom ${state.phase.name}'),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Custom ready'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}
