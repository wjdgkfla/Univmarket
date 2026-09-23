import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Marketplace tokens: white ground, cool neutral greys, and the school color
/// as the single brand voice (primary actions, active tab, wordmark, prices
/// that are free, your own chat bubbles).
class AppColors extends ThemeExtension<AppColors> {
  final Color bg, surface, surface2, ink, inkSoft, inkFaint, line;
  final Color accent, accentDeep, accentInk, accentWash;
  final Color good, goodWash, warn, warnWash, bad, badWash;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.accent,
    required this.accentDeep,
    required this.accentInk,
    required this.accentWash,
    required this.good,
    required this.goodWash,
    required this.warn,
    required this.warnWash,
    required this.bad,
    required this.badWash,
  });

  /// Neutral brand before a school is known: ink carries the actions.
  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF2F3F5),
    ink: Color(0xFF17191C),
    inkSoft: Color(0xFF5B616B),
    inkFaint: Color(0xFF6E747E),
    line: Color(0xFFE6E8EB),
    accent: Color(0xFF17191C),
    accentDeep: Color(0xFF0B0C0E),
    accentInk: Color(0xFFFFFFFF),
    accentWash: Color(0xFFF2F3F5),
    good: Color(0xFF15803D),
    goodWash: Color(0xFFE3F4E8),
    warn: Color(0xFFB45309),
    warnWash: Color(0xFFFDF0DF),
    bad: Color(0xFFCC2A22),
    badWash: Color(0xFFFCE8E7),
  );

  static const dark = AppColors(
    bg: Color(0xFF111214),
    surface: Color(0xFF1B1C1F),
    surface2: Color(0xFF26282C),
    ink: Color(0xFFF1F2F4),
    inkSoft: Color(0xFFAEB3BB),
    inkFaint: Color(0xFF8C919A),
    line: Color(0xFF2E3034),
    accent: Color(0xFFF1F2F4),
    accentDeep: Color(0xFFFFFFFF),
    accentInk: Color(0xFF111214),
    accentWash: Color(0xFF26282C),
    good: Color(0xFF4ADE80),
    goodWash: Color(0xFF123322),
    warn: Color(0xFFF5A524),
    warnWash: Color(0xFF39280F),
    bad: Color(0xFFF87171),
    badWash: Color(0xFF3A1A17),
  );

  @override
  AppColors copyWith({Color? accent, Color? accentDeep, Color? accentWash}) =>
      AppColors(
        bg: bg,
        surface: surface,
        surface2: surface2,
        ink: ink,
        inkSoft: inkSoft,
        inkFaint: inkFaint,
        line: line,
        accent: accent ?? this.accent,
        accentDeep: accentDeep ?? this.accentDeep,
        accentInk: accentInk,
        accentWash: accentWash ?? this.accentWash,
        good: good,
        goodWash: goodWash,
        warn: warn,
        warnWash: warnWash,
        bad: bad,
        badWash: badWash,
      );

  // ponytail: snaps instead of tweening; themes only change at sign-in.
  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Launch school brand colors, keyed by `universities.short_name`.
/// [second] is the school's secondary color.
typedef SchoolColors = ({
  Color accent,
  Color accentDeep,
  Color accentWash,
  Color second,
});

const Map<String, SchoolColors> schoolColors = {
  'GMU': (
    accent: Color(0xFF006633),
    accentDeep: Color(0xFF004D26),
    accentWash: Color(0xFFE6F2EA),
    second: Color(0xFFFFCC33),
  ),
  'GWU': (
    accent: Color(0xFF033C5A),
    accentDeep: Color(0xFF022B41),
    accentWash: Color(0xFFE4ECF1),
    second: Color(0xFFAA9868),
  ),
};

/// One radius scale: photos 8, controls 10, sheets 16, chips full pill.
class AppRadius {
  static const photo = 8.0;
  static const control = 10.0;
  static const sheet = 16.0;
  static const pill = 999.0;
}

/// Horizontal page gutter.
const double gutter = 16;

const _tabular = [FontFeature.tabularFigures()];

