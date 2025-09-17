import '../../Data/app_imports.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.initialUser});

  final AppUser? initialUser;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String _selectedSortOption = '';
  List<DJ> _usersDJ = [];
  List<DJ> _sortedUsersDJ = [];

  List<int>? _currentSearchBpmRange;
  List<String>? _currentSearchGenres;
  final db = CachedFirestoreRepository();
  AppUser? _loggedInUser;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  final SoundcloudAuth _soundcloudAuth = SoundcloudAuth();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appLinks = AppLinks();
      _initDeepLinks();
      _checkGuestAndShowDialog();
      _loadLoggedInUser();
      _fetchDJs();
    });
  }

  void _initDeepLinks() {
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (!mounted) return;
        _onUri(uri);
      },
      onError: (err) {
        if (!mounted) return;
        throw Exception('link stream error: $err');
      },
      cancelOnError: true,
    );
  }

  void _onUri(Uri uri) async {
    if (!mounted) return;
    if (uri.toString().startsWith(SoundcloudAuth.redirectUri)) {
      final code = uri.queryParameters['code'];
      if (code != null) {
        await _soundcloudAuth.exchangeCodeForToken(code);
        if (!mounted) return;
      }
    }
  }

  void _checkGuestAndShowDialog() async {
    final token = await _soundcloudAuth.getAccessToken();

    if ((widget.initialUser is Guest && token == null) || (token == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(Duration.zero, () {
          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true,
            builder:
                (context) => AlertDialog(
                  backgroundColor: Palette.primalBlack.o(0.95),
                  surfaceTintColor: Palette.forgedGold,
                  title: Center(
                    child: Text(
                      widget.initialUser is Guest ||
                              widget.initialUser is Booker
                          ? "welcome to Gig Hub!"
                          : "lost connection to SoundCloud!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sometypeMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Palette.forgedGold,
                      ),
                    ),
                  ),
                  content: Text(
                    "connect your SoundCloud to continue:",
                    maxLines: 1,
                    style: GoogleFonts.sometypeMono(
                      fontSize: 13,
                      color: Palette.shadowGrey.o(0.9),
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: connectToSoundcloudButton(),
                    ),
                  ],
                ),
          );
        });
      });
    }
  }

  Widget connectToSoundcloudButton() {
    return Center(
      child: IconButton(
        onPressed: () {
          SoundcloudAuth()
              .authenticate()
              .then((value) async {
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                await _soundcloudAuth.getAccessToken();
              })
              .catchError((e) {
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
              });
        },
        icon: Image.asset('assets/images/btn-connect-l.png'),
      ),
    );
  }

  Future<void> _fetchDJs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use cached repository for faster loading
      final users = await db.getDJs();

      if (mounted) {
        setState(() {
          _usersDJ = users;
          _sortedUsersDJ = List.from(_usersDJ);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleExpanded() {
    if (context.mounted) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }
  }

  void _sortUsers(String option) {
    if (context.mounted) {
      setState(() {
        if (_selectedSortOption == option) {
          _selectedSortOption = '';
          _sortedUsersDJ = List.from(_usersDJ);
          return;
        }

        _selectedSortOption = option;
        List<DJ> sortedList = List.from(_usersDJ);

        if (option.isEmpty) {
          _sortedUsersDJ = List.from(_usersDJ);
          return;
        }

        switch (option) {
          case 'genre':
            if (_currentSearchGenres != null &&
                _currentSearchGenres!.isNotEmpty) {
              sortedList.sort((a, b) {
                // Count how many selected genres DJ 'a' has
                int matchesA =
                    a.genres
                        .where((genre) => _currentSearchGenres!.contains(genre))
                        .length;
                // Count how many selected genres DJ 'b' has
                int matchesB =
                    b.genres
                        .where((genre) => _currentSearchGenres!.contains(genre))
                        .length;

                // Sort descending by number of matches (more matches come first)
                if (matchesA != matchesB) {
                  return matchesB.compareTo(matchesA);
                }

                // If match counts are equal, use a secondary sort criterion.
                // For example, sort alphabetically by DJ name as a tie-breaker.
                return a.name.compareTo(b.name);
              });
            } else {
              // If no search genres are active, fall back to standard alphabetical by first genre,
              // or by name if preferred. Let's stick to name for consistency when no search filter is active.
              sortedList.sort((a, b) => a.name.compareTo(b.name));
            }
            break;
          case 'bpm':
            if (_currentSearchBpmRange != null) {
              final int searchMin = _currentSearchBpmRange![0];
              final int searchMax = _currentSearchBpmRange![1];

              sortedList.sort((a, b) {
                // Calculate overlap for DJ A
                int overlapA = 0;
                if (a.bpm.last >= searchMin && a.bpm.first <= searchMax) {
                  overlapA =
                      (a.bpm.last < searchMax ? a.bpm.last : searchMax) -
                      (a.bpm.first > searchMin ? a.bpm.first : searchMin);
                }

                // Calculate overlap for DJ B
                int overlapB = 0;
                if (b.bpm.last >= searchMin && b.bpm.first <= searchMax) {
                  overlapB =
                      (b.bpm.last < searchMax ? b.bpm.last : searchMax) -
                      (b.bpm.first > searchMin ? b.bpm.first : searchMin);
                }

                // Prioritize higher overlap
                if (overlapA != overlapB) {
                  return overlapB.compareTo(overlapA); // Descending by overlap
                }

                // If overlaps are equal, prioritize exact match of min/max
                if (a.bpm.first == searchMin && a.bpm.last == searchMax) {
                  return -1;
                }
                if (b.bpm.first == searchMin && b.bpm.last == searchMax) {
                  return 1;
                }

                // Fallback: sort by how "centered" their range is to the search range,
                // or simply by min BPM, then max BPM for tie-breaking.
                // For a simple tie-breaker, let's use min BPM then max BPM.
                int compareMin = a.bpm.first.compareTo(b.bpm.first);
                return compareMin == 0
                    ? a.bpm.last.compareTo(b.bpm.last)
                    : compareMin;
              });
            } else {
              // If no search BPM range is active, fall back to standard min/max sort
              sortedList.sort((a, b) {
                int compareMin = a.bpm.first.compareTo(b.bpm.first);
                return compareMin == 0
                    ? a.bpm.last.compareTo(b.bpm.last)
                    : compareMin;
              });
            }
            break;
          case 'location':
            sortedList.sort((a, b) => a.city.compareTo(b.city));
            break;
          default:
            _sortedUsersDJ = List.from(_usersDJ);
            return;
        }

        _sortedUsersDJ = sortedList;
      });
    }
  }

  Future<void> _loadLoggedInUser() async {
    final user = await db.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _loggedInUser = user;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();

    // Clean up cached repository resources
    db.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseRepository>();
    final currentUser = _loggedInUser;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Palette.primalBlack,
        body: SafeArea(
          child: Center(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: SizedBox(
                    height: 130,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              if (currentUser == null) return;
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) => SettingsScreen(),
                                      fullscreenDialog: true,
                                    ),
                                  )
                                  .then((_) async {
                                    // Clear all image caches to ensure avatar updates are shown
                                    imageCache.clear();
                                    imageCache.clearLiveImages();
                                    // Force reload user data
                                    await _loadLoggedInUser();
                                    // Force widget rebuild with setState
                                    if (mounted) {
                                      setState(() {
                                        // This will trigger a rebuild with fresh data
                                      });
                                    }
                                  });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Palette.glazedWhite.o(0.5),
                                  width: 1.4,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  currentUser?.avatarUrl ??
                                      'https://firebasestorage.googleapis.com/v0/b/gig-hub-8ac24.firebasestorage.app/o/default%2Fdefault_avatar.jpg?alt=media&token=9c48f377-736e-4a9a-bf31-6ffc3ed020f7',
                                  key: ValueKey(
                                    '${currentUser?.avatarUrl ?? 'default'}_${DateTime.now().millisecondsSinceEpoch}',
                                  ),
                                  height: 68,
                                  width: 68,
                                  fit: BoxFit.cover,
                                  cacheWidth: null,
                                  cacheHeight: null,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/default_avatar.jpg',
                                      height: 68,
                                      width: 68,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      height: 68,
                                      width: 68,
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onLongPress:
                                () => launchUrlString(
                                  'https://gig-hub-8ac24.web.app/',
                                ),
                            child: SizedBox(
                              height: 160,
                              width: 160,
                              child: Image.asset('assets/images/icon_full.png'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                RepaintBoundary(
                  child: SearchFunctionCard(
                    onSearchResults: (List<DJ> results) {
                      setState(() {
                        _usersDJ = results;
                        _sortedUsersDJ = List.from(results);
                        _selectedSortOption = '';
                      });
                    },
                    onSearchLoading: (bool isLoading) {
                      setState(() {
                        _isLoading = isLoading;
                      });
                    },
                    onBpmRangeChanged: (List<int>? bpmRange) {
                      setState(() {
                        _currentSearchBpmRange = bpmRange;
                      });
                    },
                    onGenresChanged: (List<String>? genres) {
                      setState(() {
                        _currentSearchGenres = genres;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Palette.forgedGold),
                          right: BorderSide(color: Palette.forgedGold),
                          top: BorderSide(color: Palette.forgedGold),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          List<DJ> favs = await db.getFavoriteDJs(
                            currentUser!.id,
                          );
                          setState(() {
                            _sortedUsersDJ = favs;
                          });
                        },
                        icon: Icon(
                          Icons.favorite_rounded,
                          color: Palette.glazedWhite,
                          size: 21,
                        ),
                        style: ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          splashFactory: NoSplash.splashFactory,
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.only(top: 12, bottom: 12, right: 4),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap:
                          () => setState(() {
                            _isExpanded = !_isExpanded;
                          }),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: AppLocale.sortBy.getString(context),
                              style: TextStyle(
                                color: Palette.glazedWhite,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                wordSpacing: -1,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.top,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Icon(
                                  _isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                  color: Palette.glazedWhite,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                if (_isExpanded)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SortButtonsWidget(
                      selectedSortOption: _selectedSortOption,
                      onSortOptionChanged: _sortUsers,
                      onExpandedChanged: _toggleExpanded,
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      _isLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              color: Palette.forgedGold,
                            ),
                          )
                          : Stack(
                            children: [
                              ListView.builder(
                                padding: const EdgeInsets.only(
                                  top: 28,
                                  left: 4,
                                  right: 4,
                                  bottom: 164,
                                ),
                                physics: const ClampingScrollPhysics(),
                                itemCount: _sortedUsersDJ.length,
                                itemBuilder: (context, index) {
                                  final currentUserDJ = _sortedUsersDJ[index];
                                  return SearchListTile(
                                    currentUser: widget.initialUser!,
                                    user: currentUserDJ,
                                    name: currentUserDJ.name,
                                    genres: currentUserDJ.genres,
                                    imagePath: currentUserDJ.avatarImageUrl,
                                    about: currentUserDJ.about,
                                    location: currentUserDJ.city,
                                    bpm: currentUserDJ.bpm,
                                    rating: currentUserDJ.avgRating,
                                  );
                                },
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 20,
                                child: IgnorePointer(
                                  child: LiquidGlass(
                                    shape: LiquidRoundedRectangle(
                                      borderRadius: Radius.circular(0),
                                    ),
                                    glassContainsChild: false,
                                    settings: LiquidGlassSettings(
                                      thickness: 17,
                                      blur: 1.7,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Palette.primalBlack,
                                            Palette.primalBlack.o(0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomNavBar(
          currentUser:
              currentUser ??
              Guest(
                    id: '',
                    favoriteUIds: [],
                    avatarImageUrl:
                        'https://firebasestorage.googleapis.com/v0/b/gig-hub-8ac24.firebasestorage.app/o/default%2Fdefault_avatar.jpg?alt=media&token=9c48f377-736e-4a9a-bf31-6ffc3ed020f7',
                  )
                  as AppUser,
        ),
      ),
    );
  }
}
