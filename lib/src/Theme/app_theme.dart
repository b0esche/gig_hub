import 'package:gig_hub/src/Data/app_imports.dart';

abstract class AppTheme {
  static final lightTheme = ThemeData.from(
    textTheme: _lightTextTheme,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Palette.glazedWhite,
      onPrimary: Palette.primalBlack,
      secondary: Palette.shadowGrey,
      onSecondary: Palette.concreteGrey,
      error: Palette.alarmRed,
      onError: Palette.balisticBlue,
      surface: Palette.glazedWhite,
      onSurface: Palette.primalBlack,
    ),
  ).copyWith(
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.transparent,
      foregroundColor: Palette.primalBlack,
      shape: StadiumBorder(
        side: BorderSide(width: 2.4, color: Palette.primalBlack),
      ),
      iconSize: 28,
    ),
  );

  static final darkTheme =
      ThemeData.from(
        textTheme: _darkTextTheme,
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: Palette.primalBlack,
          onPrimary: Palette.glazedWhite,
          secondary: Palette.concreteGrey,
          onSecondary: Palette.shadowGrey,
          error: Palette.alarmRed,
          onError: Palette.balisticBlue,
          surface: Palette.primalBlack,
          onSurface: Palette.glazedWhite,
        ),
      ).copyWith();

  static final TextTheme _lightTextTheme = TextTheme();

  static final TextTheme _darkTextTheme = TextTheme();
}