/// Price text: bold, tabular figures, and "Free" in the school color.
Widget priceText(
  BuildContext context,
  int price, {
  double size = 16,
  FontWeight weight = FontWeight.w700,
}) {
  final c = context.colors;
  final free = price == 0;
  return Text(
    free ? 'Free' : '\$$price',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: free ? c.accent : c.ink,
      letterSpacing: -0.2,
      fontFeatures: _tabular,
    ),
  );
}

/// Screen title for top-level tabs (iOS large-title scale).
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(gutter, 2, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.15,
                color: context.colors.ink,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Full theme from a palette. Used for the campus markets and, with the
/// neutral palette, for sign-in, loading, and update-required screens.
ThemeData buildTheme(AppColors c) {
  final radius = BorderRadius.circular(AppRadius.control);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: c.accent).copyWith(
      primary: c.accent,
      onPrimary: c.accentInk,
      secondaryContainer: c.accentWash,
      onSecondaryContainer: c.accentDeep,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSoft,
      surfaceTint: Colors.transparent,
      outline: c.line,
      outlineVariant: c.line,
      error: c.bad,
    ),
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    splashFactory: defaultTargetPlatform == TargetPlatform.iOS
        ? NoSplash.splashFactory
        : InkSparkle.splashFactory,
  );
  // Material 3 tracking is tuned for Roboto; SF wants tighter spacing.
  TextStyle? track(TextStyle? s) {
    final size = s?.fontSize ?? 14;
    return s?.copyWith(
      letterSpacing: size >= 20
          ? 0
          : size >= 17
          ? -0.4
          : size >= 15
          ? -0.2
          : -0.1,
      color: c.ink,
    );
  }

  final t = base.textTheme;
  final textTheme = t.copyWith(
    displayLarge: track(t.displayLarge),
    displayMedium: track(t.displayMedium),
    displaySmall: track(t.displaySmall),
    headlineLarge: track(t.headlineLarge),
    headlineMedium: track(t.headlineMedium),
    headlineSmall: track(t.headlineSmall),
    titleLarge: track(t.titleLarge),
    titleMedium: track(t.titleMedium),
    titleSmall: track(t.titleSmall),
    bodyLarge: track(t.bodyLarge),
    bodyMedium: track(t.bodyMedium),
    bodySmall: track(t.bodySmall),
    labelLarge: track(t.labelLarge),
    labelMedium: track(t.labelMedium),
    labelSmall: track(t.labelSmall),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: radius);
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      shape: Border(bottom: BorderSide(color: c.line, width: 0.5)),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 0.5, space: 0.5),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentInk,
        disabledBackgroundColor: c.surface2,
        disabledForegroundColor: c.inkFaint,
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        disabledForegroundColor: c.inkFaint,
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: c.line, width: 1),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: c.inkSoft, fontSize: 15),
      floatingLabelStyle: TextStyle(color: c.inkSoft),
      hintStyle: TextStyle(color: c.inkFaint, fontSize: 15),
      helperStyle: TextStyle(color: c.inkSoft, fontSize: 12.5),
      border: border(c.line),
      enabledBorder: border(c.line),
      disabledBorder: border(c.line),
      focusedBorder: border(c.ink, 1.5),
      errorBorder: border(c.bad),
      focusedErrorBorder: border(c.bad, 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface2,
      selectedColor: c.ink,
      disabledColor: c.surface2,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: c.ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.bg,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.bg, fontSize: 14),
      actionTextColor: c.bg,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      contentTextStyle: TextStyle(fontSize: 15, height: 1.4, color: c.inkSoft),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    bannerTheme: MaterialBannerThemeData(
      backgroundColor: c.warnWash,
      contentTextStyle: TextStyle(color: c.ink, fontSize: 14),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.inkSoft, textColor: c.ink),
    iconTheme: IconThemeData(color: c.ink),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(c.surface)),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.accent),
  );
}

/// Neutral UnivMarket theme for screens shown before the school is known
/// (sign-in, loading, errors, update required).
ThemeData brandTheme() => buildTheme(AppColors.light);

extension AppColorsOf on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
