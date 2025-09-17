import "../../../../Data/app_imports.dart";
import 'package:gig_hub/src/Common/widgets/safe_pinch_zoom.dart';

class CreateProfileScreenDJ extends StatefulWidget {
  final String email;
  final String pw;
  const CreateProfileScreenDJ({
    super.key,

    required this.email,
    required this.pw,
  });

  @override
  State<CreateProfileScreenDJ> createState() => _CreateProfileScreenDJState();
}

class _CreateProfileScreenDJState extends State<CreateProfileScreenDJ> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: AppLocale.yourName.getString(context),
  );
  late final _locationController = TextEditingController(
    text: AppLocale.yourCity.getString(context),
  );
  late final _bpmController = TextEditingController(
    text: AppLocale.yourTempo.getString(context),
  );
  late final _aboutController = TextEditingController();
  late final _infoController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();
  String? headUrl;
  String? _locationError;
  String? bpmMin;
  String? bpmMax;
  String? about;
  String? info;
  List<String>? genres;
  List<String>? mediaUrl;
  int index = 0;
  bool isSoundcloudConnected = false;

  late final AppLinks _appLinks;
  final SoundcloudAuth _soundcloudAuth = SoundcloudAuth();
  StreamSubscription<Uri>? _sub;

  List<SoundcloudTrack> userTrackList = [];
  SoundcloudTrack? selectedTrackOne;
  SoundcloudTrack? selectedTrackTwo;

  @override
  void initState() {
    super.initState();

    _locationFocusNode.addListener(_onLocationFocusChange);

    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _onUri(uri);
    }, onError: (err) => throw Exception('link stream error: $err'));
  }

  void _onUri(Uri uri) async {
    if (uri.toString().startsWith(SoundcloudAuth.redirectUri)) {
      final code = uri.queryParameters['code'];
      if (code != null) {
        await _soundcloudAuth.exchangeCodeForToken(code);

        final token = await _soundcloudAuth.getAccessToken();
        if (token == null) {
          return;
        }

        final tracks = await SoundcloudService().fetchUserTracks();
        setState(() {
          userTrackList = tracks;
          isSoundcloudConnected = !isSoundcloudConnected;
        });
      }
    }
  }

  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null) {
      throw Exception(AppLocale.imgCompressionFailed.getString(context));
    }

    final compressedFile = File(targetPath);
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }

  @override
  void dispose() {
    _locationFocusNode.removeListener(_onLocationFocusChange);
    _locationFocusNode.dispose();
    _nameController.dispose();
    _aboutController.dispose();
    _infoController.dispose();
    _locationController.dispose();
    _bpmController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _onLocationFocusChange() {
    if (!_locationFocusNode.hasFocus) {
      _validateCity(_locationController.text);
    }
  }

  Future<void> _validateCity(String value) async {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      setState(() {
        _locationError = null;
      });
      // Trigger form validation to update UI
      _formKey.currentState?.validate();
      return;
    }

    setState(() {
      _locationError = null;
    });

    try {
      // Use the new PlacesValidationService
      final isValid = await PlacesValidationService.validateCity(trimmedValue);

      if (mounted) {
        setState(() {
          _locationError = isValid ? null : 'Please enter a valid city name';
        });
        // Trigger form validation to update the UI
        _formKey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Error validating location';
        });
        // Trigger form validation to update the UI
        _formKey.currentState?.validate();
      }
    }
  }

  Future<void> _showGenreDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder:
          (context) =>
              GenreSelectionDialog(initialSelectedGenres: genres ?? []),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        genres = result;
      });
    }
  }

  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseRepository>();
    if (isLoading) {
      return Scaffold(
        backgroundColor: Palette.primalBlack,
        body: Center(
          child: CircularProgressIndicator(color: Palette.forgedGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Palette.primalBlack,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 256,
                  color: Palette.gigGrey,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    child:
                        headUrl != null
                            ? Image.file(
                              File(headUrl!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              key: ValueKey(headUrl!),
                            )
                            : null,
                  ),
                ),
                Center(
                  heightFactor: 4,
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
                        final File compressedFile = await compressImage(
                          originalFile,
                        );

                        setState(() {
                          headUrl = compressedFile.path;
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
                        Navigator.pop(context);
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
                      child: Container(
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
                          onTap: _nameController.clear,
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Palette.glazedWhite,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(bottom: 14),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Palette.forgedGold,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                              color: Palette.shadowGrey.o(0.35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Palette.concreteGrey),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 138,
                                    height: 24,
                                    child: TextFormField(
                                      onTap: _locationController.clear,
                                      style: TextStyle(
                                        color: Palette.glazedWhite,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                      controller: _locationController,
                                      focusNode: _locationFocusNode,
                                      validator: (value) {
                                        return _locationError;
                                      },
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.alarmRed,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.alarmRed,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.forgedGold,
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.glazedWhite,
                                          ),
                                        ),
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
                              color: Palette.shadowGrey.o(0.35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Palette.concreteGrey),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.speed, size: 20),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 138,
                                    height: 24,
                                    child: TextFormField(
                                      readOnly: true,
                                      textAlign: TextAlign.center,
                                      onTap: () async {
                                        final result = await showDialog<
                                          List<int>
                                        >(
                                          context: context,
                                          builder:
                                              (context) => BpmSelectionDialog(
                                                intialSelectedBpm: [
                                                  int.tryParse(
                                                        bpmMin?.toString() ??
                                                            '',
                                                      ) ??
                                                      100,
                                                  int.tryParse(
                                                        bpmMax?.toString() ??
                                                            '',
                                                      ) ??
                                                      130,
                                                ],
                                              ),
                                        );

                                        if (result != null &&
                                            result.length == 2) {
                                          setState(() {
                                            bpmMin = result[0].toString();
                                            bpmMax = result[1].toString();
                                            _bpmController.text =
                                                '${result[0]}-${result[1]} bpm';
                                          });
                                        }
                                      },
                                      style: TextStyle(
                                        color: Palette.glazedWhite,
                                        fontSize: 13,
                                      ),
                                      controller: _bpmController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.forgedGold,
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.glazedWhite,
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
                      const SizedBox(height: 36),
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
                          Container(
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
                                  about = _aboutController.text;
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
                      const SizedBox(height: 60),
                      Center(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (genres != null && genres!.isNotEmpty) ...[
                              ...genres!.map(
                                (genre) => GenreBubble(genre: genre),
                              ),
                            ],
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Palette.forgedGold,
                                  width: 2.7,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: GestureDetector(
                                onTap: _showGenreDialog,
                                child: GenreBubble(
                                  genre:
                                      (genres == null)
                                          ? AppLocale.addGenres.getString(
                                            context,
                                          )
                                          : AppLocale.editGenres.getString(
                                            context,
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: !isSoundcloudConnected ? 72 : 48),
                      IndexedStack(
                        index: isSoundcloudConnected ? 0 : 1,
                        children: [
                          soundcloudFields(),
                          connectToSoundcloudButton(),
                        ],
                      ),

                      SizedBox(height: isSoundcloudConnected ? 72 : 0),
                      (mediaUrl != null && mediaUrl!.isNotEmpty)
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ImageSlideshow(
                              width: double.infinity,
                              height: 240,
                              isLoop: true,
                              autoPlayInterval: 12000,
                              indicatorColor: Palette.shadowGrey,
                              indicatorBackgroundColor: Palette.gigGrey,
                              initialPage: index,
                              onPageChanged: (value) {
                                setState(() => index = value);
                              },
                              children:
                                  mediaUrl!.map((path) {
                                    return SafePinchZoom(
                                      zoomEnabled: true,
                                      maxScale: 2.5,
                                      child: Image.network(
                                        path,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          )
                          : Center(
                            child: Column(
                              children: [
                                Text(
                                  AppLocale.addImages.getString(context),
                                  style: GoogleFonts.sometypeMono(
                                    textStyle: TextStyle(
                                      color: Palette.glazedWhite,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  height: 160,
                                  width: 240,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Palette.forgedGold,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    style: ButtonStyle(
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final medias = await picker
                                          .pickMultiImage(limit: 5);

                                      if (medias.isNotEmpty) {
                                        List<String> newMediaUrls = [];

                                        for (XFile xfile in medias) {
                                          File originalFile = File(xfile.path);
                                          File compressedFile =
                                              await compressImage(originalFile);
                                          newMediaUrls.add(compressedFile.path);
                                        }

                                        setState(() {
                                          mediaUrl = newMediaUrls;
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
                              ],
                            ),
                          ),
                      SizedBox(height: 8),
                      (mediaUrl != null && mediaUrl!.isNotEmpty)
                          ? Center(
                            child: TextButton(
                              onPressed:
                                  () => setState(() {
                                    mediaUrl!.clear();
                                  }),
                              child: Text(
                                AppLocale.removeImages.getString(context),
                                style: TextStyle(
                                  color: Palette.alarmRed.o(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          : SizedBox.shrink(),
                      SizedBox(height: 36),
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

                          Container(
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
                                setState(() => info = _infoController.text);
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
                      Center(
                        child: SizedBox(
                          height: 100,
                          child: OutlinedButton(
                            onPressed: () async {
                              if (_nameController.text.isEmpty ||
                                  _nameController.text == '' ||
                                  _nameController.text == 'Name' ||
                                  _nameController.text == 'name' ||
                                  _nameController.text ==
                                      AppLocale.yourName.getString(context) ||
                                  _aboutController.text == '' ||
                                  _aboutController.text.isEmpty ||
                                  _infoController.text == '' ||
                                  _infoController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Palette.forgedGold,
                                    content: Center(
                                      child: Text(
                                        AppLocale.fillOutAllFields.getString(
                                          context,
                                        ),
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (headUrl == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Palette.forgedGold,
                                    content: Center(
                                      child: Text(
                                        AppLocale.addHeadImage.getString(
                                          context,
                                        ),
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              // Check if SoundCloud is connected
                              if (!isSoundcloudConnected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Palette.alarmRed,
                                    content: Center(
                                      child: Text(
                                        'please connect your SoundCloud account first.',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              // Check if both tracks are selected
                              if (selectedTrackOne == null ||
                                  selectedTrackTwo == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Palette.alarmRed,
                                    content: Center(
                                      child: Text(
                                        'please select 2 tracks from your SoundCloud.',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                isLoading = true;
                              });
                              FocusManager.instance.primaryFocus?.unfocus();

                              if (headUrl?.isNotEmpty == true &&
                                  bpmMin?.isNotEmpty == true &&
                                  bpmMax?.isNotEmpty == true &&
                                  _infoController.text.isNotEmpty &&
                                  _aboutController.text.isNotEmpty &&
                                  _locationController.text.isNotEmpty &&
                                  _nameController.text.isNotEmpty) {
                                try {
                                  User? firebaseUser;

                                  // Check if user is already authenticated (social login)
                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  if (currentUser != null &&
                                      widget.pw.isEmpty) {
                                    // Social login case - user is already authenticated
                                    firebaseUser = currentUser;
                                  } else {
                                    // Email/password signup case
                                    final UserCredential userCredential =
                                        await FirebaseAuth.instance
                                            .createUserWithEmailAndPassword(
                                              email: widget.email,
                                              password: widget.pw,
                                            );
                                    firebaseUser = userCredential.user;
                                  }

                                  if (firebaseUser == null) {
                                    throw Exception("user creation failed");
                                  }

                                  String uploadedHeadImageUrl = headUrl!;
                                  String headImageBlurHash =
                                      BlurHashService.defaultBlurHash;

                                  if (!headUrl!.startsWith('http')) {
                                    final headFile = File(headUrl!);

                                    // Generate BlurHash for head image
                                    headImageBlurHash =
                                        await BlurHashService.generateBlurHash(
                                          headFile,
                                        );

                                    final headStorageRef = FirebaseStorage
                                        .instance
                                        .ref()
                                        .child(
                                          'head_images/${firebaseUser.uid}.jpg',
                                        );
                                    await headStorageRef.putFile(headFile);
                                    uploadedHeadImageUrl =
                                        await headStorageRef.getDownloadURL();
                                  }

                                  List<String> uploadedMediaUrls = [];
                                  List<String> mediaImageBlurHashes = [];

                                  if (mediaUrl != null &&
                                      mediaUrl!.isNotEmpty) {
                                    for (int i = 0; i < mediaUrl!.length; i++) {
                                      final mediaPath = mediaUrl![i];
                                      if (mediaPath.startsWith('http')) {
                                        uploadedMediaUrls.add(mediaPath);
                                        mediaImageBlurHashes.add(
                                          BlurHashService.defaultBlurHash,
                                        );
                                      } else {
                                        final mediaFile = File(mediaPath);

                                        // Generate BlurHash for media image
                                        final blurHash =
                                            await BlurHashService.generateBlurHash(
                                              mediaFile,
                                            );
                                        mediaImageBlurHashes.add(blurHash);

                                        final mediaStorageRef = FirebaseStorage
                                            .instance
                                            .ref()
                                            .child(
                                              'media_images/${firebaseUser.uid}_$i.jpg',
                                            );
                                        await mediaStorageRef.putFile(
                                          mediaFile,
                                        );
                                        final downloadUrl =
                                            await mediaStorageRef
                                                .getDownloadURL();
                                        uploadedMediaUrls.add(downloadUrl);
                                      }
                                    }
                                  }
                                  final dj = DJ(
                                    id: firebaseUser.uid,
                                    genres: genres!,
                                    headImageUrl: uploadedHeadImageUrl,
                                    headImageBlurHash: headImageBlurHash,
                                    avatarImageUrl:
                                        'https://firebasestorage.googleapis.com/v0/b/gig-hub-8ac24.firebasestorage.app/o/default%2Fdefault_avatar.jpg?alt=media&token=9c48f377-736e-4a9a-bf31-6ffc3ed020f7',
                                    bpm: [
                                      int.parse(bpmMin!),
                                      int.parse(bpmMax!),
                                    ],
                                    about: _aboutController.text,
                                    streamingUrls: [
                                      if (selectedTrackOne?.streamUrl != null)
                                        selectedTrackOne!.streamUrl!,
                                      if (selectedTrackTwo?.streamUrl != null)
                                        selectedTrackTwo!.streamUrl!,
                                    ],
                                    trackTitles: [
                                      selectedTrackOne!.title,
                                      selectedTrackTwo!.title,
                                    ],
                                    trackUrls: [
                                      selectedTrackOne!.permalinkUrl,
                                      selectedTrackTwo!.permalinkUrl,
                                    ],
                                    mediaImageUrls: uploadedMediaUrls,
                                    mediaImageBlurHashes: mediaImageBlurHashes,
                                    info: _infoController.text,
                                    name: _nameController.text,
                                    avgRating: 0,
                                    ratingCount: 0,
                                    city: _locationController.text,
                                    favoriteUIds: [],
                                  );
                                  await db.createDJ(dj);
                                  final newUser = await db.getCurrentUser();
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              MainScreen(initialUser: newUser),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Palette.forgedGold,
                                      content: Center(
                                        child: Text(
                                          AppLocale.profileCreationFailed
                                              .getString(context),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ButtonStyle(
                              splashFactory: NoSplash.splashFactory,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                      AppLocale.done.getString(context),
                                      style: GoogleFonts.sometypeMono(
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Palette.glazedWhite,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Palette.glazedWhite,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.done,
                                      size: 14,
                                      color: Palette.glazedWhite,
                                    ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget connectToSoundcloudButton() {
    return Center(
      child: IconButton(
        onPressed: () async {
          await _soundcloudAuth.authenticate();
        },
        icon: Image.asset('assets/images/btn-connect-l.png'),
      ),
    );
  }

  Column soundcloudFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildTrackDropdown(
          label: AppLocale.firstSoundcloud.getString(context),
          selectedTrack: selectedTrackOne,
          onChanged: (track) => setState(() => selectedTrackOne = track),
        ),
        const SizedBox(height: 36),
        _buildTrackDropdown(
          label: AppLocale.secondSoundcloud.getString(context),
          selectedTrack: selectedTrackTwo,
          onChanged: (track) => setState(() => selectedTrackTwo = track),
        ),
      ],
    );
  }

  Widget _buildTrackDropdown({
    required String label,
    required SoundcloudTrack? selectedTrack,
    required Function(SoundcloudTrack?) onChanged,
  }) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.sometypeMono(
              textStyle: TextStyle(
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
            width: 260,
            height: 48,
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
                  style: TextStyle(color: Palette.glazedWhite, fontSize: 11),
                ),
                style: TextStyle(color: Palette.glazedWhite, fontSize: 11),
                items:
                    userTrackList.map((track) {
                      return DropdownMenuItem<SoundcloudTrack>(
                        value: track,
                        child: Text(
                          track.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
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
