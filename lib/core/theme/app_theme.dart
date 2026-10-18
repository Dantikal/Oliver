import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppPalette.light);
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);
  static ThemeData sand() => _build(Brightness.light, AppPalette.sand);

  static ThemeData _build(Brightness b, AppPalette p) {
    final scheme =
        ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b)
            .copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.leaf,
      surface: p.surface,
      onSurface: p.text,
      error: AppColors.danger,
    );

    // Unbounded — широкий геометричный гротеск для заголовков.
    TextStyle head(double size, FontWeight w) => GoogleFonts.unbounded(
          fontSize: size * 0.86,
          fontWeight: w,
          color: p.text,
          letterSpacing: -0.6,
          height: 1.14,
        );
    TextStyle body(double size, FontWeight w, [Color? c]) =>
        GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          color: c ?? p.text,
          height: 1.38,
        );

    final textTheme = TextTheme(
      displayLarge: head(40, FontWeight.w700),
      displayMedium: head(32, FontWeight.w700),
      displaySmall: head(27, FontWeight.w600),
      headlineLarge: head(25, FontWeight.w600),
      headlineMedium: head(21, FontWeight.w600),
      headlineSmall: head(18, FontWeight.w600),
      titleLarge: body(19, FontWeight.w800),
      titleMedium: body(16, FontWeight.w700),
      titleSmall: body(14, FontWeight.w700),
      bodyLarge: body(16, FontWeight.w500),
      bodyMedium: body(14, FontWeight.w500),
      bodySmall: body(12.5, FontWeight.w500, p.textSecondary),
      labelLarge: body(15.5, FontWeight.w700),
      labelMedium: body(13, FontWeight.w600),
      labelSmall: body(11, FontWeight.w700),
    );

    const field = AppRadius.mdAll;
    const rounded = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      fontFamily: GoogleFonts.manrope().fontFamily,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: p.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        hintStyle: body(15, FontWeight.w500, p.textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: const OutlineInputBorder(
            borderRadius: field, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: field, borderSide: BorderSide(color: p.border)),
        disabledBorder: const OutlineInputBorder(
            borderRadius: field, borderSide: BorderSide.none),
        focusedBorder: const OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: AppColors.danger, width: 1.8),
        ),
        errorStyle: body(12.5, FontWeight.w600, AppColors.danger),
        counterStyle: body(12, FontWeight.w600, p.textTertiary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b == Brightness.dark ? p.surface3 : AppColors.ink,
        contentTextStyle: body(14, FontWeight.w600, Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        modalBarrierColor: Colors.black.withValues(alpha: 0.45),
        showDragHandle: true,
        dragHandleColor: p.surface3,
        dragHandleSize: const Size(44, 5),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl + 4)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? AppColors.primary : p.surface3,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        textStyle: body(15, FontWeight.w600),
        elevation: 12,
        shadowColor: p.shadow,
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(rounded)),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(rounded)),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(rounded)),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(rounded)),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(CircleBorder())),
      ),
      listTileTheme: const ListTileThemeData(shape: rounded),
      cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll)),
      dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll)),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      cupertinoOverrideTheme:
          const CupertinoThemeData(primaryColor: AppColors.primary),
    );
  }
}
