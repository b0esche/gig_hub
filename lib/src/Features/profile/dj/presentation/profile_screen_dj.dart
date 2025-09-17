import 'package:gig_hub/src/Features/profile/dj/presentation/widgets/location_display.dart';
import 'package:gig_hub/src/Features/profile/dj/presentation/widgets/bpm_display.dart';
import 'package:gig_hub/src/Features/profile/dj/presentation/widgets/location_input_field.dart';
import 'package:gig_hub/src/Features/profile/dj/presentation/widgets/about_box.dart';
import 'package:gig_hub/src/Features/profile/dj/presentation/widgets/info_box.dart';
import 'package:gig_hub/src/Features/profile/dj/presentation/widgets/track_selection_dropdown.dart';
import 'package:gig_hub/src/data/services/image_compression_service.dart';
import 'package:gig_hub/src/Features/raves/presentation/widgets/rave_list.dart';
import 'package:gig_hub/src/Common/widgets/safe_pinch_zoom.dart';
import "../../../../Data/app_imports.dart";
import "../../../../Data/app_imports.dart" as http;

class ProfileScreenDJArgs {
  final DJ dj;
  final DatabaseRepository db;
  final bool showChatButton, showEditButton, showFavoriteIcon;
  final AppUser currentUser;

  ProfileScreenDJArgs({
    required this.dj,
    required this.db,
    required this.currentUser,
    required this.showChatButton,
    required this.showEditButton,
    required this.showFavoriteIcon,
  });
}

class ProfileScreenDJ extends StatefulWidget {
  static const routeName = '/profileDj';

  final DJ dj;

  final bool showChatButton, showEditButton, showFavoriteIcon;
  final AppUser currentUser;
  const ProfileScreenDJ({
    super.key,
    required this.dj,

    required this.currentUser,
    required this.showChatButton,
    required this.showEditButton,
    required this.showFavoriteIcon,
  });

  @override
  State<ProfileScreenDJ> createState() => _ProfileScreenDJState();
}

class _ProfileScreenDJState extends State<ProfileScreenDJ> {
  int index = 0;
  bool editMode = false;
  Timer? _debounceTimer;
  StatusMessage? _currentStatusMessage;

  // Separate ValueNotifier for slideshow index to avoid full rebuilds
  late final ValueNotifier<int> _slideshowIndexNotifier = ValueNotifier(0);

  bool get isFavorite {
    final id = widget.dj.id;

    if (widget.currentUser is Guest) {
      return (widget.currentUser as Guest).favoriteUIds.contains(id);
    } else if (widget.currentUser is Booker) {
      return (widget.currentUser as Booker).favoriteUIds.contains(id);
    } else if (widget.currentUser is DJ) {
      return (widget.currentUser as DJ).favoriteUIds.contains(id);
    }
    return false;
  }

  final _formKey = GlobalKey<FormState>();
  final _locationFocusNode = FocusNode();
  String? _locationError;

  late final TextEditingController _nameController = TextEditingController(
    text: widget.dj.name,
  );
  late final TextEditingController _locationController = TextEditingController(
    text: widget.dj.city,
  );
  late final TextEditingController _bpmController = TextEditingController(
    text: "${widget.dj.bpm.first}-${widget.dj.bpm.last} bpm",
  );
  late final TextEditingController _aboutController = TextEditingController(
    text: widget.dj.about,
  );
  late final TextEditingController _infoController = TextEditingController(
    text: widget.dj.info,
  );

  final SoundcloudAuth _soundcloudAuth = SoundcloudAuth();

  List<SoundcloudTrack> userTrackList = [];
  SoundcloudTrack? selectedTrackOne;
  SoundcloudTrack? selectedTrackTwo;

  bool isUploading = false;

