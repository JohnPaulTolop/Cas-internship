import 'package:flutter/material.dart';

class AppTheme {
  // Brand
  static const navy = Color(0xFF17324D);
  static const blue = Color(0xFF2563EB);
  static const deepBlue = Color(0xFF1D4ED8);
  static const sky = Color(0xFFDBEAFE);

  // Light surfaces
  static const background = Color(0xFFF5F7FB);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF8FAFC);
  static const surfaceBlue = Color(0xFFF4F8FF);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);

  // Text
  static const text = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);

  // States
  static const success = Color(0xFF16A36A);
  static const warning = Color(0xFFE69B19);
  static const danger = Color(0xFFDC4C64);
  static const purple = Color(0xFF7C5CE7);

  static const double contentMaxWidth = 1240;
  static const double cardRadius = 16;
  static const double controlRadius = 12;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: const Color(0xFF0EA5E9),
      surface: surface,
      error: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.standard,
      dividerColor: border,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: navy,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineMedium: const TextStyle(
          color: navy,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: const TextStyle(
          color: navy,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
        titleLarge: const TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
        ),
        titleMedium: const TextStyle(
          color: text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: const TextStyle(
          color: text,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: text,
          fontSize: 14.5,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          color: text,
          fontSize: 13,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: muted,
          fontSize: 11.5,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: subtle, fontSize: 12.5),
        labelStyle: const TextStyle(color: muted, fontSize: 12.5),
        floatingLabelStyle: const TextStyle(
          color: blue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: text,
          backgroundColor: surface,
          side: const BorderSide(color: borderStrong),
          textStyle: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: sky,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(
          color: text,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(surfaceSoft),
        headingTextStyle: TextStyle(
          color: Color(0xFF475569),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: text, fontSize: 12),
        dividerThickness: .7,
        horizontalMargin: 16,
        columnSpacing: 20,
        headingRowHeight: 46,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 60,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: blue,
        linearTrackColor: Color(0xFFEAF0F8),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(7),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? borderStrong
              : const Color(0xFFD8E0EA),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: muted,
        textColor: text,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minVerticalPadding: 8,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: borderStrong),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
