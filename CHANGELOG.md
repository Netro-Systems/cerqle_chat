# Changelog

## Unreleased

### Added

- Added a compact, single-row message composer with focus-driven expansion and refreshed chat action icons.
- Added configurable full-screen status-bar icon brightness.

### Changed

- Replaced timer-based foreground polling with Pusher as the primary live conversation transport.
- Removed `CerqlePollingConfig` and `CerqleConfig.polling`; retained bounded pull-to-refresh and initial history pagination without a periodic scheduler.
- Realtime connections now follow listener and application lifecycle demand and retry failed initial socket connections.

## 0.1.0

### Added

- Reusable Flutter package structure with a cross-platform example app.
- Anonymous and verified-user chat sessions with secure, identity-scoped storage.
- Public widget API client with injectable HTTP transport, Pusher realtime WebSocket channels, and OneSignal push notification integration.
- Typed chat state, events, errors, and redacted diagnostics.
- Message ordering, deduplication, and send/server-echo reconciliation.
- Realtime message streaming and typing updates over private Pusher channels (`WidgetMessageCreated`, `WidgetTypingChanged`, `WidgetHandoffUpdated`).
- OneSignal push notification integration with automatic device ID registration and click handling.
- Text, image, and audio message transport using the current visitor API.
- Human handoff, typing updates, and required pre-chat support.
- Prebuilt full-screen, launcher, embedded, bottom-sheet, dialog, and headless integration surfaces.
- Material UI defaults with server/host theme resolution, loading, empty, error, reconnecting, offline, and accessibility states.
- `CerqleConfig.useApiColors` for switching between API-provided colors and the built-in Cerqle signature purple brand palette.
- Format-aware remote image rendering for SVG and Flutter-supported raster assets.
- Public API documentation and contributor guidance.
