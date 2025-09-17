import 'package:gig_hub/src/Data/app_imports.dart';

class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.widget});

  final ProfileScreenDJ widget;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Palette.shadowGrey,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          widget.dj.info,
          style: TextStyle(color: Palette.primalBlack, fontSize: 14),
        ),
      ),
    );
  }
}
