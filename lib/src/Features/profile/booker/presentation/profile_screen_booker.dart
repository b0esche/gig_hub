import 'package:gig_hub/src/Data/app_imports.dart' hide UserStarRating;
import 'package:gig_hub/src/data/services/image_compression_service.dart';
import 'package:gig_hub/src/Features/profile/booker/presentation/widgets/star_rating_booker.dart';
import 'package:gig_hub/src/Features/raves/presentation/widgets/rave_list.dart';
import 'package:gig_hub/src/Common/widgets/safe_pinch_zoom.dart';

class ProfileScreenBookerArgs {
  final Booker booker;
  final DatabaseRepository db;
  final bool showEditButton;

  ProfileScreenBookerArgs({
    required this.booker,
    required this.db,
    required this.showEditButton,
  });
}

class ProfileScreenBooker extends StatefulWidget {
  static const routeName = '/profileBooker';

  final Booker booker;
  final dynamic db;
  final bool showEditButton;

  const ProfileScreenBooker({
    super.key,
    required this.booker,
    required this.db,
    required this.showEditButton,
  });

  @override
  State<ProfileScreenBooker> createState() => _ProfileScreenBookerState();
}

class _ProfileScreenBookerState extends State<ProfileScreenBooker> {
  int index = 0;

  bool editMode = false;
  StatusMessage? _currentStatusMessage;
  AppUser? _currentUser;

  // Separate ValueNotifier for slideshow index to avoid full rebuilds
  late final ValueNotifier<int> _slideshowIndexNotifier = ValueNotifier(0);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _infoController = TextEditingController(
    text: widget.booker.info,
  );
  late final TextEditingController _aboutController = TextEditingController(
    text: widget.booker.about,
  );
  late final TextEditingController _nameController = TextEditingController(
    text: widget.booker.name,
  );
  late final TextEditingController _locationController = TextEditingController(
    text: widget.booker.city,
  );
  String? _locationError;
  final _locationFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    _locationFocusNode.addListener(_onLocationFocusChange);
    _locationController.addListener(_onLocationChanged);
    _loadCurrentUser();
    _loadStatusMessage();
    super.initState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationFocusNode.removeListener(_onLocationFocusChange);
    _locationFocusNode.dispose();

    _locationController.removeListener(_onLocationChanged);
    _infoController.dispose();
    _aboutController.dispose();
    _nameController.dispose();
    _locationController.dispose();
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

