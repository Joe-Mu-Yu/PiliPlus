import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoThemeData;
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

abstract final class ThemeUtils {
  static const _cardShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _dialogShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(32)),
  );
  static const _sheetShape = RoundedSuperellipseBorder(
    borderRadius: Style.bottomSheetRadius,
  );
  static const _controlShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _popupShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _inputRadius = BorderRadius.all(Radius.circular(16));
  static const _snackBarShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  static late ThemeData lightTheme;

  static late ThemeData darkTheme;

  static late ThemeMode themeMode;

  static ThemeData get theme {
    if (themeMode == .dark ||
        (themeMode == .system &&
            PlatformDispatcher.instance.platformBrightness == .dark)) {
      return darkTheme;
    }
    return lightTheme;
  }

  static bool get isDarkMode => theme.isDark;

  static String themeUrl(bool isDark) =>
      'native.theme=${isDark ? 2 : 1}&night=${isDark ? 1 : 0}';

  /// Maps the app's effective Material roles to the roles used by MIUIX.
  /// Keeping this conversion in one place prevents Flutter-native MIUIX
  /// controls and Material fallbacks from drifting to different palettes.
  static miuix.MiuixColors getMiuixColors(ColorScheme scheme) {
    return miuix.mapMd3RolesToMiuixColors(
      miuix.MiuixMonetRoles(
        primary: scheme.primary,
        onPrimary: scheme.onPrimary,
        primaryFixed: scheme.primaryFixed,
        onPrimaryFixed: scheme.onPrimaryFixed,
        error: scheme.error,
        onError: scheme.onError,
        errorContainer: scheme.errorContainer,
        onErrorContainer: scheme.onErrorContainer,
        primaryContainer: scheme.primaryContainer,
        onPrimaryContainer: scheme.onPrimaryContainer,
        secondary: scheme.secondary,
        onSecondary: scheme.onSecondary,
        secondaryContainer: scheme.secondaryContainer,
        onSecondaryContainer: scheme.onSecondaryContainer,
        tertiaryContainer: scheme.tertiaryContainer,
        onTertiaryContainer: scheme.onTertiaryContainer,
        background: scheme.surfaceContainerLowest,
        onBackground: scheme.onSurface,
        surface: scheme.surface,
        onSurface: scheme.onSurface,
        surfaceVariant: scheme.surfaceContainerLow,
        surfaceContainer: scheme.surfaceContainer,
        surfaceContainerHigh: scheme.surfaceContainerHigh,
        surfaceContainerHighest: scheme.surfaceContainerHighest,
        outline: scheme.outline,
        outlineVariant: scheme.outlineVariant,
        onSurfaceVariant: scheme.onSurfaceVariant,
      ),
      dark: scheme.brightness == .dark,
    );
  }

  static TextStyle _textStyle(
    double fontSize,
    FontWeight fontWeight,
    String? fontFamily, {
    double? height,
  }) => TextStyle(
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    fontFamily: fontFamily,
  );

  static miuix.MiuixTextStyles getMiuixTextStyles() {
    final weight = Pref.appFontWeight;
    final family = FontUtils.fontFamily;
    return miuix.MiuixTextStyles(
      main: _textStyle(17, weight, family),
      paragraph: _textStyle(17, weight, family, height: 1.2),
      body1: _textStyle(16, weight, family),
      body2: _textStyle(14, weight, family),
      button: _textStyle(17, weight, family),
      footnote1: _textStyle(13, weight, family),
      footnote2: _textStyle(11, weight, family),
      headline1: _textStyle(17, weight, family),
      headline2: _textStyle(16, weight, family),
      subtitle: _textStyle(14, weight, family),
      title1: _textStyle(32, weight, family),
      title2: _textStyle(24, weight, family),
      title3: _textStyle(20, weight, family),
      title4: _textStyle(18, weight, family),
    );
  }

  static miuix.MiuixThemeData getMiuixThemeData(ThemeData theme) {
    return miuix.MiuixThemeData(
      colors: getMiuixColors(theme.colorScheme),
      textStyles: getMiuixTextStyles(),
      brightness: theme.brightness,
      // The user's precise weight is already baked into every style. Applying
      // a second platform adjustment would silently turn the default 350 into
      // 450 when Android's bold-text option is enabled.
      fontWeightAdjustment: 0,
    );
  }

  static TextTheme _materialTextTheme(
    FontWeight fontWeight,
    String? fontFamily,
  ) => TextTheme(
    displayLarge: _textStyle(32, fontWeight, fontFamily),
    displayMedium: _textStyle(24, fontWeight, fontFamily),
    displaySmall: _textStyle(20, fontWeight, fontFamily),
    headlineLarge: _textStyle(24, fontWeight, fontFamily),
    headlineMedium: _textStyle(20, fontWeight, fontFamily),
    headlineSmall: _textStyle(18, fontWeight, fontFamily),
    titleLarge: _textStyle(20, fontWeight, fontFamily),
    titleMedium: _textStyle(17, fontWeight, fontFamily),
    titleSmall: _textStyle(16, fontWeight, fontFamily),
    bodyLarge: _textStyle(17, fontWeight, fontFamily),
    bodyMedium: _textStyle(16, fontWeight, fontFamily),
    bodySmall: _textStyle(14, fontWeight, fontFamily),
    labelLarge: _textStyle(17, fontWeight, fontFamily),
    labelMedium: _textStyle(13, fontWeight, fontFamily),
    labelSmall: _textStyle(11, fontWeight, fontFamily),
  );

  static ThemeData getThemeData({
    required ColorScheme colorScheme,
    bool isDark = false,
  }) {
    colorScheme = _withMiuixNeutralSurfaces(colorScheme, isDark: isDark);
    if (isDark && Pref.isPureBlackTheme) {
      colorScheme = _pureBlackColorScheme(colorScheme);
    }
    final fontWeight = Pref.appFontWeight;
    final fontFamily = FontUtils.fontFamily;
    final textTheme = _materialTextTheme(fontWeight, fontFamily);
    final miuixColors = getMiuixColors(colorScheme);
    final buttonTextStyle = _textStyle(17, fontWeight, fontFamily);
    final commonButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(58, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      shape: const WidgetStatePropertyAll(_controlShape),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(buttonTextStyle),
    );
    const inputBorder = OutlineInputBorder(
      borderRadius: _inputRadius,
      borderSide: BorderSide.none,
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: _inputRadius,
      borderSide: BorderSide(color: miuixColors.primary, width: 2),
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      canvasColor: colorScheme.surfaceContainerLowest,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      fontFamily: fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: miuixColors.onBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          color: miuixColors.onBackground,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: miuixColors.surfaceContainer,
        indicatorColor: miuixColors.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: miuixColors.surface,
        elevation: 0,
        selectedItemColor: miuixColors.onSurfaceContainer,
        unselectedItemColor: miuixColors.onSurfaceContainer.withValues(
          alpha: 0.4,
        ),
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 26),
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
        enableFeedback: true,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: miuixColors.surface,
        elevation: 0,
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: miuixColors.onSurfaceContainer,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: miuixColors.onSurfaceContainer.withValues(alpha: 0.4),
        ),
        selectedIconTheme: IconThemeData(
          size: 28,
          color: miuixColors.onSurfaceContainer,
        ),
        unselectedIconTheme: IconThemeData(
          size: 28,
          color: miuixColors.onSurfaceContainer.withValues(alpha: 0.4),
        ),
        useIndicator: true,
        indicatorColor: miuixColors.surfaceContainerHigh,
        indicatorShape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        minWidth: 80,
        minExtendedWidth: 240,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        tileHeight: 56,
        backgroundColor: miuixColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: miuixColors.surfaceContainerHigh,
        indicatorShape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodyMedium?.copyWith(
            color: selected
                ? miuixColors.onSurfaceContainer
                : miuixColors.onSurfaceContainer.withValues(alpha: 0.7),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 28,
            color: selected
                ? miuixColors.onSurfaceContainer
                : miuixColors.onSurfaceContainer.withValues(alpha: 0.7),
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: _snackBarShape,
        insetPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        actionTextColor: miuixColors.onPrimary,
        actionBackgroundColor: miuixColors.primary,
        closeIconColor: miuixColors.onSurfaceContainerVariant,
        backgroundColor: miuixColors.onSecondaryVariant,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          color: miuixColors.secondaryVariant,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: miuixColors.surfaceContainer,
        elevation: 6,
        shape: _popupShape,
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
        textStyle: textTheme.bodyMedium?.copyWith(
          color: miuixColors.onSurfaceContainer,
        ),
      ),
      cardTheme: CardThemeData(
        color: miuixColors.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _cardShape,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: miuixColors.primary,
        linearTrackColor: miuixColors.secondaryContainer,
        linearMinHeight: 6,
        circularTrackColor: miuixColors.secondaryContainer,
        refreshBackgroundColor: isDark
            ? colorScheme.onInverseSurface
            : miuixColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(99)),
        strokeWidth: 4,
        strokeCap: StrokeCap.round,
        // ignore: deprecated_member_use
        year2023: false,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          color: miuixColors.onBackground,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: miuixColors.onBackground,
        ),
        backgroundColor: miuixColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: _dialogShape,
        barrierColor: miuixColors.windowDimming,
        insetPadding: const EdgeInsets.all(12),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: miuixColors.background,
        modalBackgroundColor: miuixColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shadowColor: Colors.transparent,
        modalBarrierColor: miuixColors.windowDimming,
        shape: _sheetShape,
        showDragHandle: true,
        dragHandleColor: miuixColors.onSurfaceVariantSummary.withValues(
          alpha: 0.2,
        ),
        dragHandleSize: const Size(40, 4),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 10,
        activeTrackColor: miuixColors.primary,
        inactiveTrackColor: miuixColors.sliderBackground,
        secondaryActiveTrackColor: miuixColors.primary.withValues(alpha: 0.5),
        disabledActiveTrackColor: miuixColors.disabledPrimarySlider,
        disabledInactiveTrackColor: miuixColors.disabledSecondary,
        thumbColor: miuixColors.onPrimary,
        disabledThumbColor: miuixColors.disabledOnPrimary,
        overlayColor: miuixColors.primary.withValues(alpha: 0.08),
        valueIndicatorColor: miuixColors.primary,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: miuixColors.onPrimary,
        ),
        showValueIndicator: ShowValueIndicator.onDrag,
        trackGap: 0,
        // ignore: deprecated_member_use
        year2023: false,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 14,
          color: miuixColors.secondaryVariant,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
        ),
        decoration: BoxDecoration(
          color: miuixColors.onSecondaryVariant,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: miuixColors.surfaceContainer,
        contentPadding: const EdgeInsets.all(16),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: miuixColors.onSecondaryContainer,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: miuixColors.primary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: miuixColors.onSurfaceVariantSummary,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: focusedInputBorder,
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: miuixColors.error, width: 2),
        ),
        focusedErrorBorder: focusedInputBorder.copyWith(
          borderSide: BorderSide(color: miuixColors.error, width: 2),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        selectionHandleColor: colorScheme.primary,
      ),
      switchTheme: SwitchThemeData(
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return miuixColors.disabledOnPrimary;
          }
          return states.contains(WidgetState.selected)
              ? miuixColors.onPrimary
              : miuixColors.onSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return miuixColors.disabledSecondary;
          }
          return states.contains(WidgetState.selected)
              ? miuixColors.primary
              : miuixColors.secondary;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: const CircleBorder(),
        side: BorderSide.none,
        checkColor: WidgetStatePropertyAll(miuixColors.onPrimary),
        fillColor: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          if (states.contains(WidgetState.disabled)) {
            return selected
                ? miuixColors.disabledPrimary
                : miuixColors.disabledSecondary;
          }
          return selected ? miuixColors.primary : miuixColors.secondary;
        }),
      ),
      radioTheme: RadioThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return miuixColors.disabledPrimary;
          }
          return states.contains(WidgetState.selected)
              ? miuixColors.primary
              : miuixColors.secondary;
        }),
        overlayColor: WidgetStatePropertyAll(
          miuixColors.primary.withValues(alpha: 0.08),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: miuixColors.surfaceContainer,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        iconColor: miuixColors.onSurfaceVariantActions,
        collapsedIconColor: miuixColors.onSurfaceVariantActions,
        textColor: miuixColors.onBackground,
        collapsedTextColor: miuixColors.onBackground,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 56,
        minVerticalPadding: 8,
        horizontalTitleGap: 12,
        titleAlignment: ListTileTitleAlignment.center,
        controlAffinity: ListTileControlAffinity.trailing,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: miuixColors.onBackground,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: miuixColors.onSurfaceVariantSummary,
        ),
        iconColor: miuixColors.onSurfaceVariantActions,
      ),
      dividerTheme: DividerThemeData(
        color: miuixColors.dividerLine,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        indicator: ShapeDecoration(
          color: miuixColors.surfaceContainer,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: miuixColors.onBackground,
        unselectedLabelColor: miuixColors.onSurfaceVariantSummary,
        labelStyle: textTheme.bodyMedium,
        unselectedLabelStyle: textTheme.bodyMedium,
        overlayColor: WidgetStatePropertyAll(
          miuixColors.onBackground.withValues(alpha: 0.06),
        ),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return miuixColors.disabledSecondary;
          }
          return states.contains(WidgetState.selected)
              ? miuixColors.surfaceContainerHigh
              : miuixColors.surfaceContainer;
        }),
        backgroundColor: miuixColors.surfaceContainer,
        disabledColor: miuixColors.disabledSecondary,
        selectedColor: miuixColors.surfaceContainerHigh,
        secondarySelectedColor: miuixColors.surfaceContainerHigh,
        deleteIconColor: miuixColors.onSurfaceVariantActions,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        checkmarkColor: miuixColors.primary,
        side: BorderSide(color: miuixColors.dividerLine),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: miuixColors.onSurfaceContainer,
        ),
        secondaryLabelStyle: textTheme.bodySmall?.copyWith(
          color: miuixColors.onSurfaceContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return miuixColors.disabledSecondary;
            }
            return states.contains(WidgetState.selected)
                ? miuixColors.surfaceContainerHigh
                : miuixColors.surfaceContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return miuixColors.disabledOnSecondary;
            }
            return states.contains(WidgetState.selected)
                ? miuixColors.onSurfaceContainer
                : miuixColors.onSurfaceVariantActions;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: miuixColors.dividerLine),
          ),
          shape: const WidgetStatePropertyAll(_controlShape),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(textTheme.bodySmall),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: miuixColors.error,
        textColor: miuixColors.onError,
        smallSize: miuix.MiuixBadgeDefaults.size,
        largeSize: miuix.MiuixBadgeDefaults.largeSize,
        textStyle: _textStyle(11, fontWeight, fontFamily, height: 16 / 11),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        foregroundColor: miuixColors.onPrimary,
        backgroundColor: miuixColors.primary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        shape: _controlShape,
        sizeConstraints: const BoxConstraints.tightFor(width: 60, height: 60),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(40)),
          shape: WidgetStatePropertyAll(CircleBorder()),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: commonButtonStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(miuixColors.primary),
          foregroundColor: WidgetStatePropertyAll(miuixColors.onPrimary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: commonButtonStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            miuixColors.secondaryVariant,
          ),
          foregroundColor: WidgetStatePropertyAll(
            miuixColors.onSecondaryVariant,
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: commonButtonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(
            miuixColors.onSecondaryVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: miuixColors.dividerLine),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: commonButtonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(miuixColors.primary),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
    return theme;
  }

  /// Deadliner's Miuix layer keeps the user's accent palette, but uses the
  /// HyperOS neutral surfaces and text colours for the app canvas and elevated
  /// containers. This prevents a yellow, green, or other preset from tinting
  /// supporting text such as video authors and statistics.
  /// Applying this before the component themes keeps pages, dialogs and bars
  /// visually coherent without replacing the user's selected seed colour.
  static ColorScheme _withMiuixNeutralSurfaces(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    if (isDark) {
      return scheme.copyWith(
        surface: Colors.black,
        onSurface: const Color(0xFFF2F2F2),
        onSurfaceVariant: const Color(0xFFA6A6A6),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF242424),
        surfaceContainer: const Color(0xFF242424),
        surfaceContainerHigh: const Color(0xFF242424),
        surfaceContainerHighest: const Color(0xFF2D2D2D),
        surfaceBright: const Color(0xFF242424),
        surfaceDim: const Color(0xFF242424),
        outline: const Color(0xFFA6A6A6),
        outlineVariant: const Color(0xFF393939),
      );
    }
    return scheme.copyWith(
      surface: const Color(0xFFF3F3F3),
      onSurface: const Color(0xFF191919),
      onSurfaceVariant: const Color(0xFF6F6F6F),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF3F3F3),
      surfaceContainer: Colors.white,
      surfaceContainerHigh: const Color(0xFFE8E8E8),
      surfaceContainerHighest: const Color(0xFFE8E8E8),
      surfaceBright: Colors.white,
      surfaceDim: const Color(0xFFE8E8E8),
      outline: const Color(0xFF6F6F6F),
      outlineVariant: const Color(0xFFE0E0E0),
    );
  }

  static ColorScheme _pureBlackColorScheme(ColorScheme colorScheme) {
    return colorScheme.copyWith(
      primary: colorScheme.primary.darken(0.1),
      onPrimary: colorScheme.onPrimary.darken(0.1),
      primaryContainer: colorScheme.primaryContainer.darken(0.1),
      onPrimaryContainer: colorScheme.onPrimaryContainer.darken(0.1),
      inversePrimary: colorScheme.inversePrimary.darken(0.1),
      secondary: colorScheme.secondary.darken(0.05),
      onSecondary: colorScheme.onSecondary.darken(0.05),
      secondaryContainer: colorScheme.secondaryContainer.darken(0.05),
      onSecondaryContainer: colorScheme.onSecondaryContainer.darken(0.05),
      error: colorScheme.error.darken(0.05),
      surface: Colors.black,
      onSurface: colorScheme.onSurface.darken(0.15),
      surfaceTint: colorScheme.surfaceTint.darken(),
      inverseSurface: colorScheme.inverseSurface.darken(),
      onInverseSurface: colorScheme.onInverseSurface.darken(),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: colorScheme.surfaceContainerLow.darken(0.75),
      surfaceContainer: colorScheme.surfaceContainer.darken(0.75),
      surfaceContainerHigh: colorScheme.surfaceContainerHigh.darken(0.7),
      surfaceContainerHighest: colorScheme.surfaceContainerHighest.darken(0.4),
    );
  }
}
