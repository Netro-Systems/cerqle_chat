part of 'chat_widgets_test.dart';

void registerPresentationLayoutTests(CerqleConfig config) {
  testWidgets('full-screen chat can use light status-bar icons',
      (tester) async {
    const lightStatusConfig = CerqleConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      enableOneSignal: false,
      lightStatusBarIcons: true,
    );
    final runtime = _runtime(
      lightStatusConfig,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(CerqleChatScreen(
      config: lightStatusConfig,
      controller: runtime.controller,
    )));
    await tester.pump();

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(CerqleChatScreen),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(overlay.value.statusBarBrightness, Brightness.dark);
    expect(overlay.value.statusBarColor, Colors.transparent);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('full-screen chat defaults to dark status-bar icons',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(CerqleChatScreen(
      config: config,
      controller: runtime.controller,
    )));
    await tester.pump();

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(CerqleChatScreen),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
    expect(overlay.value.statusBarBrightness, Brightness.light);
    expect(overlay.value.statusBarColor, Colors.transparent);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('composer shares a row and expands on focus', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
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
      _app(
        CerqleChatView(
          config: config,
          controller: runtime.controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final field = find.byType(TextField);
    final attachment = find.byTooltip('Attach file');
    final send = find.byTooltip('Send message');
    final compactSize = tester.getSize(field);
    expect(compactSize.height, closeTo(42, 1));
    expect(tester.getSize(send).height, 42);
    final sendTargets =
        find.ancestor(of: send, matching: find.byType(SizedBox));
    expect(
      sendTargets.evaluate().any(
            (element) =>
                element.renderObject is RenderBox &&
                (element.renderObject! as RenderBox).size ==
                    const Size.square(48),
          ),
      isTrue,
    );
    expect(tester.getCenter(attachment).dy,
        closeTo(tester.getCenter(field).dy, 1));
    expect(tester.getCenter(send).dy, closeTo(tester.getCenter(field).dy, 3));

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.getSize(field).width, greaterThan(compactSize.width));
    expect(tester.getSize(field).height, closeTo(compactSize.height, 1));
    await tester.enterText(field, 'First line\nSecond line\nThird line');
    await tester.pumpAndSettle();
    expect(tester.getSize(field).height, greaterThan(compactSize.height));
    expect(tester.takeException(), isNull);

    final focusNode = tester.widget<TextField>(field).focusNode!;
    focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(field).width, closeTo(compactSize.width, 1));
    expect(
      tester.widget<TextField>(field).controller!.text,
      'First line\nSecond line\nThird line',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

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
      enableOneSignal: false,
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
      enableOneSignal: false,
      theme: CerqleThemeData(primaryColor: Color(0xFF087F5B)),
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
