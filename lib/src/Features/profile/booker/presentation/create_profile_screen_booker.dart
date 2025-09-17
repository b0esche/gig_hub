import "../../../../Data/app_imports.dart";
import "../../../../Data/app_imports.dart" as http;
import 'package:gig_hub/src/Common/widgets/safe_pinch_zoom.dart';

class CreateProfileScreenBooker extends StatefulWidget {
  final String email;
  final String pw;
  const CreateProfileScreenBooker({
    super.key,

    required this.email,
    required this.pw,
  });

  @override
  State<CreateProfileScreenBooker> createState() =>
      _CreateProfileScreenBookerState();
}

class _CreateProfileScreenBookerState extends State<CreateProfileScreenBooker> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: AppLocale.yourName.getString(context),
  );
  late final _locationController = TextEditingController(
    text: AppLocale.yourCity.getString(context),
  );

  late final _aboutController = TextEditingController();
  late final _infoController = TextEditingController();

  final _locationFocusNode = FocusNode();
  String? headUrl;
  String? _locationError;

  String? about;
  String? info;

  String _selectedCategory = 'Club';

  List<String>? mediaUrl = [];
  int index = 0;

  @override
  void initState() {
    _locationFocusNode.addListener(_onLocationFocusChange);
    super.initState();
  }

  @override
  void dispose() {
    _locationFocusNode.removeListener(_onLocationFocusChange);
    _locationFocusNode.dispose();
    _nameController.dispose();
    _aboutController.dispose();
    _infoController.dispose();
    _locationController.dispose();

    super.dispose();
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
                      final XFile? newUserHeadUrl = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (newUserHeadUrl != null) {
                        setState(() {
                          headUrl = newUserHeadUrl.path;
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
                                        // Return null if valid (no error), return error message if invalid
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
                                  const Icon(Icons.nightlife_rounded, size: 20),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 138,
                                    height: 24,
                                    child: DropdownButtonFormField<String>(
                                      iconEnabledColor: Palette.glazedWhite.o(
                                        0.85,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return AppLocale.selectCategory
                                              .getString(context);
                                        }
                                        return null;
                                      },
                                      initialValue: _selectedCategory,
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
                                                          Palette.glazedWhite,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedCategory = val;
                                          });
                                        }
                                      },
                                      dropdownColor: Palette.gigGrey.o(0.9),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 0,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Palette.glazedWhite,
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
                      const SizedBox(height: 40),

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
                                      child:
                                          path.startsWith('http')
                                              ? Image.network(
                                                path,
                                                fit: BoxFit.cover,
                                              )
                                              : Image.file(
                                                File(path),
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
                                      List<XFile> medias = await ImagePicker()
                                          .pickMultiImage(limit: 10);
                                      List<String> newMediaUrls =
                                          medias
                                              .map((element) => element.path)
                                              .toList();
                                      setState(() {
                                        mediaUrl = newMediaUrls;
                                      });
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
                      (mediaUrl!.isNotEmpty)
                          ? Center(
                            child: TextButton(
                              onPressed:
                                  () => setState(() {
                                    mediaUrl!.clear();
                                  }),
                              child: Text(
                                AppLocale.removeImages.getString(context),
                                style: TextStyle(
                                  color: Palette.alarmRed.o(0.75),
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
                              setState(() {
                                isLoading = true;
                              });
                              FocusManager.instance.primaryFocus?.unfocus();
                              if (headUrl!.isNotEmpty &&
                                  headUrl != null &&
                                  _aboutController.text.isNotEmpty &&
                                  _infoController.text.isNotEmpty &&
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

                                  final booker = Booker(
                                    id: firebaseUser.uid,
                                    avatarImageUrl:
                                        'https://firebasestorage.googleapis.com/v0/b/gig-hub-8ac24.firebasestorage.app/o/default%2Fdefault_avatar.jpg?alt=media&token=9c48f377-736e-4a9a-bf31-6ffc3ed020f7',
                                    headImageUrl: uploadedHeadImageUrl,
                                    headImageBlurHash: headImageBlurHash,
                                    name: _nameController.text,
                                    city: _locationController.text,
                                    about: _aboutController.text,
                                    info: _infoController.text,
                                    category: _selectedCategory,
                                    mediaImageUrls: uploadedMediaUrls,
                                    mediaImageBlurHashes: mediaImageBlurHashes,
                                    avgRating: 0.0,
                                    ratingCount: 0,
                                  );
                                  await db.createBooker(booker);
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
}
