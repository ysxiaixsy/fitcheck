import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const double xxs = 2,
      xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 20,
      xxl = 24,
      xxxl = 32,
      huge = 40,
      touch = 48;
}

abstract final class AppRadius {
  static const double sm = 8, md = 12, lg = 16, xl = 20, full = 999;
}

abstract final class AppSize {
  static const double touch = 48,
      iconSmall = 16,
      iconMedium = 20,
      icon = 24,
      illustration = 36,
      dateCircle = 36,
      navPillWidth = 56,
      navPillHeight = 32,
      header = 56,
      contentWidth = 600,
      stroke = 1,
      focus = 2;
}

@immutable
class FitCheckColors extends ThemeExtension<FitCheckColors> {
  const FitCheckColors({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.pressed,
    required this.accent,
    required this.accentSubtle,
    required this.successSubtle,
    required this.warningSubtle,
    required this.dangerSubtle,
    required this.primary,
    required this.secondary,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.border,
    required this.borderStrong,
  });
  final Color canvas,
      surface,
      subtle,
      pressed,
      accent,
      accentSubtle,
      successSubtle,
      warningSubtle,
      dangerSubtle,
      primary,
      secondary,
      onAccent,
      success,
      warning,
      danger,
      border,
      borderStrong;
  static const light = FitCheckColors(
    canvas: Color(0xFFF6F6F5),
    surface: Color(0xFFFFFFFF),
    subtle: Color(0xFFEDEDEC),
    pressed: Color(0xFFDEDEDC),
    accent: Color(0xFF3448D6),
    accentSubtle: Color(0xFFEEF1FF),
    successSubtle: Color(0xFFDCF2E3),
    warningSubtle: Color(0xFFFBEFD0),
    dangerSubtle: Color(0xFFFCE4E1),
    primary: Color(0xFF0F0F0E),
    secondary: Color(0xFF5E5E5A),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF1E6B3C),
    warning: Color(0xFF7D5200),
    danger: Color(0xFFA42D22),
    border: Color(0xFFDEDEDC),
    borderStrong: Color(0xFF7A7A76),
  );
  static const dark = FitCheckColors(
    canvas: Color(0xFF0F0F0E),
    surface: Color(0xFF191918),
    subtle: Color(0xFF2C2C2A),
    pressed: Color(0xFF454542),
    accent: Color(0xFF98A9FF),
    accentSubtle: Color(0xFF1A2363),
    successSubtle: Color(0xFF0F3520),
    warningSubtle: Color(0xFF3D2900),
    dangerSubtle: Color(0xFF4F140F),
    primary: Color(0xFFF6F6F5),
    secondary: Color(0xFFA1A19D),
    onAccent: Color(0xFF10163F),
    success: Color(0xFF86D3A3),
    warning: Color(0xFFF0C46A),
    danger: Color(0xFFF5A49B),
    border: Color(0xFF2C2C2A),
    borderStrong: Color(0xFF7A7A76),
  );
  static FitCheckColors of(BuildContext context) =>
      Theme.of(context).extension<FitCheckColors>()!;
  @override
  FitCheckColors copyWith({
    Color? canvas,
    Color? surface,
    Color? subtle,
    Color? pressed,
    Color? accent,
    Color? accentSubtle,
    Color? successSubtle,
    Color? warningSubtle,
    Color? dangerSubtle,
    Color? primary,
    Color? secondary,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? border,
    Color? borderStrong,
  }) => FitCheckColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    subtle: subtle ?? this.subtle,
    pressed: pressed ?? this.pressed,
    accent: accent ?? this.accent,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    successSubtle: successSubtle ?? this.successSubtle,
    warningSubtle: warningSubtle ?? this.warningSubtle,
    dangerSubtle: dangerSubtle ?? this.dangerSubtle,
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    onAccent: onAccent ?? this.onAccent,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
  );
  @override
  FitCheckColors lerp(covariant FitCheckColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FitCheckColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      subtle: mix(subtle, other.subtle),
      pressed: mix(pressed, other.pressed),
      accent: mix(accent, other.accent),
      accentSubtle: mix(accentSubtle, other.accentSubtle),
      successSubtle: mix(successSubtle, other.successSubtle),
      warningSubtle: mix(warningSubtle, other.warningSubtle),
      dangerSubtle: mix(dangerSubtle, other.dangerSubtle),
      primary: mix(primary, other.primary),
      secondary: mix(secondary, other.secondary),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
    );
  }
}

abstract final class FitCheckTheme {
  static final light = _build(Brightness.light, FitCheckColors.light);
  static final dark = _build(Brightness.dark, FitCheckColors.dark);
  static ThemeData _build(Brightness brightness, FitCheckColors c) {
    TextStyle type(
      double size,
      double line,
      FontWeight weight, {
      double spacing = 0,
    }) => TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: c.primary,
    );
    final text = TextTheme(
      displayLarge: type(32, 40, FontWeight.w700, spacing: -0.5),
      headlineLarge: type(24, 32, FontWeight.w700),
      titleLarge: type(18, 24, FontWeight.w600),
      bodyLarge: type(16, 24, FontWeight.w400),
      bodyMedium: type(16, 24, FontWeight.w400),
      bodySmall: type(14, 20, FontWeight.w400),
      labelLarge: type(16, 24, FontWeight.w600),
      labelMedium: type(14, 20, FontWeight.w600),
      labelSmall: type(12, 16, FontWeight.w600, spacing: 0.1),
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.accent,
          brightness: brightness,
        ).copyWith(
          primary: c.accent,
          onPrimary: c.onAccent,
          primaryContainer: c.accentSubtle,
          onPrimaryContainer: c.primary,
          secondary: c.secondary,
          onSecondary: c.surface,
          secondaryContainer: c.subtle,
          onSecondaryContainer: c.primary,
          tertiary: c.success,
          onTertiary: c.surface,
          tertiaryContainer: c.successSubtle,
          onTertiaryContainer: c.success,
          error: c.danger,
          onError: c.surface,
          errorContainer: c.dangerSubtle,
          onErrorContainer: c.danger,
          surface: c.surface,
          onSurface: c.primary,
          onSurfaceVariant: c.secondary,
          surfaceContainerLowest: c.canvas,
          surfaceContainerLow: c.canvas,
          surfaceContainer: c.surface,
          surfaceContainerHigh: c.subtle,
          surfaceContainerHighest: c.pressed,
          outline: c.borderStrong,
          outlineVariant: c.border,
          inverseSurface: c.primary,
          onInverseSurface: c.canvas,
          inversePrimary: c.accent,
          surfaceTint: c.surface,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      fontFamily: 'Plus Jakarta Sans',
      textTheme: text,
      extensions: [c],
      dividerColor: c.border,
      disabledColor: c.secondary,
      iconTheme: IconThemeData(color: c.primary, size: AppSize.icon),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(AppSize.touch, AppSize.touch),
          shape: shape,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxl,
            vertical: AppSpace.md,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(AppSize.touch, AppSize.touch),
          shape: shape,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.borderStrong),
          minimumSize: const Size(AppSize.touch, AppSize.touch),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSize.touch),
          foregroundColor: c.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: text.bodyMedium,
        contentPadding: const EdgeInsets.all(AppSpace.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.accent, width: AppSize.focus),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: c.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primary,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.canvas),
      ),
    );
  }
}
