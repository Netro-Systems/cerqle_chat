# Cerqle Chat Project Goal

Provide a robust, production-ready Flutter SDK for integrating Cerqle customer chat across mobile, desktop, and web platforms.

## Key Principles

1. **Brand Fidelity**: Strictly adhere to Cerqle's brand identity, purple palette, and modern UI aesthetic.
2. **Reliability & Realtime**: Combine WebSocket channels (Pusher) with foreground fallback polling and OneSignal push notifications.
3. **Security**: Identity-scoped secure credential storage, HMAC verification support, and zero credential leakage.
4. **Developer Experience**: Simple drop-in facade (`CerqleChat.open`), floating launcher (`CerqleChatLauncher`), and headless controller for full customization.
