import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/application/services/widget_onesignal_service.dart';
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

  tearDown(() {
    WidgetOneSignalService.instance.resetForTesting();
    for (final name in channelNames) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('Cerqle initialization owns notification setup', () async {
    var permissionRequests = 0;
    _mockOneSignal(() => permissionRequests++);

    await CerqleChat.initialize(
      config: const CerqleConfig(
        widgetKey: 'test-widget',
        registerUserOnStartup: false,
      ),
    );

    expect(WidgetOneSignalService.instance.isInitialized, isTrue);
    expect(permissionRequests, 1);
  });

  test('OneSignal can be disabled without separate handler setup', () async {
    await CerqleChat.initialize(
      config: const CerqleConfig(
        widgetKey: 'test-widget',
        enableOneSignal: false,
        registerUserOnStartup: false,
      ),
    );

    expect(WidgetOneSignalService.instance.isInitialized, isFalse);
  });
}

void _mockOneSignal(VoidCallback onPermissionRequest) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final name in <String>[
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#inappmessages',
    'OneSignal#user',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  messenger.setMockMethodCallHandler(
    const MethodChannel('OneSignal#notifications'),
    (call) async {
      if (call.method == 'OneSignal#requestPermission') {
        onPermissionRequest();
        return true;
      }
      if (call.method == 'OneSignal#permission') return false;
      if (call.method == 'OneSignal#canRequest') return true;
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('OneSignal#pushsubscription'),
    (_) async => null,
  );
}
