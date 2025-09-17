import 'package:gig_hub/src/Data/app_imports.dart';

abstract class Palette {
  static final Color primalBlack = const Color.fromARGB(255, 33, 33, 33);
  static final Color glazedWhite = const Color.fromARGB(255, 248, 248, 248);
  static final Color gigGrey = const Color.fromARGB(255, 155, 155, 155);
  static final Color concreteGrey = const Color.fromARGB(255, 205, 205, 205);
  static final Color shadowGrey = const Color.fromARGB(255, 233, 233, 234);
  static final Color forgedGold = const Color.fromARGB(255, 187, 175, 99);
  static final Color alarmRed = const Color.fromARGB(255, 235, 72, 72);
  static final Color okGreen = const Color.fromARGB(255, 25, 255, 144);
  static final Color balisticBlue = const Color.fromARGB(255, 64, 112, 245);
  static final Color favoriteRed = const Color.fromARGB(255, 238, 82, 71);
}

extension ColorOpacity on Color {
  Color o(double opacity) => withValues(alpha: opacity);
}
