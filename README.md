# Cerqle Chat

![pub version](https://img.shields.io/pub/v/cerqle_chat?label=cerqle_chat)
![license](https://img.shields.io/badge/license-MIT-green)

A customizable, battery-efficient Flutter SDK for embedding Cerqle customer support chat into mobile, web, and desktop apps. It provides identity-scoped visitor sessions, real-time messaging, Pusher channel synchronization, foreground polling, prebuilt customizable UI, and push notifications.

---

## Capabilities & Platform Support

| Capability | Android / iOS | Web | macOS / Windows / Linux |
|---|:---:|:---:|:---:|
| **Anonymous & Signed-User Sessions** | ✅ Yes | ✅ Yes* | ✅ Yes |
| **OneSignal Push Notifications** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Realtime Pusher Streaming** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Text, Image, Audio & File Messaging** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Foreground Polling & Sync** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Typing Indicators & Human Handoff** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Prebuilt UI (Screens, Sheets, Dialogs, Launchers)** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Required Pre-Chat Lead Forms** | ✅ Yes | ✅ Yes | ✅ Yes |

*\* Web secure storage requires HTTPS (or localhost during development) and is scoped to the browser origin.*

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  cerqle_chat: ^0.1.0
```

Or run:

```bash
flutter pub add cerqle_chat
```

### Platform Requirements

* **Android**: Set `minSdk = 23` in `android/app/build.gradle` (required by `flutter_secure_storage`) and ensure `INTERNET` permission is granted:
  ```kotlin
  defaultConfig {
      minSdk = 23
  }
  ```
* **iOS & macOS**: Enable **Keychain Sharing** in Xcode and include a `keychain-access-groups` entitlement. The runnable [example](example) contains the required configuration.
* **Web**: Deploy over HTTPS (browser session storage inherits the origin's security).

---

## Quick Start

Open a functional chat interface with just a few lines of code using your public **Widget Key**:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

void openSupportChat(BuildContext context) async {
  final config = CerqleConfig(widgetKey: 'YOUR_WIDGET_KEY');
  await CerqleChat.open(context, config: config);
}
```

> [!NOTE]
> The `widgetKey` is a public routing identifier, not a secret. Never bundle Cerqle management credentials or widget secret keys in client applications.

---

## Integration Styles

Cerqle provides multiple ready-to-use presentation modes to fit seamlessly into any app workflow:

### 1. Full Screen
An immersive, dedicated support page with app bar navigation:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

void openFullScreen(BuildContext context, CerqleConfig config) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CerqleChatScreen(config: config),
    ),
  );
}
```

### 2. Modal Bottom Sheet
Keeps the current screen in context while sliding up the chat interface:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

Future<void> openBottomSheet(BuildContext context, CerqleConfig config) async {
  await CerqleChat.open(
    context,
    config: config,
    presentation: CerqlePresentation.bottomSheet,
  );
}
```

### 3. Dialog Popup
A compact, centered chat window ideal for tablets, desktops, or web:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

Future<void> openDialog(BuildContext context, CerqleConfig config) async {
  await CerqleChat.open(
    context,
    config: config,
    presentation: CerqlePresentation.dialog,
  );
}
```

### 4. Floating Launcher
An expandable floating action button that overlays your screen:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

Widget buildFloatingLauncher(CerqleConfig config) {
  return Stack(
    children: [
      const Placeholder(), // Application content
      CerqleChatLauncher(config: config),
    ],
  );
}
```

### 5. Embedded View
Place the chat view directly inside an existing layout, drawer, or split-view:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

Widget buildEmbeddedChat(CerqleConfig config) {
  return CerqleChatView(
    config: config,
    showHeader: true,
  );
}
```

### 6. Headless & Custom UI
Take full programmatic control with `CerqleChatController`:

```dart
import 'package:cerqle_chat/cerqle_chat.dart';

