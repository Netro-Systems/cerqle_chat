import 'package:flutter/material.dart';

import '../../configuration/cerqle_config.dart';
import '../../domain/models/models.dart';

const _brandPrimary = Color(0xFF3E2A49);
const _brandSecondary = Color(0xFF8F5FA7);
const _brandSecondaryStrong = Color(0xFF77488E);
const _brandBackgroundLight = Color(0xFFF8FAFC);
const _brandSurfaceLight = Color(0xFFFFFFFF);
const _brandSurfaceMutedLight = Color(0xFFE2E8F0);
const _brandOnSurfaceLight = Color(0xFF0F172A);
const _brandOnSurfaceMutedLight = Color(0xFF64748B);
const _brandOutlineLight = Color(0xFFCBD5E1);
const _brandBackgroundDark = Color(0xFF090A0F);
const _brandSurfaceDark = Color(0xFF171923);
const _brandSurfaceMutedDark = Color(0xFF2A2D3D);
const _brandOnSurfaceDark = Color(0xFFF8FAFC);
const _brandOnSurfaceMutedDark = Color(0xFF94A3B8);
const _brandOutlineDark = Color(0xFF303445);

class CerqleResolvedTheme {
  CerqleResolvedTheme({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.visitorBubble,
    required this.onVisitorBubble,
    required this.agentBubble,
    required this.onAgentBubble,
    required this.error,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.borderRadius,
    required this.messageSpacing,
    required this.launcherSize,
  });

  factory CerqleResolvedTheme.resolve({
    required ThemeData hostTheme,
    required CerqleThemeData? override,
    required CerqleWidgetConfig? server,
    required bool useApiColors,
  }) {
    final serverPrimary = useApiColors
        ? _parseHex(server?.primaryColorHex)
        : null;
    final requestedBrightness = override?.brightness;
    final colorScheme = requestedBrightness == null
        ? hostTheme.colorScheme
        : ColorScheme.fromSeed(
            seedColor: override?.primaryColor ?? serverPrimary ?? _brandPrimary,
            brightness: requestedBrightness,
          );
    final primary = override?.primaryColor ?? serverPrimary ?? _brandPrimary;
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface =
        override?.surfaceColor ??
        (isDark ? _brandSurfaceDark : _brandSurfaceLight);
    final background =
        override?.backgroundColor ??
        (isDark ? _brandBackgroundDark : _brandBackgroundLight);
    final visitorBubble =
        override?.visitorBubbleColor ??
        (isDark ? _brandSecondaryStrong : _brandSecondary);
    final agentBubble =
        override?.agentBubbleColor ??
        (isDark ? _brandSurfaceMutedDark : _brandSurfaceMutedLight);
    final onSurface = isDark ? _brandOnSurfaceDark : _brandOnSurfaceLight;
    return CerqleResolvedTheme(
      primary: primary,
      onPrimary: _contrasting(primary),
      background: background,
      surface: surface,
      surfaceMuted: isDark ? _brandSurfaceMutedDark : _brandSurfaceMutedLight,
      visitorBubble: visitorBubble,
      onVisitorBubble:
          override?.onVisitorBubbleColor ?? _contrasting(visitorBubble),
      agentBubble: agentBubble,
      onAgentBubble: override?.onAgentBubbleColor ?? onSurface,
      error: override?.errorColor ?? colorScheme.error,
      onSurface: onSurface,
      onSurfaceMuted: isDark
          ? _brandOnSurfaceMutedDark
          : _brandOnSurfaceMutedLight,
      outline: isDark ? _brandOutlineDark : _brandOutlineLight,
      borderRadius: override?.borderRadius?.clamp(4, 32).toDouble() ?? 16,
      messageSpacing: override?.messageSpacing?.clamp(2, 24).toDouble() ?? 8,
      launcherSize: override?.launcherSize?.clamp(48, 80).toDouble() ?? 56,
    );
  }

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color visitorBubble;
  final Color onVisitorBubble;
  final Color agentBubble;
  final Color onAgentBubble;
  final Color error;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color outline;
  final double borderRadius;
  final double messageSpacing;
  final double launcherSize;
}

Color _contrasting(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;

Color? _parseHex(String? value) {
  if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    return null;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}
