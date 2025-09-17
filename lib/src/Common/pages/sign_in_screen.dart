import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../main.dart' show globalNavigatorKey;

import '../../Data/app_imports.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  late final TextEditingController emailController = TextEditingController();
  Set<String> selected = {'dj'};
  bool _isObscured = true;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

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
    _currentLanguage =
        FlutterLocalization.instance.currentLocale?.languageCode ?? 'en';
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _performLogin() async {
    final auth = context.read<AuthRepository>();
    try {
      await auth.signInWithEmailAndPassword(
        _loginEmailController.text,
        _loginPasswordController.text,
      );
    } catch (e) {
      if (!context.mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(milliseconds: 950),
            backgroundColor: Palette.forgedGold,
            content: Center(
              child: Text(
                'invalid credentials. please try again.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleSocialLogin(
    Future<void> Function() socialLoginMethod,
  ) async {
    if (!mounted) {
      return;
    }
    final db = context.read<DatabaseRepository>();

    try {
      // Perform social login
      await socialLoginMethod();

      // Check if widget is still mounted after async operation
      if (!mounted) {
        return;
      }

      // Get the authenticated user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Check if user document exists
        try {
          await db.getCurrentUser();
          // User document exists, app.dart will handle navigation automatically
          return;
        } catch (e) {
          // User document doesn't exist, this user needs to create a profile

          // Get the selected user type and user email
          final selectedUserType = selected.first; // 'dj' or 'booker'
          final userEmail = user.email ?? '';

          // Use Future.microtask for immediate execution after current event loop
          // This executes faster than addPostFrameCallback and avoids widget unmounting
          Future.microtask(() {
            if (selectedUserType == 'dj') {
              globalNavigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(
                  builder:
                      (context) => CreateProfileScreenDJ(
                        email: userEmail,
                        pw: '', // Social login doesn't use password
                      ),
                ),
              );
            } else {
              globalNavigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(
                  builder:
                      (context) => CreateProfileScreenBooker(
                        email: userEmail,
                        pw: '', // Social login doesn't use password
                      ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      // Handle social login errors - only show snackbar if widget is still mounted
      if (mounted) {
        rethrow;
      }
    }
  }

  Future<void> _continueAsGuest() async {
    final db = context.read<DatabaseRepository>();

    try {
      // Get current FCM token to check for existing guest
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        // If FCM token fails, proceed with regular guest creation
        fcmToken = null;
      }

      Guest? existingGuest;

      // Try to find existing guest user with same FCM token
      if (fcmToken != null) {
        try {
          existingGuest = await _findExistingGuestByFCMToken(fcmToken);
        } catch (e) {
          // If search fails, proceed with new guest creation
          existingGuest = null;
        }
      }

      Guest guestUser;

      if (existingGuest != null) {
        // Reuse existing guest - no need to create new Firebase Auth user
        // Just sign in anonymously and then update the existing document with new auth UID
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        final newUid = userCredential.user?.uid;

        if (newUid == null) {
          throw Exception("Failed to create guest authentication");
        }

        // Create guest with existing data but new auth UID
        guestUser = Guest(
          id: newUid,
          name: existingGuest.name,
          favoriteUIds: existingGuest.favoriteUIds,
          avatarImageUrl: existingGuest.avatarImageUrl,
          isFlinta: existingGuest.isFlinta,
        );

        // Update all chat references to use the new UID
        await _migrateChatReferences(existingGuest.id, newUid);

        // Update the user document with new UID (this preserves chat history)
        await _migrateUserDocument(existingGuest.id, newUid, guestUser);
      } else {
        // Create new guest user
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        final uid = userCredential.user?.uid;

        if (uid == null) {
          throw Exception("Failed to create guest authentication");
        }

        guestUser = Guest(
          id: uid,
          name: '',
          favoriteUIds: [],
          avatarImageUrl:
              'https://firebasestorage.googleapis.com/v0/b/gig-hub-8ac24.firebasestorage.app/o/default%2Fdefault_avatar.jpg?alt=media&token=9c48f377-736e-4a9a-bf31-6ffc3ed020f7',
        );
      }

      await db.createGuest(guestUser);

      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(initialUser: guestUser),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.alarmRed,
            content: Center(
              child: Text(
                'failed to continue as guest: ${e.toString()}',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
    }
  }

  /// Migrates chat references from old UID to new UID
  Future<void> _migrateChatReferences(String oldUid, String newUid) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update direct chat messages where user is sender
      final directChatsQuery =
          await FirebaseFirestore.instance
              .collectionGroup('messages')
              .where('senderId', isEqualTo: oldUid)
              .get();

      for (final doc in directChatsQuery.docs) {
        batch.update(doc.reference, {'senderId': newUid});
      }

      // 2. Update direct chat messages where user is receiver
      final receivedChatsQuery =
          await FirebaseFirestore.instance
              .collectionGroup('messages')
              .where('receiverId', isEqualTo: oldUid)
              .get();

      for (final doc in receivedChatsQuery.docs) {
        batch.update(doc.reference, {'receiverId': newUid});
      }

      // 3. Update group chat memberships
      final groupChatsQuery =
          await FirebaseFirestore.instance
              .collection('group_chats')
              .where('memberIds', arrayContains: oldUid)
              .get();

      for (final doc in groupChatsQuery.docs) {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        final updatedMemberIds =
            memberIds.map((id) => id == oldUid ? newUid : id).toList();

        batch.update(doc.reference, {'memberIds': updatedMemberIds});
      }

      // 4. Update group chat messages where user is sender
      final groupMessagesQuery =
          await FirebaseFirestore.instance
              .collectionGroup('messages')
              .where('senderId', isEqualTo: oldUid)
              .get();

      for (final doc in groupMessagesQuery.docs) {
        batch.update(doc.reference, {'senderId': newUid});
      }

      // 5. Update public group chat memberships
      final publicGroupChatsQuery =
          await FirebaseFirestore.instance
              .collection('public_group_chats')
              .where('memberIds', arrayContains: oldUid)
              .get();

      for (final doc in publicGroupChatsQuery.docs) {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        final updatedMemberIds =
            memberIds.map((id) => id == oldUid ? newUid : id).toList();

        batch.update(doc.reference, {'memberIds': updatedMemberIds});
      }

      // 6. Update chat documents that use the user ID in document IDs
      // For direct chats, we need to find chat documents where the user ID is part of the document ID
      final allChatsQuery =
          await FirebaseFirestore.instance.collection('chats').get();

      for (final doc in allChatsQuery.docs) {
        final chatId = doc.id;
        if (chatId.contains(oldUid)) {
          // This chat involves the old user ID
          final data = doc.data();
          final participants = chatId.split('_');

          if (participants.contains(oldUid)) {
            // Create new chat document with updated ID
            final newParticipants =
                participants.map((id) => id == oldUid ? newUid : id).toList();
            newParticipants.sort(); // Maintain consistent ordering
            final newChatId = newParticipants.join('_');

            // Copy the chat document to new location
            final newChatRef = FirebaseFirestore.instance
                .collection('chats')
                .doc(newChatId);
            batch.set(newChatRef, data);

            // Copy all messages to new chat
            final messagesQuery =
                await doc.reference.collection('messages').get();
            for (final messageDoc in messagesQuery.docs) {
              final messageData = messageDoc.data();
              // Update sender/receiver IDs in the message data
              if (messageData['senderId'] == oldUid) {
                messageData['senderId'] = newUid;
              }
              if (messageData['receiverId'] == oldUid) {
                messageData['receiverId'] = newUid;
              }

              final newMessageRef = newChatRef
                  .collection('messages')
                  .doc(messageDoc.id);
              batch.set(newMessageRef, messageData);
            }

            // Delete old chat document (will be done after batch commit)
            batch.delete(doc.reference);
          }
        }
      }

      await batch.commit();
    } catch (_) {
      // Log error but don't fail the entire process
    }
  }

  /// Migrates user document from old UID to new UID
  Future<void> _migrateUserDocument(
    String oldUid,
    String newUid,
    Guest guestUser,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Create new user document
      final newUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(newUid);
      batch.set(newUserRef, guestUser.toJson());

      // Delete old user document
      final oldUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(oldUid);
      batch.delete(oldUserRef);

      await batch.commit();
    } catch (e) {
      // If migration fails, clean up and rethrow
      await FirebaseFirestore.instance.collection('users').doc(newUid).delete();
      rethrow;
    }
  }

  Future<Guest?> _findExistingGuestByFCMToken(String fcmToken) async {
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('type', isEqualTo: 'guest')
              .where('fcmToken', isEqualTo: fcmToken)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Guest.fromJson(doc.id, doc.data());
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    return Scaffold(
      backgroundColor: Palette.primalBlack,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(height: 8),
            Stack(
              children: [
                Positioned(
                  right: 8,
                  top: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Palette.shadowGrey.o(0.25),
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

                            FlutterLocalization.instance.translate(newLanguage);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    spacing: 16,
                    children: [
                      SizedBox(height: 12),
                      SizedBox(
                        height: 132,
                        width: 132,
                        child: Image.asset('assets/images/icon_full.png'),
                      ),
                      SizedBox(
                        height: 48,
                        width: 270,
                        child: LiquidGlass(
                          shape: LiquidRoundedRectangle(
                            borderRadius: Radius.circular(16),
                          ),
                          settings: LiquidGlassSettings(
                            thickness: 30,
                            refractiveIndex: 1.1,
                            chromaticAberration: 1.3,
                          ),
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment<String>(
                                value: 'booker',
                                label: Text(
                                  "booker",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              ButtonSegment<String>(
                                value: 'dj',
                                label: Text(
                                  "    DJ    ",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            selected: selected,
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                selected = newSelection;
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color?>((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Palette.shadowGrey;
                                    }
                                    return Palette.shadowGrey.o(0.35);
                                  }),
                              foregroundColor: WidgetStateProperty.all(
                                Palette.primalBlack,
                              ),
                              textStyle:
                                  WidgetStateProperty.resolveWith<TextStyle?>((
                                    states,
                                  ) {
                                    return TextStyle(
                                      fontWeight:
                                          states.contains(WidgetState.selected)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    );
                                  }),
                              shape: WidgetStateProperty.all<
                                RoundedRectangleBorder
                              >(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Palette.shadowGrey,
                                    width: 2,
                                  ),
                                ),
                              ),
                              padding: WidgetStateProperty.all<EdgeInsets>(
                                const EdgeInsets.symmetric(horizontal: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      SizedBox(
                        width: 310,
                        child: FocusScope(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.dontHaveAnAccount.getString(
                                      context,
                                    ),
                                    style: TextStyle(
                                      color: Palette.glazedWhite,
                                    ),
                                  ),
                                  TextButton(
                                    style: ButtonStyle(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        showDragHandle: true,
                                        backgroundColor: Colors.transparent,
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (BuildContext context) {
                                          return SignUpSheet();
                                        },
                                      );
                                    },
                                    child: Text(
                                      AppLocale.signUp.getString(context),
                                      style: TextStyle(
                                        color: Palette.forgedGold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Palette.glazedWhite,
                                  borderRadius: BorderRadius.circular(16),
                                ),

                                child: AutofillGroup(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        focusNode: _emailFocusNode,
                                        textInputAction: TextInputAction.next,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        autofillHints: [AutofillHints.email],
                                        controller: _loginEmailController,
                                        showCursor: true,
                                        maxLines: 1,
                                        onFieldSubmitted: (value) {
                                          FocusScope.of(
                                            context,
                                          ).requestFocus(_passwordFocusNode);
                                        },
                                        decoration: InputDecoration(
                                          hintText: AppLocale.email.getString(
                                            context,
                                          ),
                                          contentPadding: EdgeInsets.all(12),
                                          border: InputBorder.none,
                                          prefixIcon: Icon(
                                            Icons.email_outlined,
                                            color: Palette.primalBlack,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      Divider(color: Palette.concreteGrey),
                                      TextFormField(
                                        focusNode: _passwordFocusNode,
                                        textInputAction: TextInputAction.done,
                                        keyboardType:
                                            TextInputType.visiblePassword,
                                        autofillHints: [AutofillHints.password],
                                        controller: _loginPasswordController,
                                        showCursor: true,
                                        maxLines: 1,
                                        obscureText: _isObscured,
                                        obscuringCharacter: "✱",
                                        onFieldSubmitted: (value) {
                                          _performLogin();
                                        },
                                        decoration: InputDecoration(
                                          hintText: AppLocale.pw.getString(
                                            context,
                                          ),
                                          contentPadding: EdgeInsets.all(8),
                                          border: InputBorder.none,
                                          prefixIcon: Icon(
                                            Icons.lock_outline_rounded,
                                            color: Palette.primalBlack,
                                            size: 20,
                                          ),
                                          suffixIcon: IconButton(
                                            onPressed:
                                                () => setState(() {
                                                  _isObscured = !_isObscured;
                                                }),
                                            icon:
                                                !_isObscured
                                                    ? Icon(
                                                      Icons.visibility,
                                                      color:
                                                          Palette.concreteGrey,
                                                    )
                                                    : Icon(
                                                      Icons.visibility_off,
                                                      color:
                                                          Palette.concreteGrey,
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          backgroundColor: Palette.forgedGold,

                                          title: Center(
                                            child: Text(
                                              AppLocale.forgotPwText.getString(
                                                context,
                                              ),
                                              style: GoogleFonts.sometypeMono(
                                                textStyle: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          content: TextFormField(
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            controller: emailController,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Palette.primalBlack,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed: () {
                                                auth.sendPasswordResetEmail(
                                                  emailController.text,
                                                );
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor:
                                                        Palette.forgedGold,
                                                    content: Center(
                                                      child: Text(
                                                        AppLocale
                                                            .pwResetLinkSent
                                                            .getString(context),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                AppLocale.sendPwReset.getString(
                                                  context,
                                                ),
                                                style: TextStyle(
                                                  color: Palette.primalBlack,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: Text(
                                                AppLocale.cancel.getString(
                                                  context,
                                                ),
                                                style: TextStyle(
                                                  color: Palette.primalBlack,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                                child: Text(
                                  AppLocale.forgotPw.getString(context),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Palette.glazedWhite.o(0.7),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Palette.glazedWhite.o(0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),

                              LiquidGlass(
                                shape: LiquidRoundedRectangle(
                                  borderRadius: Radius.circular(16),
                                ),
                                settings: LiquidGlassSettings(
                                  thickness: 28,
                                  refractiveIndex: 1.1,
                                  chromaticAberration: 0.35,
                                  glassColor: Palette.forgedGold.o(0.025),
                                ),
                                child: ElevatedButton(
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all<
                                      EdgeInsetsGeometry
                                    >(EdgeInsets.only(left: 90, right: 90)),
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(
                                          Palette.forgedGold.o(0.65),
                                        ),
                                    shape: WidgetStateProperty.all<
                                      OutlinedBorder
                                    >(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: Palette.concreteGrey.o(0.7),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onPressed: _performLogin,
                                  child: Text(
                                    AppLocale.logIn.getString(context),
                                    style: GoogleFonts.sometypeMono(
                                      textStyle: TextStyle(
                                        color: Palette.glazedWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        wordSpacing: -8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Divider(color: Palette.glazedWhite.o(0.5)),
                          ),
                          Text(
                            AppLocale.or.getString(context),
                            style: TextStyle(
                              color: Palette.glazedWhite,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Divider(color: Palette.glazedWhite.o(0.5)),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 68,
                        width: 300,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: () async {
                                  await _handleSocialLogin(() async {
                                    try {
                                      await auth.signInWithApple();
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Palette.alarmRed,
                                          duration: Duration(seconds: 5),
                                          content: Center(
                                            child: Text(
                                              'Apple Sign In Error: ${e.toString()}',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                color: Palette.glazedWhite,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                      rethrow; // Re-throw to be handled by _handleSocialLogin
                                    }
                                  });
                                },
                                icon: Image.asset(
                                  'assets/images/apple_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await _handleSocialLogin(() async {
                                    try {
                                      await auth.signInWithGoogle();
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Palette.forgedGold,
                                          content: Center(
                                            child: Text(
                                              'access failed. please try again.',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      );
                                      rethrow;
                                    }
                                  });
                                },
                                icon: Image.asset(
                                  'assets/images/google_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        color: Palette.glazedWhite.o(0.5),
                        indent: 8,
                        endIndent: 8,
                      ),
                      SizedBox(height: 16),
                      LiquidGlass(
                        shape: LiquidRoundedRectangle(
                          borderRadius: Radius.circular(16),
                        ),
                        settings: LiquidGlassSettings(
                          thickness: 24,
                          refractiveIndex: 1.1,
                          chromaticAberration: 0.35,
                        ),
                        child: Shimmer.fromColors(
                          period: Duration(milliseconds: 2600),
                          baseColor: Palette.glazedWhite,
                          highlightColor: Palette.forgedGold,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.transparent,
                                padding: EdgeInsets.only(left: 32, right: 32),

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Palette.glazedWhite.o(0.7),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onPressed: () async {
                                await _continueAsGuest();
                              },
                              child: Text(
                                AppLocale.continueAsGuest.getString(context),
                                style: GoogleFonts.sometypeMono(
                                  textStyle: TextStyle(
                                    color: Palette.primalBlack,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
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
          ],
        ),
      ),
    );
  }
}
