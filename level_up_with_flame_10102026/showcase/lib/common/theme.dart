import 'package:material_ui/material_ui.dart';

/// Dark, premium fintech look shared by every demo. No branding.
abstract final class Pal {
  static const bg = Color(0xFF0B0B0F);
  static const surface = Color(0xFF15151C);
  static const surface2 = Color(0xFF1E1E27);
  static const line = Color(0xFF2A2A35);
  static const text = Color(0xFFF4F5F7);
  static const muted = Color(0xFF9A9CA8);
  static const gold = Color(0xFFF2C766);
  static const goldDeep = Color(0xFFC8902E);
  static const green = Color(0xFF5BD69A);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF1C1), Color(0xFFF2C766), Color(0xFFC8902E)],
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Pal.gold,
      brightness: Brightness.dark,
      primary: Pal.gold,
      onPrimary: const Color(0xFF111114),
      surface: Pal.surface,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Pal.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: Pal.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pal.gold,
        foregroundColor: const Color(0xFF111114),
        disabledBackgroundColor: Pal.surface2,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Pal.surface,
      selectedColor: Pal.gold.withValues(alpha: 0.18),
      side: const BorderSide(color: Pal.line),
      labelStyle: const TextStyle(fontFamily: 'Inter', color: Pal.text, fontWeight: FontWeight.w600),
    ),
  );
}

/// Rounded dark card used across screens.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Pal.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Pal.line),
        ),
        child: Padding(padding: padding, child: child),
      );
}
