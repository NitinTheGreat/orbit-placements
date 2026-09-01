import 'package:flutter/widgets.dart';

class OrbitColors {
  const OrbitColors({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentEdge,
    required this.accentInk,
    required this.accentWash,
    required this.urgent,
    required this.urgentInk,
    required this.urgentWash,
    required this.success,
    required this.successInk,
    required this.successWash,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color accentEdge;
  final Color accentInk;
  final Color accentWash;
  final Color urgent;
  final Color urgentInk;
  final Color urgentWash;
  final Color success;
  final Color successInk;
  final Color successWash;

  static const OrbitColors light = OrbitColors(
    surface: Color(0xFFF5F3EF),
    surfaceRaised: Color(0xFFFCFBF9),
    surfaceSunken: Color(0xFFEBE7E0),
    ink: Color(0xFF1A1815),
    inkMuted: Color(0xFF6B655C),
    inkFaint: Color(0xFF938C81),
    border: Color(0xFFE2DDD4),
    borderStrong: Color(0xFFCFC8BC),
    accent: Color(0xFFC98A2B),
    accentEdge: Color(0xFFAD741F),
    accentInk: Color(0xFF7A5214),
    accentWash: Color(0xFFF7EBD6),
    urgent: Color(0xFFD65F4C),
    urgentInk: Color(0xFFB33F2E),
    urgentWash: Color(0xFFFAE6E2),
    success: Color(0xFF2F7A5C),
    successInk: Color(0xFF2A6E53),
    successWash: Color(0xFFDFEFE7),
  );

  static const OrbitColors dark = OrbitColors(
    surface: Color(0xFF1A1815),
    surfaceRaised: Color(0xFF232019),
    surfaceSunken: Color(0xFF141210),
    ink: Color(0xFFF5F3EF),
    inkMuted: Color(0xFFA39B8E),
    inkFaint: Color(0xFF7A736A),
    border: Color(0xFF332E26),
    borderStrong: Color(0xFF453E33),
    accent: Color(0xFFE0A945),
    accentEdge: Color(0xFFE0A945),
    accentInk: Color(0xFFF0D19A),
    accentWash: Color(0xFF33291A),
    urgent: Color(0xFFE87A66),
    urgentInk: Color(0xFFE87A66),
    urgentWash: Color(0xFF3A241F),
    success: Color(0xFF4E9E7B),
    successInk: Color(0xFF5AAD89),
    successWash: Color(0xFF1C2F27),
  );
}

class OrbitRadius {
  static const double sheet = 20;
  static const double card = 18;
  static const double control = 12;
  static const double rail = 3;
  static const double pill = 999;
}

class OrbitSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class OrbitMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration entrance = Duration(milliseconds: 320);
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve spring = Cubic(0.2, 0.9, 0.25, 1.06);
  static const Curve settle = Cubic(0.22, 0.61, 0.36, 1);
}

class OrbitTheme extends InheritedWidget {
  const OrbitTheme({super.key, required this.colors, required super.child});

  final OrbitColors colors;

  static OrbitColors of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<OrbitTheme>();
    assert(theme != null, 'No OrbitTheme found in context');
    return theme!.colors;
  }

  @override
  bool updateShouldNotify(OrbitTheme oldWidget) => colors != oldWidget.colors;
}

bool prefersReducedMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media == null) {
    return false;
  }
  return media.disableAnimations || media.accessibleNavigation;
}
