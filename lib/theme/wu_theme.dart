import 'package:flutter/material.dart';

/// 统一的视觉 token：颜色、间距、圆角、文字层级。
/// 整体是低饱和的纸感配色，尽量少的边框与阴影，留白优先。
/// 主题色不使用 Material 默认紫色。
@immutable
class WuColors extends ThemeExtension<WuColors> {
  const WuColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.danger,
    required this.scrim,
  });

  /// 页面底色（米白纸面 / 深墨）
  final Color background;

  /// 卡片、输入框底色
  final Color surface;

  /// 次级区域底色（搜索框、标签底）
  final Color surfaceAlt;

  /// 主文字
  final Color ink;

  /// 次要文字
  final Color inkSecondary;

  /// 辅助文字、占位符
  final Color inkTertiary;

  /// 分割线
  final Color line;

  /// 强调色（抹茶灰绿）
  final Color accent;

  /// 强调色的浅底
  final Color accentSoft;

  /// 强调色上的文字
  final Color onAccent;

  /// 危险操作（陶土红）
  final Color danger;

  /// 弹窗遮罩
  final Color scrim;

  static const WuColors light = WuColors(
    background: Color(0xFFF4F1E9),
    surface: Color(0xFFFCFAF4),
    surfaceAlt: Color(0xFFEDEAE1),
    ink: Color(0xFF2B2A26),
    inkSecondary: Color(0xFF605D55),
    inkTertiary: Color(0xFF9A958A),
    line: Color(0xFFDED9CC),
    accent: Color(0xFF6C7A61),
    accentSoft: Color(0xFFE2E6DA),
    onAccent: Color(0xFFF9F8F3),
    danger: Color(0xFF9C5F55),
    scrim: Color(0x66242220),
  );

  static const WuColors dark = WuColors(
    background: Color(0xFF161614),
    surface: Color(0xFF1E1E1B),
    surfaceAlt: Color(0xFF262622),
    ink: Color(0xFFE7E3D9),
    inkSecondary: Color(0xFFA6A196),
    inkTertiary: Color(0xFF77726A),
    line: Color(0xFF302F2A),
    accent: Color(0xFF97A98B),
    accentSoft: Color(0xFF2B3227),
    onAccent: Color(0xFF1A1A17),
    danger: Color(0xFFC98A7F),
    scrim: Color(0xB30C0C0B),
  );

  @override
  WuColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? danger,
    Color? scrim,
  }) {
    return WuColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  WuColors lerp(ThemeExtension<WuColors>? other, double t) {
    if (other is! WuColors) return this;
    return WuColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// 间距与圆角常量，保持全应用一致。
class WuSpace {
  WuSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusS = 6;
  static const double radiusM = 10;
  static const double radiusL = 14;

  static const double contentMaxWidth = 760;
  static const double wideBreakpoint = 900;
  static const double sidebarWidth = 232;
}

/// 主题构建。
class WuTheme {
  WuTheme._();

  static ThemeData build(Brightness brightness) {
    final colors = brightness == Brightness.light ? WuColors.light : WuColors.dark;
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        surface: colors.surface,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        error: colors.danger,
      ),
    );

    final textTheme = TextTheme(
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: colors.ink, height: 1.3),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: colors.ink, height: 1.35),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: colors.ink, height: 1.4),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.ink, height: 1.4),
      bodyLarge: TextStyle(fontSize: 15, color: colors.ink, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, color: colors.inkSecondary, height: 1.6),
      bodySmall: TextStyle(fontSize: 12.5, color: colors.inkTertiary, height: 1.5),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.ink, height: 1.3),
      labelMedium: TextStyle(fontSize: 12.5, color: colors.inkSecondary, height: 1.3),
      labelSmall: TextStyle(fontSize: 11.5, color: colors.inkTertiary, height: 1.3),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      dividerColor: colors.line,
      splashColor: colors.accent.withValues(alpha: 0.06),
      highlightColor: colors.accent.withValues(alpha: 0.04),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WuSpace.radiusL),
          side: BorderSide(color: colors.line),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(WuSpace.radiusL)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(fontSize: 13.5, color: colors.background),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WuSpace.radiusS)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: TextStyle(fontSize: 14, color: colors.inkTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WuSpace.radiusS),
          borderSide: BorderSide(color: colors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WuSpace.radiusS),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WuSpace.radiusS),
          borderSide: BorderSide(color: colors.accent, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.inkSecondary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WuSpace.radiusS)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WuSpace.radiusS)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.line),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WuSpace.radiusS)),
        ),
      ),
      iconTheme: IconThemeData(color: colors.inkSecondary, size: 20),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return colors.inkTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accentSoft;
          return colors.surfaceAlt;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.surfaceAlt,
        thumbColor: colors.accent,
        overlayColor: colors.accent.withValues(alpha: 0.08),
        trackHeight: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surfaceAlt,
        linearMinHeight: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WuSpace.radiusM),
          side: BorderSide(color: colors.line),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(colors.inkTertiary.withValues(alpha: 0.4)),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
    );
  }
}

/// 快捷取色：context.colors
extension WuThemeContext on BuildContext {
  WuColors get colors => Theme.of(this).extension<WuColors>() ?? WuColors.light;

  TextTheme get texts => Theme.of(this).textTheme;
}
