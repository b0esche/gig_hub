import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:gig_hub/src/Common/widgets/blocked_users_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppUser? _user;
  XFile? _pickedImage;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  late DatabaseRepository db;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'it', 'name': 'Italiano', 'flag': '🇮🇹'},
    {'code': 'pt', 'name': 'Português', 'flag': '🇵🇹'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'nl', 'name': 'Nederlands', 'flag': '🇳🇱'},
    {'code': 'pl', 'name': 'Polski', 'flag': '🇵🇱'},
    {'code': 'uk', 'name': 'Українська', 'flag': '🇺🇦'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
  ];

  String _currentLanguage = 'en';

  @override
  void initState() {
    super.initState();
    db = Provider.of<DatabaseRepository>(context, listen: false);
    _currentLanguage =
        FlutterLocalization.instance.currentLocale?.languageCode ?? 'en';
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await db.getCurrentUser();
    setState(() {
      _user = user;
      _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    });
  }

  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 60,
      format: CompressFormat.jpeg,
    );
    if (mounted) {
      if (compressedBytes == null) {
        throw Exception(AppLocale.imgCompressionFailed.getString(context));
      }
    }
    if (compressedBytes != null) {
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    }
    return file;
  }

  Future<void> _pickNewImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null && _user != null) {
      final originalFile = File(picked.path);
      final compressedFile = await compressImage(originalFile);

      final storageRef = FirebaseStorage.instance.ref().child(
        'avatars/${_user!.id}.jpg',
      );

      try {
        final uploadTask = await storageRef.putFile(
          compressedFile,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'ownerId': _user!.id},
          ),
        );

        final downloadUrl = await uploadTask.ref.getDownloadURL();

        setState(() {
          if (_user is DJ) {
            (_user as DJ).avatarImageUrl = downloadUrl;
          } else if (_user is Booker) {
            (_user as Booker).avatarImageUrl = downloadUrl;
          } else if (_user is Guest) {
            (_user as Guest).avatarImageUrl = downloadUrl;
          }
          // Reset _pickedImage so that the new URL from database is used
          _pickedImage = null;
        });

        await db.updateUser(_user!);
      } catch (e) {
        throw Exception('error while uploading: $e');
      }
    }
  }

  String? validateEmail(String? input) {
    if (input == null || input.isEmpty) return "can't be empty";
    if (input.length < 5) return "enter full address";
    if (!input.contains('@') || !input.contains('.')) return "invalid input";
    if (input.startsWith('@') || input.endsWith('@')) return "invalid input";
    if (input.contains(' ')) return "can't contain space";
    final parts = input.split('@');
    if (parts.length != 2) return "invalid input";
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return "invalid input";
    if (!domain.contains('.')) return "invalid domain";
    final domainParts = domain.split('.');
    if (domainParts.any((part) => part.length < 2)) return "invalid domain";
    return null;
  }

  Future<void> _onEmailSubmitted(String newValue) async {
    if (_formKey.currentState?.validate() != true) return;

    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) return;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final passwordController = TextEditingController();
        final formKey = GlobalKey<FormState>();

        return AlertDialog(
          title: Center(
            child: Text(
              AppLocale.enterPw.getString(context),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocale.pw.getString(context),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator:
                  (value) =>
                      (value == null || value.isEmpty)
                          ? AppLocale.pwNecessary.getString(context)
                          : null,
            ),
          ),
          actions: [
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Palette.primalBlack,
                  elevation: 0,
                  splashFactory: NoSplash.splashFactory,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Palette.primalBlack.o(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  AppLocale.cancel.getString(context),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(passwordController.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.forgedGold,
                  foregroundColor: Palette.primalBlack,
                  elevation: 0,
                  splashFactory: NoSplash.splashFactory,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocale.proceed.getString(context),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (password == null) {
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      await user.verifyBeforeUpdateEmail(newValue);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Palette.forgedGold,
            content: Center(
              child: Text(
                'verification email sent. please check your inbox.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Palette.alarmRed,
          content: Center(
            child: Text(
              'error: ${e.toString()}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _onResetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    final messenger = ScaffoldMessenger.of(context);
    if (email != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Palette.forgedGold,
            content: Center(
              child: Text(
                'password reset email sent. please check your inbox.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    if (_user == null) {
      return Scaffold(
        backgroundColor: Palette.primalBlack,
        body: Center(
          child: CircularProgressIndicator(color: Palette.forgedGold),
        ),
      );
    } else {
      final avatarUrl =
          _user is DJ
              ? (_user as DJ).avatarImageUrl
              : _user is Booker
              ? (_user as Booker).avatarImageUrl
              : (_user as Guest).avatarImageUrl;

      final ImageProvider avatarProvider =
          _pickedImage != null
              ? FileImage(File(_pickedImage!.path))
              : NetworkImage(avatarUrl);

      return Scaffold(
        backgroundColor: Palette.primalBlack,
        body: Stack(
          children: [
            Positioned(
              top: 128,
              right: 8,
              child: IconButton(
                onPressed:
                    () => launchUrlString('https://gig-hub-8ac24.web.app/#/qa'),
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 36,
                  color: Palette.glazedWhite,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.shadowGrey.o(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Palette.concreteGrey),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currentLanguage,
                    dropdownColor: Palette.primalBlack.o(0.9),
                    iconEnabledColor: Palette.forgedGold,
                    style: TextStyle(color: Palette.glazedWhite),
                    borderRadius: BorderRadius.circular(8),
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    selectedItemBuilder: (BuildContext context) {
                      return _languages.map((language) {
                        return Center(
                          child: Text(
                            language['flag']!,
                            style: TextStyle(fontSize: 24),
                          ),
                        );
                      }).toList();
                    },
                    items:
                        _languages.map((language) {
                          return DropdownMenuItem<String>(
                            value: language['code'],
                            child: Center(
                              child: Text(
                                language['flag']!,
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newLanguage) {
                      if (newLanguage != null) {
                        setState(() {
                          _currentLanguage = newLanguage;
                        });

                        // Change the app language
                        FlutterLocalization.instance.translate(newLanguage);
                      }
                    },
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left_rounded, size: 36),
                      color: Palette.glazedWhite,
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.padded,
                        splashFactory: NoSplash.splashFactory,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        () => launchUrlString(
                          'https://gig-hub-8ac24.web.app/#/portfolio',
                        ),
                    child: SizedBox.square(
                      dimension: 142,
                      child: Image.asset("assets/images/icon_full.png"),
                    ),
                  ),

                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickNewImage,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Palette.glazedWhite,
                              width: 1.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 80,
                            backgroundImage: avatarProvider,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -8,
                        right: -8,
                        child: IconButton(
                          style: ButtonStyle(
                            splashFactory: NoSplash.splashFactory,
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          onPressed: _pickNewImage,
                          icon: Icon(
                            Icons.upload_file_rounded,
                            color: Palette.forgedGold,
                            size: 36,
                            shadows: [
                              BoxShadow(
                                blurRadius: 2,
                                blurStyle: BlurStyle.inner,
                                color: Palette.primalBlack,
                                spreadRadius: 2,
                                offset: Offset(0.6, 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_user is! Guest)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocale.changeEmail.getString(context),
                          style: GoogleFonts.sometypeMono(
                            textStyle: TextStyle(
                              color: Palette.glazedWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 1.3,
                          child: Form(
                            key: _formKey,
                            child: TextFormField(
                              readOnly: false,
                              textInputAction: TextInputAction.go,
                              autovalidateMode: AutovalidateMode.always,
                              validator: validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              onFieldSubmitted: _onEmailSubmitted,
                              controller: _emailController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                helperText: AppLocale.pressEnterFinish
                                    .getString(context),
                                labelStyle: TextStyle(
                                  color: Palette.primalBlack,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => _emailController.clear(),
                                  icon: Icon(
                                    Icons.delete,
                                    color: Palette.alarmRed.o(0.85),
                                    size: 26,
                                  ),
                                ),
                                fillColor: Palette.glazedWhite,
                                filled: true,
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                hintText: AppLocale.pressEnterDone.getString(
                                  context,
                                ),
                                hintStyle: TextStyle(color: Palette.forgedGold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_user is! Guest)
                    Container(
                      height: 48,
                      width: MediaQuery.of(context).size.width / 1.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.shadowGrey.o(0.1),
                          foregroundColor: Palette.glazedWhite,
                          elevation: 0,
                          splashFactory: NoSplash.splashFactory,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Palette.glazedWhite.o(0.7),
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed: _user is Guest ? null : _onResetPassword,
                        child: Text(
                          AppLocale.changePw.getString(context),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  if (_user is! Guest)
                    Container(
                      height: 48,
                      width: MediaQuery.of(context).size.width / 1.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.shadowGrey.o(0.1),
                          foregroundColor: Palette.glazedWhite,
                          elevation: 0,
                          splashFactory: NoSplash.splashFactory,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Palette.glazedWhite.o(0.7),
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed:
                            _user is Guest
                                ? null
                                : () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => BlockedUsersDialog(),
                                  );
                                },
                        child: Text(
                          AppLocale.blocks.getString(context),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  if (_user is! Guest)
                    Container(
                      height: 48,
                      width: MediaQuery.of(context).size.width / 1.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.alarmRed.o(0.1),
                          foregroundColor: Palette.alarmRed,
                          elevation: 0,
                          splashFactory: NoSplash.splashFactory,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Palette.alarmRed.o(0.7),
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  backgroundColor: Palette.forgedGold,

                                  title: Center(
                                    child: Text(
                                      AppLocale.areYouSure.getString(context),
                                      style: GoogleFonts.sometypeMono(
                                        textStyle: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Palette.primalBlack,
                                          elevation: 0,
                                          splashFactory: NoSplash.splashFactory,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            side: BorderSide(
                                              color: Palette.primalBlack.o(0.3),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          AppLocale.cancel.getString(context),
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Palette.alarmRed,
                                          foregroundColor: Palette.glazedWhite,
                                          elevation: 0,
                                          splashFactory: NoSplash.splashFactory,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () async {
                                          // Store navigator reference before async operation
                                          final navigator = Navigator.of(
                                            context,
                                          );

                                          await auth.deleteUser();

                                          if (!mounted) return;

                                          // Close the dialog first
                                          navigator.pop();

                                          // Navigate back to root and let auth state handle the rest
                                          navigator.popUntil(
                                            (route) => route.isFirst,
                                          );
                                        },
                                        child: Text(
                                          AppLocale.deleteAcc.getString(
                                            context,
                                          ),
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        },
                        child: Text(
                          AppLocale.deleteAcc.getString(context),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    height: 48,
                    width: MediaQuery.of(context).size.width / 1.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.forgedGold.o(0.1),
                        foregroundColor: Palette.forgedGold,
                        elevation: 0,
                        splashFactory: NoSplash.splashFactory,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Palette.forgedGold.o(0.7),
                            width: 2,
                          ),
                        ),
                      ),
                      onPressed: () async {
                        // Store navigator reference before async operation
                        final navigator = Navigator.of(context);

                        // Sign out
                        await auth.signOut();

                        // Ensure we're not mounted after async operation
                        if (!mounted) return;

                        // Navigate back to root and let auth state handle the rest
                        navigator.popUntil((route) => route.isFirst);
                      },
                      child: Text(
                        AppLocale.logOut.getString(context),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onTap:
                          () => launchUrlString(
                            'https://gig-hub-8ac24.web.app/#/contribute',
                          ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 24, 12),
                        child: Text(
                          "version 1.0.21",
                          style: TextStyle(color: Palette.glazedWhite),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
