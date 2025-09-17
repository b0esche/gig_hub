import 'package:gig_hub/src/Data/app_imports.dart';

class SearchFunctionCard extends StatefulWidget {
  final void Function(List<DJ>) onSearchResults;
  final void Function(bool) onSearchLoading;
  final void Function(List<int>?) onBpmRangeChanged;
  final void Function(List<String>?) onGenresChanged;

  const SearchFunctionCard({
    required this.onSearchResults,
    required this.onSearchLoading,
    required this.onBpmRangeChanged,
    required this.onGenresChanged,
    super.key,
  });

  @override
  State<SearchFunctionCard> createState() => _SearchFunctionCardState();
}

class _SearchFunctionCardState extends State<SearchFunctionCard> {
  List<String> selectedGenres = [];
  List<int>? selectedBpm;
  String? selectedCity;
  final TextEditingController genreController = TextEditingController();
  final TextEditingController bpmController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  void _showGenreDialog() async {
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return GenreSelectionDialog(initialSelectedGenres: selectedGenres);
      },
    );

    if (result != null && mounted) {
      setState(() {
        selectedGenres = result;
        genreController.text = selectedGenres.join(', ');
      });
      widget.onGenresChanged(selectedGenres);
    }
  }

  void _showBpmDialog() async {
    final List<int>? bpmValues = await showDialog<List<int>>(
      context: context,
      builder: (BuildContext context) {
        return BpmSelectionDialog(intialSelectedBpm: selectedBpm);
      },
    );
    if (bpmValues != null && mounted) {
      setState(() {
        selectedBpm = bpmValues;
        bpmController.text =
            bpmValues[0] == bpmValues[1]
                ? "${bpmValues[0]}"
                : "${bpmValues[0]} - ${bpmValues[1]}";
      });
      widget.onBpmRangeChanged(selectedBpm);
    }
  }

  Future<void> _search() async {
    widget.onSearchLoading(true);

    final repo = CachedFirestoreRepository();
    final results = await repo.searchDJs(
      city: selectedCity,
      genres: selectedGenres,
      bpmRange: selectedBpm,
    );

    widget.onSearchResults(results);

    if (mounted) {
      widget.onSearchLoading(false);
    }
  }

  @override
  void dispose() {
    genreController.dispose();
    bpmController.dispose();
    locationController.dispose();
    super.dispose();
  }

  bool isSearchCardCollapsed = false;
  bool showSearchContent = true;
  bool isSearchCardAnimating = false;
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onLongPress:
            !isSearchCardCollapsed
                ? () => setState(() {
                  showSearchContent = !showSearchContent;

                  isSearchCardCollapsed = !isSearchCardCollapsed;

                  isSearchCardAnimating = !isSearchCardAnimating;
                })
                : null,
        child: LiquidGlass(
          shape: LiquidRoundedRectangle(borderRadius: Radius.circular(16)),
          settings: LiquidGlassSettings(
            thickness: 18,
            refractiveIndex: 1.25,
            chromaticAberration: 0.25,
            glassColor: Palette.forgedGold.o(0.025),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: !isSearchCardCollapsed ? 300 : 110,
            height: !isSearchCardCollapsed ? 192 : 48,
            curve: Curves.easeInOut,

            alignment: Alignment.center,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              color: Palette.glazedWhite.o(0.15),
              child: Padding(
                padding:
                    !isSearchCardCollapsed
                        ? EdgeInsets.fromLTRB(16, 16, 0, 0)
                        : EdgeInsetsGeometry.only(
                          top: 2,
                          bottom: 2,
                          left: 8,
                          right: 8,
                        ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  reverseDuration: const Duration(microseconds: 250),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child:
                      showSearchContent
                          ? Column(
                            key: const ValueKey('expanded'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomFormField(
                                readOnly: true,
                                label: "genres...",
                                onPressed: _showGenreDialog,
                                controller: genreController,
                              ),
                              const SizedBox(height: 8),
                              CustomFormField(
                                readOnly: true,
                                label: "bpm...",
                                onPressed: _showBpmDialog,
                                controller: bpmController,
                              ),
                              const SizedBox(height: 8),
                              LocationAutocompleteField(
                                controller: locationController,
                                onCitySelected: (city) {
                                  setState(() {
                                    selectedCity = city;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const SizedBox(width: 85),
                                  ElevatedButton(
                                    onPressed: _search,

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Palette.shadowGrey,
                                      splashFactory: NoSplash.splashFactory,
                                      maximumSize: const Size(150, 24),
                                      minimumSize: const Size(88, 22),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: Palette.concreteGrey.o(0.7),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: Text(
                                      AppLocale.search.getString(context),
                                      style: GoogleFonts.sometypeMono(
                                        textStyle: TextStyle(
                                          color: Palette.primalBlack,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    style: ButtonStyle(
                                      foregroundColor:
                                          WidgetStateProperty.resolveWith<
                                            Color
                                          >((states) {
                                            if (states.contains(
                                              WidgetState.pressed,
                                            )) {
                                              return Palette.forgedGold;
                                            }
                                            return Palette.primalBlack;
                                          }),
                                      alignment: Alignment.bottomCenter,
                                      splashFactory: NoSplash.splashFactory,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        selectedGenres.clear();
                                        selectedBpm = null;
                                        selectedCity = null;
                                        genreController.clear();
                                        bpmController.clear();
                                        locationController.clear();
                                      });
                                      widget.onBpmRangeChanged(null);
                                      widget.onGenresChanged(null);
                                      _search();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Palette.shadowGrey,
                                        border: Border.all(
                                          color: Palette.concreteGrey,
                                        ),
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(6),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Palette.gigGrey.o(0.65),
                                            blurRadius: 2,
                                            offset: const Offset(0.5, 2),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          4,
                                          0,
                                          4,
                                          0,
                                        ),
                                        child: Text(
                                          AppLocale.clear.getString(context),
                                          style: GoogleFonts.sometypeMono(
                                            textStyle: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: Palette.primalBlack,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                          : isSearchCardAnimating
                          ? Center(
                            key: const ValueKey('collapsed'),
                            child: ElevatedButton(
                              autofocus: true,
                              onPressed: () async {
                                setState(() {
                                  isSearchCardAnimating =
                                      !isSearchCardAnimating;
                                  isSearchCardCollapsed =
                                      !isSearchCardCollapsed;
                                });
                                await Future.delayed(
                                  const Duration(milliseconds: 350),
                                );
                                setState(() {
                                  showSearchContent = !showSearchContent;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Palette.shadowGrey,
                                splashFactory: NoSplash.splashFactory,

                                maximumSize: const Size(150, 24),
                                minimumSize: const Size(88, 22),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Palette.concreteGrey.o(0.7),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 3,
                              ),
                              child: Text(
                                AppLocale.search.getString(context),
                                style: GoogleFonts.sometypeMono(
                                  textStyle: TextStyle(
                                    color: Palette.primalBlack,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          )
                          : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
