import '../../Data/app_imports.dart';

List<String> genres = [
  // TECHNO & HARTE SPIELARTEN
  "Techno",
  "Hard Techno",
  "Melodic Techno",
  "Industrial",
  "Dark Techno",
  "Schranz",
  "Peaktime",
  "Groove",
  "Hardgroove",
  "ACID",
  "Hard Acid",
  "Detroit",

  // TEK / TEKKNO / HARTE STYLES
  "Tekno",
  "Tekk",
  "Hardtekk",
  "Bounce",
  "Hardstyle",
  "Rawstyle",
  "Jumpstyle",
  "Hard Bounce",
  "Terror",
  "Gabber",
  "Hardcore",
  "Happy Hardcore",
  "Frenchcore",
  "Hard Bass",
  "Uptempo",
  "Hitech",
  "Raggatek",

  // TRANCE & PSY
  "Trance",
  "Hard Trance",
  "Eurotrance",
  "Eurodance",
  "Psytrance",
  "Progressive Psytrance",
  "Darkpsy",
  "Forest",
  "Psytech",

  // HOUSE
  "House",
  "Hard House",
  "Tech House",
  "Deep House",
  "Progressive House",
  "Acid House",
  "G-House",
  "Witch House",

  // BASS / GARAGE / BREAKS
  "Bass",
  "Garage",
  "Speed Garage",
  "Miami Bass",
  "Ghetto Tech",
  "Jersey Club",
  "Dubstep",
  "Dub",
  "Trap",

  // DNB / JUNGLE
  "DnB",
  "Darkstep",
  "Jungle",
  "Ragga Jungle",

  // DISCO / SYNTH
  "Disco",
  "Synthwave",
  "Vaporwave",

  // POP & MODERNE SPIELARTEN
  "Hyperpop",
  "EDM",
  "IDM",
  "Experimental",
  "Minimal",

  // LATIN / AFRO
  "Afro Beats",
  "Reggaeton",
  "Dancehall",

  // SONSTIGES
  "Makina",
  "Downtempo",
];

class GenreBubble extends StatelessWidget {
  const GenreBubble({required this.genre, super.key});
  final String genre;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LiquidGlass(
          shape: LiquidRoundedRectangle(borderRadius: Radius.circular(16)),
          clipBehavior: Clip.hardEdge,
          glassContainsChild: true,
          settings: LiquidGlassSettings(
            blur: 1,
            refractiveIndex: 1,
            thickness: 10,
            lightIntensity: 8,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.shadowGrey, width: 0.85),
              color: Palette.gigGrey.o(0.35),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                genre,
                style: GoogleFonts.sometypeMono(
                  textStyle: TextStyle(
                    wordSpacing: -4,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Palette.shadowGrey,
                    decoration: TextDecoration.underline,
                    decorationColor: Palette.shadowGrey.o(0.35),
                    decorationThickness: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
