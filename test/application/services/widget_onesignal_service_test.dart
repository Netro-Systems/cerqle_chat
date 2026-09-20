import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/application/services/widget_onesignal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelNames = <String>[
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#inappmessages',
    'OneSignal#notifications',
    'OneSignal#pushsubscription',
    'OneSignal#user',
  ];

  tearDown(() async {
    WidgetOneSignalService.instance.resetForTesting();
    for (final name in channelNames) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('chat open reports unavailable permission without requesting', () async {
    var permissionRequests = 0;
    _mockOneSignal(
      permission: false,
      canRequest: false,
      onPermissionRequest: () => permissionRequests++,
    );
    final service = WidgetOneSignalService();

    await service.initialize(appId: 'test-app-id');
    final result = await service.requestPermissionForChatOpen();

    expect(result, CerqleNotificationPermissionResult.cannotRequest);
    expect(permissionRequests, 0);
  });

  test('chat open requests an available notification permission', () async {
    var permissionRequests = 0;
    var optIns = 0;
    _mockOneSignal(
      permission: false,
      canRequest: true,
      requestGranted: true,
      onPermissionRequest: () => permissionRequests++,
      onOptIn: () => optIns++,
    );
    final service = WidgetOneSignalService();

    await service.initialize(appId: 'test-app-id');
    final result = await service.requestPermissionForChatOpen();

    expect(result, CerqleNotificationPermissionResult.granted);
    expect(permissionRequests, 1);
    expect(optIns, 1);
  });

  test('failed native request falls back to notification settings', () async {
    var permissionRequests = 0;
    _mockOneSignal(
      permission: false,
      canRequest: true,
      onPermissionRequest: () => permissionRequests++,
    );
    final service = WidgetOneSignalService();

    await service.initialize(appId: 'test-app-id');
    final result = await service.requestPermissionForChatOpen();

    expect(result, CerqleNotificationPermissionResult.cannotRequest);
    expect(permissionRequests, 1);
  });

  test('token lookup can avoid requesting permission', () async {
    var permissionRequests = 0;
    _mockOneSignal(
      permission: false,
      canRequest: true,
      onPermissionRequest: () => permissionRequests++,
    );
    final service = WidgetOneSignalService();

    await service.initialize(appId: 'test-app-id');
    final token = await service.currentPushToken(requestPermission: false);

    expect(token, isNull);
    expect(permissionRequests, 0);
  });

  testWidgets('denied required permission keeps chat closed and shows settings',
      (tester) async {
    _mockOneSignal(permission: false, canRequest: true);
    CerqleChatResult? openResult;
    var openCompleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Mirrors hosts that place CerqleChatLauncher in this slot. Its
          // alignment container can report the full available layout size.
          floatingActionButton: const SizedBox.expand(),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                openResult = await CerqleChat.open(
                  context,
                  config: const CerqleConfig(
                    widgetKey: 'test-widget',
                    requireNotificationPermission: true,
                  ),
                );
                openCompleted = true;
              },
              child: const Text('Open chat'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();

    expect(openCompleted, isTrue);
    expect(openResult, isNull);
    expect(find.byType(CerqleChatScreen), findsNothing);
    expect(find.text('Enable notifications in Settings.'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _mockOneSignal({
  required bool permission,
  required bool canRequest,
  bool requestGranted = false,
  VoidCallback? onPermissionRequest,
  VoidCallback? onOptIn,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final name in <String>[
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#inappmessages',
    'OneSignal#user',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (_) async => null,
    );
  }

  messenger.setMockMethodCallHandler(
    const MethodChannel('OneSignal#notifications'),
    (call) async {
      switch (call.method) {
        case 'OneSignal#permission':
          return permission;
        case 'OneSignal#canRequest':
          return canRequest;
        case 'OneSignal#requestPermission':
          onPermissionRequest?.call();
          return requestGranted;
        default:
          return null;
      }
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('OneSignal#pushsubscription'),
    (call) async {
      switch (call.method) {
        case 'OneSignal#pushSubscriptionOptedIn':
          return false;
        case 'OneSignal#optIn':
          onOptIn?.call();
          return null;
        default:
          return null;
      }
    },
  );
}
