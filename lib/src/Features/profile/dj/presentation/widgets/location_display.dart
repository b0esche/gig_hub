import 'package:gig_hub/src/Data/app_imports.dart';

class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key, required this.widget});

  final ProfileScreenDJ widget;

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.dj.city,
      style: GoogleFonts.sometypeMono(
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Palette.primalBlack,
        ),
      ),
    );
  }
}
