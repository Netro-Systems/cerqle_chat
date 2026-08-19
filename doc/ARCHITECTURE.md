# Cerqle Architecture

## Layer Boundary

```text
presentation -> application -> domain <- data
configuration --------^          ^
             application runtime wires adapters
```

- `configuration`: Public host configuration, theme settings, polling options, and identity models.
- `domain`: Core domain models, interfaces, typed exceptions (`CerqleException`), and event definitions.
- `application`: State machine, chat controller, session coordinator, polling coordinator, Pusher realtime connector, and OneSignal service.
- `data`: HTTP network caller, request encoders, response decoders, API endpoint definitions, and secure storage implementation.
- `presentation`: UI components (screens, embedded views, launchers, message bubbles, composer, and theme resolution).
