import 'package:flutter/material.dart';

/// The app's palette. Same colours as the BenQ Bridge web UI: graphite with a violet accent,
/// and a warm amber reserved for the eye-care controls.
@immutable
class BridgeColors extends ThemeExtension<BridgeColors> {
  const BridgeColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.track,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.lamp,
    required this.lampSoft,
    required this.ok,
    required this.bad,
    required this.badSoft,
    required this.thumb,
  });

  static const dark = BridgeColors(
    bg: Color(0xFF0F1211),
    surface: Color(0xFF171B1A),
    raised: Color(0xFF202524),
    line: Color(0xFF2A302E),
    track: Color(0xFF2C3331),
    text: Color(0xFFE8EDE9),
    muted: Color(0xFF8F9B95),
    accent: Color(0xFF9B83FF),
    accentSoft: Color(0x299B83FF),
    onAccent: Color(0xFF14102A),
    lamp: Color(0xFFF2B45A),
    lampSoft: Color(0x29F2B45A),
    ok: Color(0xFF52D18C),
    bad: Color(0xFFFF6B6B),
    badSoft: Color(0x24FF6B6B),
    thumb: Color(0xFFF4F5F7),
  );

  static const light = BridgeColors(
    bg: Color(0xFFF2F4F2),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFECEEEC),
    line: Color(0xFFDCDFDC),
    track: Color(0xFFDDE1DE),
    text: Color(0xFF151A18),
    muted: Color(0xFF5B6761),
    accent: Color(0xFF5A3FD1),
    accentSoft: Color(0x1F5A3FD1),
    onAccent: Color(0xFFFFFFFF),
    lamp: Color(0xFFA95F00),
    lampSoft: Color(0x24C97800),
    ok: Color(0xFF178A52),
    bad: Color(0xFFC4312F),
    badSoft: Color(0x1AC4312F),
    thumb: Color(0xFFFFFFFF),
  );

  final Color bg;
  final Color surface;
  final Color raised;
  final Color line;
  final Color track;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color lamp;
  final Color lampSoft;
  final Color ok;
  final Color bad;
  final Color badSoft;
  final Color thumb;

  @override
  BridgeColors copyWith() => this;

  @override
  BridgeColors lerp(ThemeExtension<BridgeColors>? other, double t) {
    if (other is! BridgeColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return BridgeColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      line: mix(line, other.line),
      track: mix(track, other.track),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccent: mix(onAccent, other.onAccent),
      lamp: mix(lamp, other.lamp),
      lampSoft: mix(lampSoft, other.lampSoft),
      ok: mix(ok, other.ok),
      bad: mix(bad, other.bad),
      badSoft: mix(badSoft, other.badSoft),
      thumb: mix(thumb, other.thumb),
    );
  }
}

extension BridgeColorsContext on BuildContext {
  BridgeColors get colors => Theme.of(this).extension<BridgeColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? BridgeColors.dark : BridgeColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.lamp,
    onSecondary: c.bg,
    error: c.bad,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.line,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? c.accent : c.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.accent : c.muted),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: TextStyle(color: c.bg, fontSize: 14, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.line),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    textTheme: Typography.material2021().black.apply(bodyColor: c.text, displayColor: c.text).copyWith(
          bodyMedium: TextStyle(color: c.text, fontSize: 15),
        ),
  );
}
