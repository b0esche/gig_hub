import 'package:gig_hub/src/Data/app_imports.dart';

class BlockedUsersDialog extends StatefulWidget {
  const BlockedUsersDialog({super.key});

  @override
  State<BlockedUsersDialog> createState() => _BlockedUsersDialogState();
}

class _BlockedUsersDialogState extends State<BlockedUsersDialog> {
  final FirestoreDatabaseRepository _db = FirestoreDatabaseRepository();
  List<AppUser> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final currentUser = await _db.getCurrentUser();
      final blockedUsers = await _db.getBlockedUsers(currentUser.id);
      setState(() {
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(AppUser user) async {
    try {
      final currentUser = await _db.getCurrentUser();
      await _db.unblockUser(currentUser.id, user.id);
      setState(() {
        _blockedUsers.removeWhere((blockedUser) => blockedUser.id == user.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.forgedGold,
            content: Center(
              child: Text(
                'user unblocked successfully.',
                style: TextStyle(color: Palette.glazedWhite, fontSize: 16),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.alarmRed,
            content: Center(
              child: Text(
                'failed to unblock user. please try again.',
                style: TextStyle(color: Palette.glazedWhite, fontSize: 16),
              ),
            ),
          ),
        );
      }
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
              height: 400,
              width: 320,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: Palette.shadowGrey.o(0.6),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        AppLocale.blocks.getString(context),
                        style: GoogleFonts.sometypeMono(
                          textStyle: TextStyle(
                            color: Palette.primalBlack,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Expanded(
                        child:
                            _isLoading
                                ? Center(
                                  child: CircularProgressIndicator(
                                    color: Palette.forgedGold,
                                    strokeWidth: 1.85,
                                  ),
                                )
                                : _blockedUsers.isEmpty
                                ? Center(
                                  child: Text(
                                    AppLocale.noBlockedUsers.getString(context),
                                    style: GoogleFonts.sometypeMono(
                                      textStyle: TextStyle(
                                        color: Palette.primalBlack.o(0.85),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _blockedUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _blockedUsers[index];
                                    final hasAvatar =
                                        user is DJ || user is Booker;
                                    final avatarUrl =
                                        hasAvatar
                                            ? (user is DJ
                                                ? user.avatarImageUrl
                                                : (user as Booker)
                                                    .avatarImageUrl)
                                            : null;

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 8),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Palette.glazedWhite.o(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Palette.primalBlack.o(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 18,
                                              backgroundImage:
                                                  hasAvatar && avatarUrl != null
                                                      ? (avatarUrl.startsWith(
                                                            'http',
                                                          )
                                                          ? NetworkImage(
                                                            avatarUrl,
                                                          )
                                                          : FileImage(
                                                            File(avatarUrl),
                                                          ))
                                                      : null,
                                              child:
                                                  hasAvatar && avatarUrl != null
                                                      ? null
                                                      : Icon(
                                                        Icons.person,
                                                        color: Palette
                                                            .primalBlack
                                                            .o(0.6),
                                                        size: 20,
                                                      ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          // Name
                                          Expanded(
                                            child: Text(
                                              hasAvatar
                                                  ? (user is DJ
                                                      ? user.name
                                                      : (user as Booker).name)
                                                  : 'guest user',
                                              style: GoogleFonts.sometypeMono(
                                                textStyle: TextStyle(
                                                  color: Palette.primalBlack,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Unblock button
                                          SizedBox(
                                            height: 28,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Palette
                                                    .forgedGold
                                                    .o(0.8),
                                                foregroundColor:
                                                    Palette.primalBlack,
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                              onPressed:
                                                  () => _unblockUser(user),
                                              child: Text(
                                                AppLocale.unblock.getString(
                                                  context,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.close_rounded,
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
