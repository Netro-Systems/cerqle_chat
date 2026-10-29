# Cerqle Chat Developer Implementation Guide

This guide describes the current Cerqle Chat integration for application
developers.

## Requirements

- Add `cerqle_chat: ^0.1.3` to the application dependencies.
- Provide the public widget key and API base URL.
- Configure a `GlobalKey<NavigatorState>` so notification taps can open chat.

`CerqleLocation` is no longer part of `CerqleUser`. Push notification setup
and startup visitor registration are now handled by
`CerqleChat.initialize(...)`; separate notification initialization and manual
visitor registration are not required.

## Remove these old integrations

### 1. Remove location from `CerqleUser`

Delete the entire `location` argument:

```dart
location: CerqleLocation(
  country: 'Bangladesh',
  countryCode: 'BD',
  city: 'Dhaka',
  region: 'Dhaka Division',
  latitude: 23.8103,
  longitude: 90.4125,
  pageTitle: 'Cerqle Example App',
  pageUrl: 'cerqle://example',
),
```

The user configuration should now contain only the visitor fields the
application needs:

```dart
user: const CerqleUser(
  name: 'Demo Visitor',
  email: 'visitor@demo.com',
),
```

If the application has additional visitor metadata, provide it through
`CerqleUser.customFields` instead of `CerqleLocation`.

### 2. Remove the old startup calls

Delete both of these calls:

```dart
CerqleChat.initializeNotificationHandlers(
  config: config,
  navigatorKey: navigatorKey,
);

unawaited(
  CerqleChat.registerVisitor(config: config),
);
```

Replace them with the single awaited initialization call shown below.
`CerqleConfig.registerUserOnStartup` defaults to `true`, so the package
automatically registers the visitor during `CerqleChat.initialize(...)`.
Developers do not need to call `CerqleChat.registerVisitor(...)` themselves.

## Initialize in `main()`

Create one configuration and use the same instance for initialization and every
chat entry point:

```dart
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final navigatorKey = GlobalKey<NavigatorState>();
late final CerqleConfig config;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final widgetKey = dotenv.get('CERQLE_WIDGET_KEY');
  final configuredOneSignalAppId =
      dotenv.maybeGet('CERQLE_ONESIGNAL_APP_ID')?.trim();

  config = CerqleConfig(
    widgetKey: widgetKey,
    registerUserOnStartup: true,
    requireNotificationPermission: true,
    lightStatusBarIcons: true,
    apiBaseUrl: dotenv.maybeGet('CERQLE_API_BASE_URL')?.trim() ??
        'https://yourdomain.com',
    oneSignalAppId: configuredOneSignalAppId?.isNotEmpty == true
        ? configuredOneSignalAppId!
        : CerqleConfig.defaultOneSignalAppId,
    user: const CerqleUser(
      name: 'Demo Visitor',
      email: 'visitor@demo.com',
    ),
  );

  await CerqleChat.initialize(
    config: config,
    navigatorKey: navigatorKey,
  );

  runApp(const MyApp());
}
```

Replace the demonstration visitor data with the signed-in user's values. Omit
`user` for an anonymous session. Optional application-specific metadata can be
provided through `CerqleUser.customFields`.

Open chat with the same configuration:

```dart
await CerqleChat.open(context, config: config);
```

## Unread badges

Unread state is shared across launchers and badge wrappers using the same
configuration. Opening the conversation from any entry point marks visible
messages as read and clears all related badges.

### Example 1: floating action button

```dart
Scaffold(
  floatingActionButton: CerqleChatLauncher(
    config: config,
    showBadge: true,
    badgeShowCount: true,
    badgeBackgroundColor: const Color(0xFFFF0000),
    badgeLargeSize: 20,
    badgeOffset: const Offset(4, -4),
  ),
  body: const HomeContent(),
)
```

### Example 2: app-bar action

```dart
AppBar(
  actions: [
    CerqleChat.badge(
      config: config,
      showCount: true,
      largeSize: 18,
      backgroundColor: const Color(0xFFFF0000),
      textStyle: const TextStyle(fontSize: 10),
      offset: const Offset(-6, 6),
      child: IconButton(
        iconSize: 26,
        icon: const Icon(Icons.message),
        onPressed: () async {
          await CerqleChat.open(context, config: config);
        },
      ),
    ),
  ],
)
```

### Example 3: custom container button

```dart
CerqleChat.badge(
  config: config,
  showCount: true,
  largeSize: 20,
  backgroundColor: const Color(0xFFFF0000),
  textStyle: const TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  ),
  offset: const Offset(5, -5),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await CerqleChat.open(context, config: config);
      },
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF5B007A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.support_agent,
          color: Colors.white,
          size: 26,
        ),
      ),
    ),
  ),
)
```

## Badge options

- `showCount: true` displays the unread count instead of a dot.
- `largeSize` controls the count-badge size.
- `backgroundColor` and `textStyle` customize its appearance.
- `offset` positions the badge relative to the wrapped widget.
- `CerqleChatLauncher` requires `showBadge: true` because its badge is hidden
  by default.

## Message links

HTTP, HTTPS, and `www.` links in sent and received messages are blue,
clickable, and open in the device's external browser.

## Further reference

For a more complete working example and a better understanding of the
integration, review:

- [`example/lib/main.dart`](example/lib/main.dart) for the runnable application
  implementation.
- [`README.md`](README.md) for the updated installation, configuration, presentation,
  notification, badge, media, and message-link documentation.