Future<void> runHeadlessChat(CerqleConfig config) async {
  final client = CerqleClient(config: config);
  final controller = CerqleChatController(client: client);

  // Listen to state changes
  final subscription = controller.states.listen((state) {
    debugPrint('Phase: ${state.phase}, Messages: ${state.messages.length}');
  });

  await controller.initialize();
  await controller.sendText('Hello, I need help!');

  // Cleanup
  await subscription.cancel();
  await controller.dispose();
  await client.close();
}
```

---

## Configuration Reference

`CerqleConfig` accepts the following options:

| Property | Type | Default | Description |
|---|---|---|---|
| `widgetKey` | `String` | *(required)* | Public routing identifier issued by the Cerqle dashboard. |
| `apiBaseUrl` | `String` | `'https://cerqle.ai'` | Base origin endpoint for widget API requests (`/widget/v1/*`). |
| `user` | `CerqleUser?` | `null` | Visitor identity, profile data, and HMAC signature for verified users. |
| `theme` | `CerqleThemeData?` | `null` | Presentation overrides for colors, bubble radius, spacing, and brightness. |
| `useApiColors` | `bool` | `true` | When true, applies the dashboard-configured branding palette automatically. |
| `presentation` | `CerqlePresentation` | `CerqlePresentation.fullScreen` | Default modal style (`fullScreen`, `bottomSheet`, or `dialog`) used by `CerqleChat.open`. |
| `enableTyping` | `bool` | `true` | Whether the controller publishes throttled visitor typing updates. |
| `mediaAdapter` | `CerqleMediaAdapter?` | `null` | Optional bridge for image selection, voice recording, and file picking. |
| `polling` | `CerqlePollingConfig` | `const CerqlePollingConfig()` | Intervals for active (`3s`), idle (`8s`), and failure backoff (`30s`) foreground polling. |
| `diagnostics` | `CerqleDiagnosticsCallback?` | `null` | Callback receiving redacted operational metrics and lifecycle events. |
| `oneSignalAppId` | `String` | `CerqleConfig.defaultOneSignalAppId` | OneSignal App ID used for push notification registration. |
| `enableOneSignal` | `bool` | `true` | Whether device push notification tokens are registered on session start. |
| `sessionStore` | `CerqleSessionStore?` | `null` | Custom session store override (defaults to secure encrypted platform storage). |

---

## Key Features

### 👤 Verified & Authenticated Users
To associate chat sessions with registered users in your application, provide a `CerqleUser` along with an HMAC signature computed on your backend:

```dart
import 'package:cerqle_chat/cerqle_chat.dart';

final config = CerqleConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  user: CerqleUser(
    externalId: 'user_123',
    name: 'Jane Doe',
    email: 'user@example.com',
    signature: 'backend_hmac_signature',
  ),
);
```

#### Switching Accounts & Logout
* **Switch user**: Call `controller.updateUser(newUser)` when switching accounts.
* **Logout**: Call `controller.updateUser(null)` on logout to wipe active credentials and clear local conversation state securely.

---

### 🎨 Colors & Theming
By default, the SDK uses the color palette configured in your Cerqle dashboard (`useApiColors: true`).

To customize colors locally or use custom themes:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

final config = CerqleConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  useApiColors: false, // Disables server palette
  theme: const CerqleThemeData(
    primaryColor: Color(0xFF6B46C1),
    visitorBubbleColor: Color(0xFF6B46C1),
    agentBubbleColor: Color(0xFFE9ECEF),
    borderRadius: 16.0,
  ),
);
```

---

### 🔔 Push Notifications
The SDK provides built-in OneSignal push notification integration so visitors receive notifications when agents reply.

Initialize notification handlers in `main()`:

```dart
import 'package:flutter/material.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = CerqleConfig(
    widgetKey: 'YOUR_WIDGET_KEY',
    user: const CerqleUser(name: 'Demo User', email: 'user@demo.com'),
  );

  CerqleChat.initializeNotificationHandlers(
    config: config,
    navigatorKey: navigatorKey,
  );

  runApp(MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()));
}
```

When a notification is tapped, the SDK automatically opens the chatbox and refreshes messages.

---

### 📷 Media & Attachments
To enable image picking, voice messaging, and document attachments in the composer, supply a `CerqleMediaAdapter`:

```dart
import 'package:cerqle_chat/cerqle_chat.dart';

final config = CerqleConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  mediaAdapter: MyCustomMediaAdapter(),
);
```
*(See the [example](example) app for a full reference implementation).*

---

### 📝 Pre-Chat Forms
When a widget requires pre-chat information (such as name or email), the built-in UI collects and submits the required fields automatically before initiating chat. Known fields already set on `config.user` are automatically populated.

For headless integrations, submit manually via:
```dart
import 'package:cerqle_chat/cerqle_chat.dart';

Future<void> submitLead(CerqleChatController controller) async {
  await controller.submitPreChat(
    const CerqlePreChatData(name: 'Jane Doe', email: 'jane@example.com'),
  );
}
```

---

## Delivery & Reliability Behavior

* **Platform Security**: Visitor tokens are bearer credentials persisted via `CerqleSessionStore` using platform-native secure storage (`flutter_secure_storage`).
* **Authoritative Confirmation**: Messages transition from `pending` to `sent` only upon server receipt and ID issuance.
* **Network Failures & Unconfirmed State**: If a request disconnects or times out before receiving a response, the message is marked `unconfirmed` rather than failed, avoiding duplicate message sends.
* **Battery-Efficient Sync**: Foreground polling and Pusher realtime channels synchronize replies and pause automatically when the application is backgrounded or when chat is closed.
* **Safe Diagnostics**: Diagnostic callbacks emit strictly redacted operational telemetry (durations, error codes, HTTP statuses) without logging PII, bearer tokens, or message content.

---

## Development & Testing

```bash
# Get dependencies
flutter pub get

# Format code
dart format --output=none --set-exit-if-changed .

# Run static analysis
flutter analyze

# Run unit tests
flutter test
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
