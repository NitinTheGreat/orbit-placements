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
    required this.accentContrast,
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
  final Color accentContrast;
  final Color accentEdge;
  final Color accentInk;
  final Color accentWash;
  final Color urgent;
  final Color urgentInk;
  final Color urgentWash;
  final Color success;
  final Color successInk;
  final Color successWash;

  static const Color seed = Color(0xFFB4823C);

  static const OrbitColors light = OrbitColors(
    surface: Color(0xFFF8F7F4),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEFEDE8),
    ink: Color(0xFF1B1B1F),
    inkMuted: Color(0xFF56565E),
    inkFaint: Color(0xFF74747C),
    border: Color(0xFFE6E3DD),
    borderStrong: Color(0xFFD2CFC8),
    accent: Color(0xFF96661B),
    accentContrast: Color(0xFFFFFFFF),
    accentEdge: Color(0xFF7E5516),
    accentInk: Color(0xFF6B4710),
    accentWash: Color(0xFFF6EEDF),
    urgent: Color(0xFFB4442F),
    urgentInk: Color(0xFF93392A),
    urgentWash: Color(0xFFFBE8E4),
    success: Color(0xFF2C6B50),
    successInk: Color(0xFF255B43),
    successWash: Color(0xFFE3F0E9),
  );

  static const OrbitColors dark = OrbitColors(
    surface: Color(0xFF131316),
    surfaceRaised: Color(0xFF1C1D21),
    surfaceSunken: Color(0xFF25262B),
    ink: Color(0xFFEAEAEE),
    inkMuted: Color(0xFFAFB0B8),
    inkFaint: Color(0xFF85868E),
    border: Color(0xFF2A2B30),
    borderStrong: Color(0xFF3A3B41),
    accent: Color(0xFFD8A75E),
    accentContrast: Color(0xFF1A1408),
    accentEdge: Color(0xFFB98A47),
    accentInk: Color(0xFFEFC98F),
    accentWash: Color(0xFF2B2519),
    urgent: Color(0xFFE08272),
    urgentInk: Color(0xFFF3A99B),
    urgentWash: Color(0xFF2F1F1D),
    success: Color(0xFF63AC86),
    successInk: Color(0xFF8FC9A9),
    successWash: Color(0xFF18261F),
  );
}

class OrbitRadius {
  static const double sheet = 24;
  static const double card = 20;
  static const double control = 14;
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
