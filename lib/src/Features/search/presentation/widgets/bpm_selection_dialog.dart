import 'package:gig_hub/src/Data/app_imports.dart';

class BpmSelectionDialog extends StatefulWidget {
  final List<int>? intialSelectedBpm;

  const BpmSelectionDialog({super.key, required this.intialSelectedBpm});

  @override
  State<BpmSelectionDialog> createState() => _BpmSelectionDialogState();
}

class _BpmSelectionDialogState extends State<BpmSelectionDialog> {
  RangeValues bpmRange = const RangeValues(80, 140);

  @override
  void initState() {
    super.initState();
    if (widget.intialSelectedBpm != null &&
        widget.intialSelectedBpm!.length == 2) {
      bpmRange = RangeValues(
        widget.intialSelectedBpm![0].toDouble(),
        widget.intialSelectedBpm![1].toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Palette.primalBlack.o(0.7),
      surfaceTintColor: Palette.forgedGold,
      elevation: 0.6,
      shadowColor: Palette.forgedGold.o(0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          LiquidGlass(
            shape: LiquidRoundedRectangle(borderRadius: Radius.circular(24)),
            settings: LiquidGlassSettings(thickness: 16, refractiveIndex: 1.2),
            child: SizedBox(
              height: 160,
              width: 300,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: Palette.shadowGrey.o(0.6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        '${bpmRange.start.round()} - ${bpmRange.end.round()} bpm',
                        style: GoogleFonts.sometypeMono(
                          textStyle: TextStyle(
                            color: Palette.primalBlack,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          showValueIndicator: ShowValueIndicator.never,
                        ),
                        child: LiquidGlass(
                          shape: LiquidRoundedRectangle(
                            borderRadius: Radius.circular(24),
                          ),
                          settings: LiquidGlassSettings(
                            thickness: 10,
                            blur: 20,
                            lightIntensity: 1.2,
                            glassColor: Palette.forgedGold.o(0.25),
                            refractiveIndex: 1.3,
                            chromaticAberration: 16,
                          ),
                          child: RangeSlider(
                            min: 60,
                            max: 200,
                            divisions: 140,
                            labels: RangeLabels(
                              bpmRange.start.round().toString(),
                              bpmRange.end.round().toString(),
                            ),
                            values: bpmRange,
                            activeColor: Palette.forgedGold.o(0.9),
                            inactiveColor: Palette.primalBlack.o(0.3),
                            onChanged: (RangeValues values) {
                              setState(() {
                                bpmRange = values;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 12),
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  border: BoxBorder.all(
                    color: Palette.shadowGrey.o(0.7),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(
                      borderRadius: Radius.circular(24),
                    ),
                    glassContainsChild: false,

                    child: IconButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop([bpmRange.start.round(), bpmRange.end.round()]);
                      },
                      icon: Icon(
                        Icons.check,
                        color: Palette.forgedGold,
                        size: 18,
                        shadows: [
                          Shadow(
                            offset: Offset(0.3, 0.3),
                            blurRadius: 2,

                            color: Palette.primalBlack.o(0.65),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
