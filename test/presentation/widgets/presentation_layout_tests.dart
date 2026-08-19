part of 'chat_widgets_test.dart';

void registerPresentationLayoutTests(CerqleConfig config) {
  testWidgets('full-screen integration renders a title and embedded body',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      CerqleChatScreen(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Test support'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final header = tester.widget<Material>(
      find.byKey(const ValueKey<String>('cerqle-chat-header')),
    );
    expect(
      header.color,
      const Color(0xFF6258F9),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('built-in brand colors ignore API and host primary colors',
      (tester) async {
    const brandConfig = CerqleConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      useApiColors: false,
      polling: CerqlePollingConfig(
        visibleInterval: Duration(minutes: 1),
        idleInterval: Duration(minutes: 1),
        failureMaxInterval: Duration(minutes: 1),
      ),
    );
    final runtime = _runtime(
      brandConfig,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      Stack(
        children: <Widget>[
          CerqleChatView(
            config: brandConfig,
            controller: runtime.controller,
          ),
          CerqleChatLauncher(
            config: brandConfig,
            controller: runtime.controller,
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump();

    final header = tester.widget<Material>(
      find.byKey(const ValueKey<String>('cerqle-chat-header')),
    );
    expect(header.color, const Color(0xFF3E2A49));
    final canvases = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(
      canvases.any((canvas) => canvas.color == const Color(0xFFF8FAFC)),
      isTrue,
    );
    final launcher = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(launcher.backgroundColor, const Color(0xFF3E2A49));

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('branded header honors theme override and close action',
      (tester) async {
    const themedConfig = CerqleConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      useApiColors: false,
      theme: CerqleThemeData(primaryColor: Color(0xFF087F5B)),
      polling: CerqlePollingConfig(
        visibleInterval: Duration(minutes: 1),
        idleInterval: Duration(minutes: 1),
        failureMaxInterval: Duration(minutes: 1),
      ),
    );
    final runtime = _runtime(
      themedConfig,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );
    var closeCalls = 0;

    await tester.pumpWidget(_app(
      CerqleChatView(
        config: themedConfig,
        controller: runtime.controller,
        onClose: () => closeCalls++,
      ),
    ));
    await tester.pump();
    await tester.pump();

    final header = tester.widget<Material>(
      find.byKey(const ValueKey<String>('cerqle-chat-header')),
    );
    expect(header.color, const Color(0xFF087F5B));
    expect(find.text('Test support'), findsOneWidget);
    expect(find.byTooltip('Close chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Close chat'));
    expect(closeCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('custom full-screen app bar remains host-owned', (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      CerqleChatScreen(
        config: config,
        controller: runtime.controller,
        appBar: AppBar(title: const Text('Host support title')),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Host support title'), findsOneWidget);
    expect(find.text('Test support'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('bottom sheet tracks keyboard and restores its safe height',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => unawaited(
            CerqleChat.open(
              context,
              config: config,
              controller: runtime.controller,
              presentation: CerqlePresentation.bottomSheet,
            ),
          ),
          child: const Text('Open bottom sheet'),
        ),
      ),
    ));

    await tester.tap(find.text('Open bottom sheet'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(
      const ValueKey<String>('cerqle-bottom-sheet'),
    );
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, closeTo(768, 0.1));
    expect(find.byType(TextField), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(tester.getSize(sheet).height, closeTo(480, 0.1));
    expect(
      tester.getBottomRight(find.byType(TextField)).dy,
      lessThanOrEqualTo(500),
    );

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(tester.getSize(sheet).height, closeTo(768, 0.1));
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Close chat'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('default layout fits a small phone at 200 percent text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: CerqleChatView(
          config: config,
          controller: runtime.controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Test support'), findsOneWidget);
    expect(find.text('Powered by Cerqle'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}
