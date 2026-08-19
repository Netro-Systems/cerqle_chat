# Cerqle chat

![Cerqle](assets/images/cerqle-logo.svg)

![pub version](https://img.shields.io/pub/v/cerqle_chat?label=cerqle_chat)
![last commit](https://img.shields.io/github/last-commit/Netro-Systems/cerqle_chat)
![license](https://img.shields.io/badge/license-MIT-green)

`cerqle_chat` is a Flutter package for adding Cerqle customer chat to Flutter apps. It includes secure visitor sessions, public widget API communication, realtime Pusher channel synchronization, OneSignal push notifications, foreground polling, message reconciliation, typed state and errors, and customizable Material UI with Cerqle's signature branding.

Native requests work only for widgets whose browser domain allowlist is empty; the SDK never spoofs browser `Origin` or `Referer` headers.

## Quick start

Add the package and open chat with a public widget key:

```dart
import 'package:cerqle_chat/cerqle_chat.dart';

final config = CerqleConfig(widgetKey: 'YOUR_WIDGET_KEY');

await CerqleChat.open(context, config: config);
```

The widget key routes chat and is not a secret. Never put Cerqle management credentials or a widget identity secret in a Flutter app.

## Installation

The preview requires Flutter 3.24 or newer (Dart 3.5 or newer).

Add the package to your app:

```yaml
dependencies:
  cerqle_chat: ^0.1.0
```

Android apps must use min SDK 23 because the default session store uses `flutter_secure_storage`:

```kotlin
defaultConfig {
    minSdk = 23
}
```

Production apps also need Android's `INTERNET` permission. Debug-only local HTTP endpoints may require Android cleartext or Apple transport-security development configuration; non-debug SDK builds require HTTPS.

On iOS and macOS, enable Keychain Sharing and include a `keychain-access-groups` entitlement. The runnable [example](example/) contains the required configuration. Web deployments must use HTTPS (or localhost during development); browser session storage inherits the browser origin's security and backup behavior.

## Integration styles

Full screen:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => CerqleChatScreen(config: config),
  ),
);
```

Floating launcher:

```dart
Stack(
  children: [
    const ApplicationContent(),
    CerqleChatLauncher(config: config),
  ],
)
```

Embedded:

```dart
CerqleChatView(config: config, showHeader: true)
```

Bottom sheet or dialog:

```dart
await CerqleChat.open(
  context,
  config: config,
  presentation: CerqlePresentation.bottomSheet,
);
```

Headless/custom UI:

```dart
final client = CerqleClient(config: config);
final controller = CerqleChatController(client: client);
final states = controller.states.listen(renderChatState);

await controller.initialize();
await controller.sendText('Hello');

await states.cancel();
await controller.dispose();
await client.close();
```

When a view, screen, or launcher creates its controller, it owns and disposes the runtime. When you supply a controller, you retain ownership.

## Colors and branding

API colors are enabled by default. Disable them to use Cerqle's built-in purple brand palette (`#3E2A49`, secondary `#8F5FA7`):

```dart
final config = CerqleConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  useApiColors: false,
);
```

Custom theme colors always take precedence, whether API colors are enabled or not:

```dart
final config = CerqleConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  useApiColors: false,
  theme: const CerqleThemeData(
    primaryColor: Color(0xFF3E2A49),
  ),
);
```

## Verified users

Generate the HMAC signature on your server. The SDK must never receive the widget identity secret.

```dart
final config = CerqleConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  user: CerqleUser(
    externalId: signedInUser.id,
    name: signedInUser.displayName,
    signature: signatureFetchedFromYourBackend,
  ),
);
```

Call `controller.updateUser(...)` whenever the host app switches accounts, and `controller.updateUser(null)` on logout. Logout stops polling and realtime streaming, sends a best-effort typing-off update, unlinks OneSignal device tags, deletes the active credential scope, and clears the in-memory conversation. It does not create a replacement anonymous session; the next `initialize()` or newly opened chat creates one. Sessions are securely isolated by canonical API base URL, widget key, and identity scope.

Anonymous and correctly signed identities persist across launches. Unsigned profile-only sessions stay in memory so an unverified display name or email cannot become a durable identity key or leave unreachable secure-storage records.

## Push notifications & Realtime sync

The SDK includes built-in OneSignal push notification registration and Pusher realtime streaming.

Initialize notification handlers in `main.dart` or during app startup:

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = CerqleConfig(
    widgetKey: 'YOUR_WIDGET_KEY',
    user: const CerqleUser(name: 'Demo User', email: 'user@demo.com'),
  );

  // Initialize push notification click handlers:
  CerqleChat.initializeNotificationHandlers(
    config: config,
    navigatorKey: navigatorKey,
  );

  runApp(MyApp(navigatorKey: navigatorKey));
}
```

When a visitor starts a session, the SDK automatically collects the OneSignal device/subscription ID and submits it with the session request (`device_id`). When support agents reply, push notifications delivered to the device will automatically open the chatbox when tapped.

Realtime WebSocket channels are automatically established via Pusher (`private-widget-conversation.{conversationId}`) for instant message receipt and typing indicators.

## Current capabilities

| Capability | Android/iOS | Web | macOS/Windows/Linux |
|---|---:|---:|---:|
| Anonymous and signed-user sessions | Yes | Yes* | Yes |
| Pusher realtime streaming | Yes | Yes | Yes |
| OneSignal push notifications | Yes | Yes | Yes |
| Text, image/audio transport | Yes | Yes | Yes |
| Foreground polling & auto-reconnect | Yes | Yes | Yes |
| Typing and human handoff | Yes | Yes | Yes |
| Prebuilt screen/view/launcher/modal UI | Yes | Yes | Yes |
| Required name/email pre-chat | Yes | Yes | Yes |
| Widget domain allowlist from native apps | Native policy pending | Supported by browser origin | Native policy pending |

\* Web secure storage requires HTTPS or localhost and is scoped to the browser origin.

## Delivery and error behavior

- Visitor tokens are bearer credentials stored through `CerqleSessionStore`; the default implementation uses secure platform storage.
- A send becomes `sent` only after a server response supplies a message ID.
- A disconnected or timed-out send becomes `unconfirmed` and is not automatically retried, because the current backend has no client idempotency key.
- Foreground polling delivers bot/human replies and pauses when the app is backgrounded or no synchronization listener exists.
- Session and poll responses are ordered and deduplicated by server ID. Send responses never advance the receive cursor, preventing missed gaps.
- Required pre-chat uses a second authenticated session request after configuration is loaded.
- Diagnostics are structured and redacted; tokens, signatures, PII, message bodies, and attachment URLs are never included.

## Development

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
