import 'package:flutter/material.dart';

/// Spacing scale (4-point grid).
abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Corner radii.
abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// Window size classes, following Material guidance.
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 900.0;
  static const large = 1200.0;

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < medium;
  static bool isExpanded(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= expanded;
}

/// Brand palette: deep emerald, warm neutrals, restrained gold and slate.
abstract final class Brand {
  static const emerald = Color(0xFF0B5D4B);
  static const emeraldDeep = Color(0xFF063D30);
  static const emeraldSoft = Color(0xFFD3EDE3);
  static const gold = Color(0xFF8F6514);
  static const goldSoft = Color(0xFFF6E8CA);
  static const slate = Color(0xFF3E5C76);
  static const slateSoft = Color(0xFFDCE6F0);
  static const canvas = Color(0xFFFAF7F2);
  static const ink = Color(0xFF1C211F);
  static const inkMuted = Color(0xFF4F5752);

  /// Avatar backgrounds; all pass 4.5:1 with white initials.
  static const avatarColors = [
    Color(0xFF0B5D4B),
    Color(0xFF3E5C76),
    Color(0xFF8F4E2A),
    Color(0xFF5B4B8A),
    Color(0xFF7A5A12),
    Color(0xFF1F6B78),
    Color(0xFF8A3B4F),
    Color(0xFF4A6B2E),
  ];
}

const _font = 'PlusJakartaSans';

ColorScheme _scheme() => const ColorScheme(
  brightness: Brightness.light,
  primary: Brand.emerald,
  onPrimary: Colors.white,
  primaryContainer: Brand.emeraldSoft,
  onPrimaryContainer: Color(0xFF04261D),
  secondary: Brand.gold,
  onSecondary: Colors.white,
  secondaryContainer: Brand.goldSoft,
  onSecondaryContainer: Color(0xFF3B2700),
  tertiary: Brand.slate,
  onTertiary: Colors.white,
  tertiaryContainer: Brand.slateSoft,
  onTertiaryContainer: Color(0xFF102A43),
  error: Color(0xFFB3261E),
  onError: Colors.white,
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: Brand.canvas,
  onSurface: Brand.ink,
  onSurfaceVariant: Brand.inkMuted,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF5F1EA),
  surfaceContainer: Color(0xFFEFEAE1),
  surfaceContainerHigh: Color(0xFFE9E3D8),
  surfaceContainerHighest: Color(0xFFE2DBCF),
  outline: Color(0xFF747C76),
  outlineVariant: Color(0xFFDAD4C8),
  inverseSurface: Color(0xFF2E3330),
  onInverseSurface: Color(0xFFF1EEE8),
  inversePrimary: Color(0xFF8FD3B9),
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

TextTheme _text(ColorScheme s) {
  TextStyle t(double size, double height, FontWeight w, {double spacing = 0}) =>
      TextStyle(
        fontFamily: _font,
        fontSize: size,
        height: height / size,
        fontWeight: w,
        letterSpacing: spacing,
        color: s.onSurface,
      );
  return TextTheme(
    displaySmall: t(36, 42, FontWeight.w800, spacing: -0.6),
    headlineMedium: t(28, 34, FontWeight.w700, spacing: -0.4),
    headlineSmall: t(24, 30, FontWeight.w700, spacing: -0.3),
    titleLarge: t(20, 26, FontWeight.w700, spacing: -0.2),
    titleMedium: t(16, 22, FontWeight.w600),
    titleSmall: t(14, 20, FontWeight.w600),
    bodyLarge: t(16, 24, FontWeight.w400),
    bodyMedium: t(14, 21, FontWeight.w400),
    bodySmall: t(12.5, 18, FontWeight.w400),
    labelLarge: t(14, 20, FontWeight.w600),
    labelMedium: t(12.5, 16, FontWeight.w600),
    labelSmall: t(11.5, 16, FontWeight.w600, spacing: 0.2),
  );
}

ThemeData buildTheme() {
  final s = _scheme();
  final text = _text(s);
  final shape12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );
  const buttonSize = Size(48, 48);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

  return ThemeData(
    useMaterial3: true,
    colorScheme: s,
    fontFamily: _font,
    textTheme: text,
    scaffoldBackgroundColor: s.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    focusColor: s.primary.withValues(alpha: 0.16),
    hoverColor: s.primary.withValues(alpha: 0.06),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(
      color: s.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: s.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: s.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape12,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: buttonSize,
            padding: buttonPadding,
            shape: shape12,
            textStyle: text.labelLarge,
            foregroundColor: s.onSurface,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: s.primary, width: 2)
                  : BorderSide(color: s.outline.withValues(alpha: 0.6)),
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: shape12,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      extendedTextStyle: text.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
      floatingLabelStyle: text.labelMedium?.copyWith(color: s.primary),
      hintStyle: text.bodyMedium?.copyWith(
        color: s.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      helperStyle: text.bodySmall?.copyWith(color: s.onSurfaceVariant),
      errorStyle: text.bodySmall?.copyWith(color: s.error),
      helperMaxLines: 3,
      errorMaxLines: 3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: s.outline.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: s.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: s.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: s.error, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: s.surfaceContainerLowest,
      selectedColor: s.primaryContainer,
      checkmarkColor: s.onPrimaryContainer,
      labelStyle: text.labelMedium,
      // A clear ring for keyboard focus; selected chips keep a quiet edge.
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: s.primary, width: 2);
        }
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: s.primaryContainer);
        }
        return BorderSide(color: s.outlineVariant);
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: s.surfaceContainerLowest,
      indicatorColor: s.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? s.onSurface
              : s.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? s.onPrimaryContainer
              : s.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: s.surface,
      indicatorColor: s.primaryContainer,
      selectedIconTheme: IconThemeData(color: s.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: s.onSurfaceVariant),
      selectedLabelTextStyle: text.labelMedium?.copyWith(color: s.onSurface),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(
        color: s.onSurfaceVariant,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: s.onInverseSurface),
      actionTextColor: s.inversePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      width: null,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surfaceContainerLowest,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall?.copyWith(color: s.onSurfaceVariant),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: s.primaryContainer,
        selectedForegroundColor: s.onPrimaryContainer,
        textStyle: text.labelLarge,
        minimumSize: const Size(48, 44),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodySmall?.copyWith(color: s.onInverseSurface),
      decoration: BoxDecoration(
        color: s.inverseSurface,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: GentlePageTransitionsBuilder(),
        TargetPlatform.iOS: GentlePageTransitionsBuilder(),
        TargetPlatform.macOS: GentlePageTransitionsBuilder(),
        TargetPlatform.windows: GentlePageTransitionsBuilder(),
        TargetPlatform.linux: GentlePageTransitionsBuilder(),
        TargetPlatform.fuchsia: GentlePageTransitionsBuilder(),
      },
    ),
  );
}

/// A short fade-and-rise page transition that turns off entirely when the
/// platform requests reduced motion.
class GentlePageTransitionsBuilder extends PageTransitionsBuilder {
  const GentlePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Animation duration that respects reduced motion.
Duration motion(BuildContext context, [int ms = 220]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);
