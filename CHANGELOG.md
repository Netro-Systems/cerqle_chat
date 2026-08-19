# Changelog

## 0.1.0

### Added

- Reusable Flutter package structure with a cross-platform example app.
- Anonymous and verified-user chat sessions with secure, identity-scoped storage.
- Public widget API client with injectable HTTP transport, Pusher realtime WebSocket channels, and OneSignal push notification integration.
- Typed chat state, events, errors, and redacted diagnostics.
- Lifecycle-aware foreground polling with message ordering, deduplication, and send/server-echo reconciliation.
- Realtime message streaming and typing updates over private Pusher channels (`WidgetMessageCreated`, `WidgetTypingChanged`, `WidgetHandoffUpdated`).
- OneSignal push notification integration with automatic device ID registration and click handling.
- Text, image, and audio message transport using the current visitor API.
- Human handoff, typing updates, and required pre-chat support.
- Prebuilt full-screen, launcher, embedded, bottom-sheet, dialog, and headless integration surfaces.
- Material UI defaults with server/host theme resolution, loading, empty, error, reconnecting, offline, and accessibility states.
- `CerqleConfig.useApiColors` for switching between API-provided colors and the built-in Cerqle signature purple brand palette.
- Format-aware remote image rendering for SVG and Flutter-supported raster assets.
- Public API documentation and contributor guidance.
