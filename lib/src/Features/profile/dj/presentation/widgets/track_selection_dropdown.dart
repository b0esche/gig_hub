import 'package:gig_hub/src/Data/app_imports.dart';

class TrackSelectionDropdown extends StatelessWidget {
  const TrackSelectionDropdown({
    super.key,
    required this.userTrackList,
    required this.label,
    required this.selectedTrack,
    required this.onChanged,
  });

  final List<SoundcloudTrack> userTrackList;
  final String label;
  final SoundcloudTrack? selectedTrack;
  final Function(SoundcloudTrack? p1) onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.sometypeMono(
              textStyle: TextStyle(
                fontSize: 15,
                color: Palette.glazedWhite,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Palette.glazedWhite,
                decorationStyle: TextDecorationStyle.dotted,
                decorationThickness: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 298,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Palette.glazedWhite, width: 1),
              borderRadius: BorderRadius.circular(8),
              color: Palette.glazedWhite.o(0.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SoundcloudTrack>(
                borderRadius: BorderRadius.circular(8),
                dropdownColor: Palette.primalBlack.o(0.85),
                iconEnabledColor: Palette.glazedWhite,
                value: selectedTrack,
                isExpanded: true,
                hint: Text(
                  AppLocale.selectTrack.getString(context),
                  style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
                ),
                style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
                items:
                    userTrackList.map((track) {
                      return DropdownMenuItem<SoundcloudTrack>(
                        value: track,
                        child: Text(
                          track.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Palette.concreteGrey,
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