  Future<void> _loadCurrentUser() async {
    try {
      final db = context.read<DatabaseRepository>();
      final currentUser = await db.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = currentUser;
        });
      }
    } catch (e) {
      // Handle error gracefully
    }
  }

  Future<void> _loadStatusMessage() async {
    try {
      final db = context.read<DatabaseRepository>();
      final statusMessage = await db.getActiveStatusMessage(widget.booker.id);
      if (mounted) {
        setState(() {
          _currentStatusMessage = statusMessage;
        });
      }
    } catch (e) {
      // Don't crash the app if status messages aren't available
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
          userId: widget.booker.id,
          message: message,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(days: days)),
        );

        final db = context.read<DatabaseRepository>();
        await db.createStatusMessage(statusMessage);
        await _loadStatusMessage();
      } catch (e) {
        // Show user-friendly error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to create status message. Please check your connection.',
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.primalBlack,
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
                        widget.booker.headImageBlurHash.isNotEmpty
                            ? widget.booker.headImageBlurHash
                            : BlurHashService.defaultBlurHash,
                    image: widget.booker.headImageUrl,
                    imageFit: BoxFit.cover,
                    optimizationMode: BlurHashOptimizationMode.approximation,
                    color: Palette.primalBlack,
                  ),

                  //  Image.network(
                  //       widget.booker.headImageUrl,
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
                            widget.booker.headImageUrl = compressedFile.path;
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
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.chevron_left,
                        shadows: [
                          BoxShadow(blurRadius: 4, color: Palette.primalBlack),
                        ],
                      ),
                      iconSize: 36,
                      color: Palette.shadowGrey,
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    ),
                  ),
                ),
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
                                widget.booker.name,
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
                                      widget.booker.name = _nameController.text;
                                    });
                                  },
                                  style: TextStyle(
                                    color: Palette.glazedWhite,
                                    fontSize: 14,
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

                if (!editMode &&
                    _currentUser != null &&
                    _currentUser!.id == widget.booker.id)
                  if (_currentStatusMessage == null ||
                      _currentStatusMessage!.isExpired)
                    Positioned(
                      top: 52,
                      right: 4,
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Palette.forgedGold.o(0.8),
                          border: Border.all(
                            color: Palette.primalBlack,
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _showStatusDialog,
                          icon: Icon(
                            Icons.add,
                            color: Palette.primalBlack,
                            size: 24,
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
                      right: 4,
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
                    _currentUser != null &&
                    _currentUser!.id != widget.booker.id &&
                    _currentStatusMessage != null &&
                    !_currentStatusMessage!.isExpired)
                  Positioned(
                    top: 52,
                    right: 4,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 280),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Palette.primalBlack.o(0.8),
                        border: Border.all(color: Palette.forgedGold, width: 1),
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
                            _getTimeRemaining(_currentStatusMessage!.expiresAt),
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
                          Container(
                            decoration: BoxDecoration(
                              color: Palette.shadowGrey.o(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Palette.concreteGrey),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  !editMode
                                      ? Text(
                                        widget.booker.city,
                                        style: GoogleFonts.sometypeMono(
                                          textStyle: TextStyle(
                                            fontSize: 14,
                                            color: Palette.primalBlack,
                                          ),
                                        ),
                                      )
                                      : SizedBox(
                                        width: 136,
                                        height: 24,
                                        child: TextFormField(
                                          style: TextStyle(
                                            color: Palette.glazedWhite,
                                            fontSize: 14,
                                          ),
                                          controller: _locationController,
                                          focusNode: _locationFocusNode,
                                          validator: (value) {
                                            return _locationError;
                                          },
                                          autovalidateMode:
                                              AutovalidateMode
                                                  .onUserInteraction,
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Palette.forgedGold,
                                                width: 2,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Palette.glazedWhite,
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Palette.alarmRed,
                                              ),
                                            ),
                                            errorText: _locationError,
                                            errorStyle: TextStyle(
                                              fontSize: 0,
                                              height: 0,
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Palette.shadowGrey.o(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Palette.concreteGrey),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.nightlife_rounded, size: 20),
                                  const SizedBox(width: 4),
                                  !editMode
                                      ? Text(
                                        widget.booker.category,
                                        style: GoogleFonts.sometypeMono(
                                          textStyle: TextStyle(
                                            fontSize: 14,
                                            color: Palette.primalBlack,
                                          ),
                                        ),
                                      )
                                      : SizedBox(
                                        width: 136,
                                        height: 24,
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              widget.booker.category.isNotEmpty
                                                  ? widget.booker.category
                                                  : 'Club',
                                          items:
                                              [
                                                    'Club',
                                                    'Event',
                                                    'Outdoor Event',
                                                    'Bar',
                                                    'Pop-Up',
                                                    'Collective',
                                                    'Festival',
                                                  ]
                                                  .map(
                                                    (cat) => DropdownMenuItem(
                                                      value: cat,
                                                      child: Text(
                                                        cat,
                                                        style: TextStyle(
                                                          color:
                                                              Palette
                                                                  .glazedWhite,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                widget.booker.category = val;
                                              });
                                            }
                                          },
                                          dropdownColor: Palette.gigGrey.o(0.9),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 0,
                                                ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Palette.glazedWhite,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Palette.forgedGold,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
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
                              ),
                            ),
                          ),
                          !editMode
                              ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Palette.shadowGrey,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    widget.booker.about,
                                    style: TextStyle(
                                      color: Palette.primalBlack,
                                    ),
                                  ),
                                ),
                              )
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
                                      widget.booker.about =
                                          _aboutController.text;
                                    });
                                  },
                                  minLines: 1,
                                  maxLines: 7,
                                  maxLength: 250,
                                  style: TextStyle(
                                    color: Palette.glazedWhite,
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
                      !editMode
                          ? widget.booker.mediaImageUrls.isEmpty
                              ? SizedBox.shrink()
                              : RepaintBoundary(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ImageSlideshow(
                                    width: double.infinity,
                                    height: 240,
                                    isLoop: true,
                                    autoPlayInterval: 12000,
                                    indicatorColor: Palette.shadowGrey,
                                    indicatorBackgroundColor: Palette.gigGrey,
                                    initialPage: _slideshowIndexNotifier.value,
                                    onPageChanged: (value) {
                                      // Use ValueNotifier instead of setState to avoid rebuilding entire widget
                                      _slideshowIndexNotifier.value = value;
                                    },
                                    children: [
                                      if (widget
                                          .booker
                                          .mediaImageUrls
                                          .isNotEmpty)
                                        for (String path
                                            in widget.booker.mediaImageUrls)
                                          SafePinchZoom(
                                            zoomEnabled: true,
                                            maxScale: 2.5,
                                            child: BlurHash(
                                              hash:
                                                  widget.booker.mediaImageUrls
                                                              .indexOf(path) <
                                                          widget
                                                              .booker
                                                              .mediaImageBlurHashes
                                                              .length
                                                      ? widget
                                                          .booker
                                                          .mediaImageBlurHashes[widget
                                                          .booker
                                                          .mediaImageUrls
                                                          .indexOf(path)]
                                                      : BlurHashService
                                                          .defaultBlurHash,
                                              image: path,
                                              imageFit: BoxFit.cover,
                                              optimizationMode:
                                                  BlurHashOptimizationMode
                                                      .approximation,
                                            ),

                                            //  Image.network(
                                            //   path,
                                            //   fit: BoxFit.cover,
                                            // ),
                                          ),
                                    ],
                                  ),
                                ),
                              )
                          : Center(
                            child: Container(
                              height: 160,
                              width: 240,
                              decoration: BoxDecoration(
                                border: Border.all(color: Palette.forgedGold),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                style: ButtonStyle(
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ),
                                onPressed: () async {
                                  List<XFile> medias = await ImagePicker()
                                      .pickMultiImage(limit: 5);
                                  List<String> newMediaUrls = [];
                                  for (XFile xfile in medias) {
                                    File originalFile = File(xfile.path);
                                    File compressedFile =
                                        await ImageCompressionService.compressImage(
                                          originalFile,
                                        );
                                    newMediaUrls.add(compressedFile.path);
                                  }
                                  List<String> mediaUrls = newMediaUrls;
                                  setState(() {
                                    widget.booker.mediaImageUrls.addAll(
                                      mediaUrls,
                                    );
                                  });
                                },
                                icon: Icon(
                                  Icons.file_upload_rounded,
                                  color: Palette.concreteGrey,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                      SizedBox(
                        height:
                            widget.booker.mediaImageUrls.isNotEmpty ? null : 24,
                      ),
                      if (widget.booker.mediaImageUrls.isNotEmpty && editMode)
                        Center(
                          child: TextButton(
                            onPressed:
                                () => setState(
                                  () => widget.booker.mediaImageUrls.clear(),
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
                      if (widget.booker.mediaImageUrls.isNotEmpty)
                        SizedBox(height: 36),
                      if (!editMode)
                        RepaintBoundary(
                          child: Column(
                            children: [
                              RaveList(
                                userId: widget.booker.id,
                                showCreateButton: true,
                                showOnlyUpcoming: false,
                              ),
                              SizedBox(height: 36),
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
                              ),
                            ),
                          ),
                          !editMode
                              ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Palette.shadowGrey,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    widget.booker.info,
                                    style: TextStyle(
                                      color: Palette.primalBlack,
                                    ),
                                  ),
                                ),
                              )
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
                                      widget.booker.info = _infoController.text;
                                    });
                                  },
                                  minLines: 1,
                                  maxLines: 7,
                                  maxLength: 250,
                                  cursorColor: Palette.forgedGold,

                                  style: TextStyle(
                                    color: Palette.glazedWhite,
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

                      Center(
                        child: SizedBox(
                          height: 100,
                          child:
                              !widget.showEditButton
                                  ? OutlinedButton(
                                    onPressed: () async {
                                      if (editMode &&
                                          _formKey.currentState!.validate()) {
                                        widget.booker.about =
                                            _aboutController.text;
                                        widget.booker.info =
                                            _infoController.text;
                                        widget.booker.name =
                                            _nameController.text;
                                        if (_locationError == null) {
                                          widget.booker.city =
                                              _locationController.text;
                                        }

                                        if (!widget.booker.headImageUrl
                                            .startsWith('http')) {
                                          final headFile = File(
                                            widget.booker.headImageUrl,
                                          );

                                          // Generate BlurHash for head image
                                          final headBlurHash =
                                              await BlurHashService.generateBlurHash(
                                                headFile,
                                              );
                                          widget.booker.headImageBlurHash =
                                              headBlurHash;

                                          final headStorageRef = FirebaseStorage
                                              .instance
                                              .ref()
                                              .child(
                                                'booker_head_images/${widget.booker.id}.jpg',
                                              );
                                          await headStorageRef.putFile(
                                            headFile,
                                          );
                                          widget.booker.headImageUrl =
                                              await headStorageRef
                                                  .getDownloadURL();
                                        }

                                        if (widget.booker.mediaImageUrls.any(
                                          (path) => !path.startsWith('http'),
                                        )) {
                                          List<String> newUrls = [];
                                          List<String> newBlurHashes = [];

                                          for (
                                            int i = 0;
                                            i <
                                                widget
                                                    .booker
                                                    .mediaImageUrls
                                                    .length;
                                            i++
                                          ) {
                                            final path =
                                                widget.booker.mediaImageUrls[i];
                                            if (path.startsWith('http')) {
                                              newUrls.add(path);
                                              // Keep existing BlurHash if available
                                              if (i <
                                                  widget
                                                      .booker
                                                      .mediaImageBlurHashes
                                                      .length) {
                                                newBlurHashes.add(
                                                  widget
                                                      .booker
                                                      .mediaImageBlurHashes[i],
                                                );
                                              } else {
                                                newBlurHashes.add(
                                                  BlurHashService
                                                      .defaultBlurHash,
                                                );
                                              }
                                            } else {
                                              final file = File(path);

                                              // Generate BlurHash for media image
                                              final blurHash =
                                                  await BlurHashService.generateBlurHash(
                                                    file,
                                                  );
                                              newBlurHashes.add(blurHash);

                                              final ref = FirebaseStorage
                                                  .instance
                                                  .ref()
                                                  .child(
                                                    'booker_media_images/${widget.booker.id}_$i.jpg',
                                                  );
                                              await ref.putFile(file);
                                              final downloadUrl =
                                                  await ref.getDownloadURL();
                                              newUrls.add(downloadUrl);
                                            }
                                          }
                                          widget.booker.mediaImageUrls =
                                              newUrls;
                                          widget.booker.mediaImageBlurHashes =
                                              newBlurHashes;
                                        }

                                        try {
                                          await widget.db.updateBooker(
                                            widget.booker,
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                backgroundColor:
                                                    Palette.forgedGold,
                                                content: Center(
                                                  child: Text(
                                                    'error: ${e.toString()}',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      setState(() {
                                        editMode = !editMode;
                                      });
                                    },

                                    style: ButtonStyle(
                                      splashFactory: NoSplash.splashFactory,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Palette.forgedGold,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Row(
                                          spacing: 4,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              !editMode
                                                  ? AppLocale.editProfile
                                                      .getString(context)
                                                  : AppLocale.done.getString(
                                                    context,
                                                  ),
                                              style: GoogleFonts.sometypeMono(
                                                textStyle: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: Palette.glazedWhite,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Palette.glazedWhite,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              !editMode
                                                  ? Icons.edit
                                                  : Icons.done,
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
