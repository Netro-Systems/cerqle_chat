# Cerqle Architecture

## Layer Boundary

```text
presentation -> application -> domain <- data
configuration --------^          ^
             application runtime wires adapters
```

- `configuration`: Public host configuration, theme settings, startup behavior, and identity models.
- `domain`: Core domain models, interfaces, typed exceptions (`CerqleException`), and event definitions.
- `application`: State machine, chat controller, session coordinator, message reconciliation, Pusher realtime connector, and OneSignal service.
- `data`: HTTP network caller, request encoders, response decoders, API endpoint definitions, and secure storage implementation.
- `presentation`: UI components (screens, embedded views, launchers, synchronized unread badges, linkified message bubbles, composer, and theme resolution).