  @override
  void initState() {
    super.initState();

    _locationFocusNode.addListener(_onLocationFocusChange);
    _locationController.addListener(_onLocationChanged);

    _loadTracksIfAvailable();
    _loadStatusMessage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationFocusNode.removeListener(_onLocationFocusChange);
    _locationFocusNode.dispose();

    _locationController.removeListener(_onLocationChanged);

    _nameController.dispose();
    _locationController.dispose();
    _bpmController.dispose();
    _aboutController.dispose();
    _infoController.dispose();
    _slideshowIndexNotifier.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    final input = _locationController.text.trim();

    _debounceTimer?.cancel();
    if (input.isEmpty) {
      setState(() => _locationError = ' ');
      _formKey.currentState?.validate();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _validateCity(input);
    });
  }

  void _onLocationFocusChange() {
    if (!_locationFocusNode.hasFocus) {
      _validateCity(_locationController.text);
    }
  }

  Future<void> _validateCity(String value) async {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      setState(() => _locationError = ' ');
      _formKey.currentState?.validate();
      return;
    }

    setState(() {
      _locationError = null;
    });

    try {
      final isValidCityFound = await PlacesValidationService.validateCity(
        trimmedValue,
      );
      setState(() {
        _locationError = isValidCityFound ? null : ' ';
        if (editMode) {
          _formKey.currentState?.validate();
        }
      });
    } catch (e) {
      setState(() => _locationError = ' ');
      if (editMode) {
        _formKey.currentState?.validate();
      }
      throw Exception('network error during city validation: $e');
    }
  }

  Future<void> _loadTracksIfAvailable() async {
    final token = await _soundcloudAuth.getAccessToken();
    if (token == null) {
      Exception("no valid access token found");
      return;
    }

    final tracks = await SoundcloudService().fetchUserTracks();
    if (!mounted) return;
    setState(() {
      userTrackList = tracks;
    });
  }

  Future<void> _loadStatusMessage() async {
    try {
      final db = context.read<DatabaseRepository>();
      final statusMessage = await db.getActiveStatusMessage(widget.dj.id);
      if (mounted) {
        setState(() {
          _currentStatusMessage = statusMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStatusMessage = null;
        });
      }
    }
  }

  Future<void> _showStatusDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatusMessageDialog(),
    );

    if (result != null && mounted) {
      try {
        final message = result['message'] as String;
        final days = result['days'] as int;

        final statusMessage = StatusMessage(
          id: Uuid().v4(),
          userId: widget.dj.id,
          message: message,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(days: days)),
        );

        final db = context.read<DatabaseRepository>();
        await db.createStatusMessage(statusMessage);
        await _loadStatusMessage();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocale.updateStatusFailed.getString(context)),
              backgroundColor: Palette.alarmRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditStatusDialog() async {
    if (_currentStatusMessage == null) return;

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Palette.forgedGold, width: 2),
            ),
            title: Text(
              AppLocale.statusMessage.getString(context),
              style: GoogleFonts.sometypeMono(
                textStyle: TextStyle(
                  color: Palette.glazedWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            content: Text(
              _currentStatusMessage!.message,
              style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
            ),
            actionsOverflowButtonSpacing: -8,
            actions: [
              TextButton(
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocale.cancel.getString(context),
                  style: TextStyle(color: Palette.glazedWhite),
                ),
              ),
              TextButton(
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pop('edit'),
                child: Text(
                  AppLocale.edit.getString(context),
                  style: TextStyle(color: Palette.forgedGold),
                ),
              ),
              TextButton(
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pop('delete'),
                child: Text(
                  AppLocale.delete.getString(context),
                  style: TextStyle(color: Palette.alarmRed),
                ),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        if (result == 'delete' && mounted) {
          final db = context.read<DatabaseRepository>();
          await db.deleteStatusMessage(_currentStatusMessage!.id);
          await _loadStatusMessage();
        } else if (result == 'edit') {
          _showStatusDialog();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocale.updateStatusFailed.getString(context)),
              backgroundColor: Palette.alarmRed,
            ),
          );
        }
      }
    }
  }

  String _getTimeRemaining(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'expires soon';
    }
  }

  Future<void> _showGenreDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder:
          (context) =>
              GenreSelectionDialog(initialSelectedGenres: widget.dj.genres),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        widget.dj.genres
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseRepository>();
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Audio players now manage their own disposal
      },
      canPop: true,
      child: Scaffold(
        backgroundColor: Palette.primalBlack,
        floatingActionButton:
            (widget.showChatButton &&
                    widget.currentUser is! Guest &&
                    !(widget.currentUser is DJ &&
                        (widget.currentUser as DJ).id == widget.dj.id))
                ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ChatScreen(
                              chatPartner: widget.dj,

                              currentUser: widget.currentUser,
                            ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Palette.glazedWhite, Palette.gigGrey],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0, 0.8],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(14.0),
                      child: Icon(Icons.question_answer_outlined),
                    ),
                  ),
                )
                : null,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 256,
                    child: BlurHash(
                      hash:
                          widget.dj.headImageBlurHash.isNotEmpty
                              ? widget.dj.headImageBlurHash
                              : BlurHashService.defaultBlurHash,
                      image: widget.dj.headImageUrl,
                      imageFit: BoxFit.cover,
                      optimizationMode: BlurHashOptimizationMode.approximation,
                      color: Palette.primalBlack,
                    ),

                    //  Image.network(
                    //       widget.dj.headImageUrl,
                    //       fit: BoxFit.cover,
                    //       colorBlendMode:
                    //           editMode ? BlendMode.difference : null,
                    //       color: editMode ? Palette.primalBlack : null,
                    //     ),
                  ),

                  if (editMode)
                    Positioned(
                      top: 120,
                      left: 180,
                      child: IconButton(
                        style: ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.padded,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        onPressed: () async {
                          final XFile? picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );

                          if (picked != null) {
                            final File originalFile = File(picked.path);
                            final File compressedFile =
                                await ImageCompressionService.compressImage(
                                  originalFile,
                                );

                            setState(() {
                              widget.dj.headImageUrl = compressedFile.path;
                            });
                          }
                        },
                        icon: Icon(
                          Icons.file_upload_rounded,
                          color: Palette.concreteGrey,
                          size: 48,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 32,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: IconButton(
                        onPressed: () {
                          // Audio players now manage their own disposal
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(
                          Icons.chevron_left,
                          shadows: [
                            BoxShadow(
                              blurRadius: 4,
                              color: Palette.primalBlack,
                            ),
                          ],
                        ),
                        iconSize: 36,
                        color: Palette.shadowGrey,
                        style: const ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.padded,
                          splashFactory: NoSplash.splashFactory,
                        ),
                      ),
                    ),
                  ),
                  if (widget.showFavoriteIcon &&
                      !(widget.currentUser is DJ &&
                          (widget.currentUser as DJ).id == widget.dj.id))
                    _favoriteButton(),
                  Positioned.fill(
                    bottom: 2,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.primalBlack.o(0.6),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          border: Border(
                            left: BorderSide(
                              color: Palette.gigGrey.o(0.6),
                              width: 2,
                            ),
                            right: BorderSide(
                              color: Palette.gigGrey.o(0.6),
                              width: 2,
                            ),
                            top: BorderSide(
                              color: Palette.gigGrey.o(0.6),
                              width: 2,
                            ),
                          ),
                        ),
                        child:
                            !editMode
                                ? Text(
                                  widget.dj.name,
                                  style: GoogleFonts.sometypeMono(
                                    textStyle: TextStyle(
                                      color: Palette.glazedWhite,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                : Container(
                                  width: 160,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Palette.glazedWhite,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Palette.glazedWhite.o(0.2),
                                  ),
                                  child: TextFormField(
                                    onEditingComplete: () {
                                      setState(() {
                                        widget.dj.name = _nameController.text;
                                      });
                                    },
                                    style: TextStyle(
                                      color: Palette.glazedWhite,
                                      fontSize: 15,
                                    ),
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Palette.forgedGold,
                                          width: 3,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Palette.forgedGold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ),
                  ),
                  if (!editMode && widget.currentUser.id == widget.dj.id)
                    if (_currentStatusMessage == null ||
                        _currentStatusMessage!.isExpired)
                      Positioned(
                        top: 52,
                        right: 4,
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Palette.forgedGold.o(0.8),
                            border: Border.all(
                              color: Palette.primalBlack.o(0.65),
                              width: 1.65,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _showStatusDialog,
                            icon: Icon(
                              Icons.add,
                              color: Palette.primalBlack,
                              size: 20,
                            ),
                            style: ButtonStyle(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              splashFactory: NoSplash.splashFactory,
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: 52,
                        right: 2,
                        child: GestureDetector(
                          onTap: _showEditStatusDialog,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 280),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Palette.primalBlack.o(0.65),
                              border: Border.all(
                                color: Palette.forgedGold.o(0.65),
                                width: 1.35,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentStatusMessage!.message,
                                  style: TextStyle(
                                    color: Palette.glazedWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getTimeRemaining(
                                        _currentStatusMessage!.expiresAt,
                                      ),
                                      style: TextStyle(
                                        color: Palette.glazedWhite.o(0.95),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(
                                      Icons.edit,
                                      color: Palette.forgedGold,
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                  if (!editMode &&
                      widget.currentUser.id != widget.dj.id &&
                      _currentStatusMessage != null &&
                      !_currentStatusMessage!.isExpired)
                    Positioned(
                      top: 52,
                      right: 2,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 280),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Palette.primalBlack.o(0.7),
                          border: Border.all(
                            color: Palette.forgedGold.o(0.65),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStatusMessage!.message,
                              style: TextStyle(
                                color: Palette.glazedWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _getTimeRemaining(
                                _currentStatusMessage!.expiresAt,
                              ),
                              style: TextStyle(
                                color: Palette.glazedWhite.o(0.95),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!editMode) UserStarRating(widget: widget),

                  Positioned(
                    right: 0,
                    left: 0,
                    bottom: 0,
                    child: Divider(
                      height: 0,
                      thickness: 2,
                      color: Palette.forgedGold.o(0.8),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            LiquidGlass(
                              shape: LiquidRoundedRectangle(
                                borderRadius: Radius.circular(8),
                              ),
                              settings: LiquidGlassSettings(thickness: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Palette.shadowGrey.o(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Palette.concreteGrey,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Palette.primalBlack,
                                      ),
                                      const SizedBox(width: 4),
                                      !editMode
                                          ? LocationDisplay(widget: widget)
                                          : LocationInputField(
                                            locationController:
                                                _locationController,
                                            locationFocusNode:
                                                _locationFocusNode,
                                            locationError: _locationError,
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            LiquidGlass(
                              shape: LiquidRoundedRectangle(
                                borderRadius: Radius.circular(8),
                              ),
                              settings: LiquidGlassSettings(thickness: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Palette.shadowGrey.o(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Palette.concreteGrey,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.speed, size: 20),
                                      const SizedBox(width: 4),
                                      !editMode
                                          ? BpmDisplay(widget: widget)
                                          : bpmInputField(context),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.about.getString(context),
                              style: GoogleFonts.sometypeMono(
                                textStyle: TextStyle(
                                  color: Palette.glazedWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            !editMode
                                ? AboutBox(widget: widget)
                                : Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Palette.glazedWhite,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Palette.glazedWhite.o(0.2),
                                  ),
                                  child: TextFormField(
                                    onEditingComplete: () {
                                      setState(() {
                                        widget.dj.about = _aboutController.text;
                                      });
                                    },
                                    minLines: 1,
                                    maxLines: 7,
                                    maxLength: 250,
                                    style: TextStyle(
                                      color: Palette.glazedWhite,
                                      fontSize: 14,
                                      overflow: TextOverflow.visible,
                                    ),
                                    controller: _aboutController,
                                    decoration: InputDecoration(
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Palette.forgedGold,
                                          width: 3,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Palette.forgedGold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        _buildGenreBubbles(),
                        const SizedBox(height: 36),
                        Column(
                          spacing: !editMode ? 0 : 8,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!editMode)
                              Text(
                                (widget.dj.trackTitles.isNotEmpty)
                                    ? widget.dj.trackTitles.first
                                    : 'first Track',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sometypeMono(
                                  textStyle: TextStyle(
                                    wordSpacing: -3,
                                    color: Palette.glazedWhite,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Palette.glazedWhite,
                                    decorationStyle: TextDecorationStyle.dotted,
                                    decorationThickness: 2,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            !editMode
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    RepaintBoundary(
                                      child: AudioPlayerWidget(
                                        audioUrl: widget.dj.streamingUrls.first,
                                        trackTitle:
                                            widget.dj.trackTitles.isNotEmpty
                                                ? widget.dj.trackTitles.first
                                                : 'Track 1',
                                        artistName: widget.dj.name,
                                        sessionId: '${widget.dj.id}_track_1',
                                        artworkUrl: widget.dj.headImageUrl,
                                      ),
                                    ),
                                    IconButton(
                                      style: ButtonStyle(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        launchUrlString(
                                          widget.dj.trackUrls.first,
                                        );
                                      },
                                      icon: SvgPicture.asset(
                                        'assets/icons/soundcloud.svg',
                                      ),
                                    ),
                                  ],
                                )
                                : soundcloudFields(),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Column(
                          spacing: !editMode ? 0 : 8,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!editMode)
                              Text(
                                (widget.dj.trackTitles.last.isNotEmpty)
                                    ? widget.dj.trackTitles.last
                                    : 'second track',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sometypeMono(
                                  textStyle: TextStyle(
                                    color: Palette.glazedWhite,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Palette.glazedWhite,
                                    decorationStyle: TextDecorationStyle.dotted,
                                    decorationThickness: 2,
                                    wordSpacing: -3,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (!editMode)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  RepaintBoundary(
                                    child: AudioPlayerWidget(
                                      audioUrl: widget.dj.streamingUrls.last,
                                      trackTitle:
                                          widget.dj.trackTitles.length > 1
                                              ? widget.dj.trackTitles.last
                                              : 'Track 2',
                                      artistName: widget.dj.name,
                                      sessionId: '${widget.dj.id}_track_2',
                                      artworkUrl: widget.dj.headImageUrl,
                                    ),
                                  ),
                                  IconButton(
                                    style: ButtonStyle(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      launchUrlString(widget.dj.trackUrls.last);
                                    },
                                    icon: SvgPicture.asset(
                                      'assets/icons/soundcloud.svg',
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        !editMode
                            ? widget.dj.mediaImageUrls.isEmpty
                                ? SizedBox.shrink()
                                : RepaintBoundary(child: imageSlideshow())
                            : imageSlideshowEditor(),
                        SizedBox(
                          height:
                              widget.dj.mediaImageUrls.isNotEmpty ? null : 24,
                        ),
                        if (widget.dj.mediaImageUrls.isNotEmpty && editMode)
                          Center(
                            child: TextButton(
                              onPressed:
                                  () => setState(
                                    () => widget.dj.mediaImageUrls.clear(),
                                  ),
                              child: Text(
                                "remove all images",
                                style: TextStyle(
                                  color: Palette.alarmRed.o(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        if (widget.dj.mediaImageUrls.isNotEmpty)
                          const SizedBox(height: 36),
                        if (!editMode)
                          RepaintBoundary(
                            child: Column(
                              children: [
                                RaveList(
                                  userId: widget.dj.id,
                                  showCreateButton:
                                      false, // DJs can't create raves, only bookers can
                                  showOnlyUpcoming: false,
                                ),
                                const SizedBox(height: 36),
                              ],
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.info.getString(context),
                              style: GoogleFonts.sometypeMono(
                                textStyle: TextStyle(
                                  color: Palette.glazedWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            !editMode
                                ? InfoBox(widget: widget)
                                : Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Palette.glazedWhite,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Palette.glazedWhite.o(0.2),
                                  ),
                                  child: TextFormField(
                                    onEditingComplete: () {
                                      setState(() {
                                        widget.dj.info = _infoController.text;
                                      });
                                    },
                                    minLines: 1,
                                    maxLines: 7,
                                    maxLength: 250,
                                    cursorColor: Palette.forgedGold,

                                    style: TextStyle(
                                      color: Palette.glazedWhite,
                                      fontSize: 14,
                                      overflow: TextOverflow.visible,
                                    ),
                                    controller: _infoController,
                                    decoration: InputDecoration(
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Palette.forgedGold,
                                          width: 3,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Palette.forgedGold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        editProfileButton(context, db),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Positioned _favoriteButton() {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 0.65, color: Palette.gigGrey.o(0.85)),
          shape: BoxShape.circle,
          color: Palette.primalBlack.o(0.5),
        ),
        child: IconButton(
          style: ButtonStyle(
            splashFactory: NoSplash.splashFactory,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Palette.favoriteRed : Palette.glazedWhite,
            size: 22,
          ),
          onPressed: () async {
            final String targetId = widget.dj.id;
            final String userId = widget.currentUser.id;
            final userDocRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);

            final bool newFavoriteStatus = !isFavorite;

            setState(() {});

            if (newFavoriteStatus) {
              await userDocRef.update({
                'favoriteUIds': FieldValue.arrayUnion([targetId]),
              });

              if (widget.currentUser is Guest) {
                (widget.currentUser as Guest).favoriteUIds.add(targetId);
              } else if (widget.currentUser is Booker) {
                (widget.currentUser as Booker).favoriteUIds.add(targetId);
              } else if (widget.currentUser is DJ) {
                (widget.currentUser as DJ).favoriteUIds.add(targetId);
              }
            } else {
              await userDocRef.update({
                'favoriteUIds': FieldValue.arrayRemove([targetId]),
              });

              if (widget.currentUser is Guest) {
                (widget.currentUser as Guest).favoriteUIds.remove(targetId);
              } else if (widget.currentUser is Booker) {
                (widget.currentUser as Booker).favoriteUIds.remove(targetId);
              } else if (widget.currentUser is DJ) {
                (widget.currentUser as DJ).favoriteUIds.remove(targetId);
              }
            }

            setState(() {});
          },
        ),
      ),
    );
  }

  Center editProfileButton(BuildContext context, DatabaseRepository db) {
    return Center(
      child: SizedBox(
        height: 100,
        child:
            !widget.showEditButton
                ? OutlinedButton(
                  onPressed: () async {
                    if (editMode &&
                        (selectedTrackOne == null ||
                            selectedTrackTwo == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Palette.forgedGold,
                          content: Center(
                            child: Text(
                              'select 2 soundcloud tracks to save your profile!',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      );
                    }
                    // Audio players now manage their own state
                    if (editMode &&
                        _formKey.currentState!.validate() &&
                        (selectedTrackOne != null &&
                            selectedTrackTwo != null)) {
                      if (editMode) {
                        setState(() {
                          isUploading = !isUploading;
                        });
                      }

                      widget.dj.about = _aboutController.text;
                      widget.dj.info = _infoController.text;
                      widget.dj.name = _nameController.text;

                      widget.dj.streamingUrls = [
                        if (selectedTrackOne?.streamUrl != null)
                          selectedTrackOne!.streamUrl!,
                        if (selectedTrackTwo?.streamUrl != null)
                          selectedTrackTwo!.streamUrl!,
                      ];

                      widget.dj.trackTitles = [
                        selectedTrackOne?.title ?? '',
                        selectedTrackTwo?.title ?? '',
                      ];

                      widget.dj.trackUrls = [
                        selectedTrackOne?.permalinkUrl ?? '',
                        selectedTrackTwo?.permalinkUrl ?? '',
                      ];

                      final bpmText = _bpmController.text.trim();
                      final bpmParts = bpmText.split(' ').first.split('-');
                      if (bpmParts.length == 2) {
                        widget.dj.bpm = [
                          int.tryParse(bpmParts[0].trim()) ?? 0,
                          int.tryParse(bpmParts[1].trim()) ?? 0,
                        ];
                      }

                      if (_locationError == null) {
                        widget.dj.city = _locationController.text;
                      }

                      if (!widget.dj.headImageUrl.startsWith('http')) {
                        final headFile = File(widget.dj.headImageUrl);

                        // Generate BlurHash for head image
                        final headBlurHash =
                            await BlurHashService.generateBlurHash(headFile);
                        widget.dj.headImageBlurHash = headBlurHash;

                        final headStorageRef = FirebaseStorage.instance
                            .ref()
                            .child('head_images/${widget.dj.id}.jpg');
                        await headStorageRef.putFile(headFile);
                        widget.dj.headImageUrl =
                            await headStorageRef.getDownloadURL();
                      }

                      if (widget.dj.mediaImageUrls.any(
                        (path) => !path.startsWith('http'),
                      )) {
                        List<String> newUrls = [];
                        List<String> newBlurHashes = [];

                        for (
                          int i = 0;
                          i < widget.dj.mediaImageUrls.length;
                          i++
                        ) {
                          final path = widget.dj.mediaImageUrls[i];
                          if (path.startsWith('http')) {
                            newUrls.add(path);
                            // Keep existing BlurHash if available
                            if (i < widget.dj.mediaImageBlurHashes.length) {
                              newBlurHashes.add(
                                widget.dj.mediaImageBlurHashes[i],
                              );
                            } else {
                              newBlurHashes.add(
                                BlurHashService.defaultBlurHash,
                              );
                            }
                          } else {
                            final file = File(path);

                            // Generate BlurHash for media image
                            final blurHash =
                                await BlurHashService.generateBlurHash(file);
                            newBlurHashes.add(blurHash);

                            final ref = FirebaseStorage.instance.ref().child(
                              'media_images/${widget.dj.id}_$i.jpg',
                            );
                            await ref.putFile(file);
                            final downloadUrl = await ref.getDownloadURL();
                            newUrls.add(downloadUrl);
                          }
                        }
                        widget.dj.mediaImageUrls = newUrls;
                        widget.dj.mediaImageBlurHashes = newBlurHashes;
                      }
                      setState(() {
                        isUploading = !isUploading;
                        editMode = !editMode;
                      });
                      await db.updateDJ(widget.dj);
                    } else if (!editMode) {
                      // Audio players now manage their own state
                      setState(() => editMode = !editMode);
                    }
                  },
                  style: ButtonStyle(
                    splashFactory: NoSplash.splashFactory,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Palette.forgedGold, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Row(
                        spacing: 4,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          !isUploading
                              ? Text(
                                !editMode
                                    ? AppLocale.editProfile.getString(context)
                                    : AppLocale.done.getString(context),
                                style: GoogleFonts.sometypeMono(
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Palette.glazedWhite,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Palette.glazedWhite,
                                  ),
                                ),
                              )
                              : SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  color: Palette.forgedGold,
                                  strokeWidth: 2,
                                ),
                              ),
                          Icon(
                            !editMode ? Icons.edit : Icons.done,
                            size: 14,
                            color: Palette.glazedWhite,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : SizedBox.shrink(),
      ),
    );
  }

  ClipRRect imageSlideshow() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ImageSlideshow(
        width: double.infinity,
        height: 240,
        isLoop: widget.dj.mediaImageUrls.length == 1 ? false : true,
        autoPlayInterval: 12000,

        indicatorColor:
            widget.dj.mediaImageUrls.length == 1
                ? Colors.transparent
                : Palette.shadowGrey,
        indicatorBackgroundColor:
            widget.dj.mediaImageUrls.length == 1
                ? Colors.transparent
                : Palette.gigGrey,
        initialPage: _slideshowIndexNotifier.value,
        onPageChanged: (value) {
          // Use ValueNotifier instead of setState to avoid rebuilding entire widget
          _slideshowIndexNotifier.value = value;
        },
        children: [
          if (widget.dj.mediaImageUrls.isNotEmpty)
            for (
              int index = 0;
              index < widget.dj.mediaImageUrls.length;
              index++
            )
              SafePinchZoom(
                key: ValueKey('safe_pinch_zoom_$index'),
                zoomEnabled: true,
                maxScale: 2.5,
                child: BlurHash(
                  hash:
                      index < widget.dj.mediaImageBlurHashes.length
                          ? widget.dj.mediaImageBlurHashes[index]
                          : BlurHashService.defaultBlurHash,
                  image: widget.dj.mediaImageUrls[index],
                  imageFit: BoxFit.cover,
                  optimizationMode: BlurHashOptimizationMode.approximation,
                ),

                // Image.network(
                //   widget.dj.mediaImageUrls[index],
                //   fit: BoxFit.cover,
                // ),
              ),
        ],
      ),
    );
  }

  Center imageSlideshowEditor() {
    return Center(
      child: Container(
        height: 160,
        width: 240,
        decoration: BoxDecoration(
          border: Border.all(color: Palette.forgedGold),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.padded),
          onPressed: () async {
            List<XFile> medias = await ImagePicker().pickMultiImage(limit: 5);
            List<String> newMediaUrls = [];
            for (XFile xfile in medias) {
              File originalFile = File(xfile.path);
              File compressedFile = await ImageCompressionService.compressImage(
                originalFile,
              );
              newMediaUrls.add(compressedFile.path);
            }
            List<String> mediaUrls = newMediaUrls;
            setState(() {
              widget.dj.mediaImageUrls.addAll(mediaUrls);
            });
          },
          icon: Icon(
            Icons.file_upload_rounded,
            color: Palette.concreteGrey,
            size: 48,
          ),
        ),
      ),
    );
  }

  Container bpmInputField(BuildContext context) {
    return Container(
      width: 136,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Palette.glazedWhite, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Palette.glazedWhite.o(0.2),
      ),
      child: TextFormField(
        readOnly: true,
        onTap: () async {
          final result = await showDialog<List<int>>(
            context: context,
            builder:
                (context) => BpmSelectionDialog(
                  intialSelectedBpm: [widget.dj.bpm.first, widget.dj.bpm.last],
                ),
          );

          if (result != null && result.length == 2) {
            setState(() {
              widget.dj.bpm.first = result[0];
              widget.dj.bpm.last = result[1];
              _bpmController.text = '${result[0]}-${result[1]} bpm';
            });
          }
        },
        style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
        controller: _bpmController,
        decoration: InputDecoration(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Palette.forgedGold, width: 3),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Palette.forgedGold),
          ),
        ),
      ),
    );
  }

  Center _buildGenreBubbles() {
    return Center(
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children:
            !editMode
                ? widget.dj.genres
                    .map((genreString) => GenreBubble(genre: genreString))
                    .toList()
                : [
                  ...widget.dj.genres.map(
                    (genreString) => GenreBubble(genre: genreString),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Palette.forgedGold, width: 2.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: GestureDetector(
                      onTap: _showGenreDialog,

                      child: GenreBubble(
                        genre: AppLocale.editGenres.getString(context),
                      ),
                    ),
                  ),
                ],
      ),
    );
  }

  Column soundcloudFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TrackSelectionDropdown(
          userTrackList: userTrackList,
          label: AppLocale.firstSoundcloud.getString(context),
          selectedTrack: selectedTrackOne,
          onChanged: (track) => setState(() => selectedTrackOne = track),
        ),
        const SizedBox(height: 36),
        TrackSelectionDropdown(
          userTrackList: userTrackList,
          label: AppLocale.secondSoundcloud.getString(context),
          selectedTrack: selectedTrackTwo,
          onChanged: (track) => setState(() => selectedTrackTwo = track),
        ),
      ],
    );
  }
}
