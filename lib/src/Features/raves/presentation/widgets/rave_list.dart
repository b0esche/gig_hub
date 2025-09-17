import 'package:intl/intl.dart';
import '../../domain/rave.dart';
import 'rave_tile.dart';
import 'join_public_group_chat_dialog.dart';
import '../dialogs/rave_detail_dialog.dart';
import '../dialogs/create_rave_dialog.dart';
import '../dialogs/edit_rave_dialog.dart';
import '../../../../Data/app_imports.dart';
import '../../../../Data/services/rave_cleanup_service.dart';

class RaveList extends StatefulWidget {
  final String? userId; // If null, shows current user's raves
  final bool showCreateButton;
  final bool showOnlyUpcoming;

  const RaveList({
    super.key,
    this.userId,
    this.showCreateButton = false,
    this.showOnlyUpcoming = false,
  });

  @override
  State<RaveList> createState() => _RaveListState();
}

class _RaveListState extends State<RaveList> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final Map<String, String> _userNameCache = {};
  StreamController<List<Rave>>? _raveStreamController;

  @override
  void dispose() {
    _userNameCache.clear();
    _raveStreamController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetUserId = widget.userId ?? currentUser?.uid;

    if (targetUserId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              ' upcoming gigs',
              style: GoogleFonts.sometypeMono(
                textStyle: TextStyle(
                  color: Palette.glazedWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),

            if (widget.showCreateButton && targetUserId == currentUser?.uid)
              IconButton(
                onPressed: _showCreateRaveDialog,
                icon: Icon(Icons.add, color: Palette.forgedGold, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
          ],
        ),

        StreamBuilder<List<Rave>>(
          stream: _buildCombinedRaveStream(targetUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Palette.forgedGold,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              // Log the error for debugging

              // Always show empty state instead of error for better UX
              // Most "errors" are actually just empty collections or permission issues
              return _buildEmptyState(targetUserId);
            }

            final raves = snapshot.data ?? [];

            // Filter and sort raves
            final filteredRaves = _filterAndSortRaves(raves);

            if (filteredRaves.isEmpty) {
              return _buildEmptyState(targetUserId);
            }

            return Column(
              children:
                  filteredRaves
                      .map(
                        (rave) => RaveTile(
                          rave: rave,
                          isAttending: rave.attendingUserIds.contains(
                            currentUser?.uid,
                          ),
                          onTap: () => _showRaveDetail(rave),
                          onAttendToggle:
                              targetUserId != currentUser?.uid
                                  ? () => _toggleAttendance(rave)
                                  : null,
                          showAttendButton: targetUserId != currentUser?.uid,
                          showOrganizerOptions:
                              targetUserId == currentUser?.uid &&
                              rave.organizerId == currentUser?.uid,
                          onEdit:
                              targetUserId == currentUser?.uid &&
                                      rave.organizerId == currentUser?.uid
                                  ? () => _showEditRaveDialog(rave)
                                  : null,
                          onDelete:
                              targetUserId == currentUser?.uid &&
                                      rave.organizerId == currentUser?.uid
                                  ? () => _showDeleteRaveDialog(rave)
                                  : null,
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(String? targetUserId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.shadowGrey.o(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.gigGrey),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event, color: Palette.glazedWhite.o(0.3), size: 32),
            const SizedBox(height: 8),
            Text(
              widget.showCreateButton && targetUserId == currentUser?.uid
                  ? 'no upcoming gigs yet. create your first one!'
                  : 'no upcoming gigs',
              style: TextStyle(color: Palette.glazedWhite.o(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Fetches all raves where the user is involved (organizer, DJ, or collaborator)
  Stream<List<Rave>> _buildCombinedRaveStream(String userId) {
    // Close existing controller if any
    _raveStreamController?.close();

    final query = FirebaseFirestore.instance.collection('raves');
    _raveStreamController = StreamController<List<Rave>>();

    List<Rave> organizerRaves = [];
    List<Rave> djRaves = [];
    List<Rave> collaboratorRaves = [];

    void updateCombinedRaves() {
      final Map<String, Rave> allRaves = {};

      // Add organizer raves
      for (final rave in organizerRaves) {
        allRaves[rave.id] = rave;
      }

      // Add DJ raves (avoiding duplicates)
      for (final rave in djRaves) {
        allRaves[rave.id] = rave;
      }

      // Add collaborator raves (avoiding duplicates)
      for (final rave in collaboratorRaves) {
        allRaves[rave.id] = rave;
      }

      if (!_raveStreamController!.isClosed) {
        _raveStreamController!.add(allRaves.values.toList());
      }
    }

    // Listen to organizer stream
    final organizerSub = query
        .where('organizerId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) {
            organizerRaves =
                snapshot.docs.map((doc) => Rave.fromJson(doc.data())).toList();
            updateCombinedRaves();
          },
          onError: (e) {
            organizerRaves = [];
            updateCombinedRaves();
          },
        );

    // Listen to DJ stream
    final djSub = query
        .where('djIds', arrayContains: userId)
        .snapshots()
        .listen(
          (snapshot) {
            djRaves =
                snapshot.docs.map((doc) => Rave.fromJson(doc.data())).toList();
            updateCombinedRaves();
          },
          onError: (e) {
            djRaves = [];
            updateCombinedRaves();
          },
        );

    // Listen to collaborator stream
    final collaboratorSub = query
        .where('collaboratorIds', arrayContains: userId)
        .snapshots()
        .listen(
          (snapshot) {
            collaboratorRaves =
                snapshot.docs.map((doc) => Rave.fromJson(doc.data())).toList();
            updateCombinedRaves();
          },
          onError: (e) {
            collaboratorRaves = [];
            updateCombinedRaves();
          },
        );

    // Clean up subscriptions when stream is closed
    _raveStreamController!.onCancel = () {
      organizerSub.cancel();
      djSub.cancel();
      collaboratorSub.cancel();
    };

    return _raveStreamController!.stream;
  }

  List<Rave> _filterAndSortRaves(List<Rave> raves) {
    var filtered = raves;

    // Always filter out expired raves (ended more than 24 hours ago)
    filtered =
        filtered.where((rave) {
          return !RaveCleanupService.shouldCleanupRave(
            rave.startDate,
            rave.endDate,
          );
        }).toList();

    if (widget.showOnlyUpcoming) {
      final now = DateTime.now();
      filtered = filtered.where((rave) => rave.startDate.isAfter(now)).toList();
    }

    // Sort by date (upcoming first, then past events)
    filtered.sort((a, b) {
      final now = DateTime.now();
      final aUpcoming = a.startDate.isAfter(now);
      final bUpcoming = b.startDate.isAfter(now);

      if (aUpcoming && !bUpcoming) return -1;
      if (!aUpcoming && bUpcoming) return 1;

      return a.startDate.compareTo(b.startDate);
    });

    return filtered;
  }

  void _showCreateRaveDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateRaveDialog(),
    );
  }

  Future<AppUser?> _getUser(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return AppUser.fromJson(userId, userData);
      }
    } catch (_) {}
    return null;
  }

  Future<List<AppUser>> _getUsers(List<String> userIds) async {
    final users = <AppUser>[];
    for (final userId in userIds) {
      final user = await _getUser(userId);
      if (user != null) {
        users.add(user);
      }
    }
    return users;
  }

  void _showRaveDetail(Rave rave) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.primalBlack,
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Palette.forgedGold),
                ),
                const SizedBox(width: 16),
                Text(
                  'loading details...',
                  style: TextStyle(color: Palette.glazedWhite),
                ),
              ],
            ),
          ),
    );

    try {
      // Fetch user objects instead of just names
      final djUsers = await _getUsers(rave.djIds);
      final collaboratorUsers = await _getUsers(rave.collaboratorIds);
      final organizerUser = await _getUser(rave.organizerId);

      String organizerName = 'unknown';
      String? organizerAvatarUrl;

      if (organizerUser != null) {
        if (organizerUser is DJ) {
          organizerName = organizerUser.name;
          organizerAvatarUrl = organizerUser.avatarImageUrl;
        } else if (organizerUser is Booker) {
          organizerName = organizerUser.name;
          organizerAvatarUrl = organizerUser.avatarImageUrl;
        }
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show actual detail dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => RaveDetailDialog(
                rave: rave,
                isAttending: rave.attendingUserIds.contains(currentUser?.uid),
                onAttendToggle:
                    currentUser?.uid != rave.organizerId
                        ? () => _toggleAttendance(rave)
                        : null,
                djs: djUsers,
                collaborators: collaboratorUsers,
                organizerName: organizerName,
                organizerAvatarUrl: organizerAvatarUrl,
              ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to load rave details'),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  Future<void> _toggleAttendance(Rave rave) async {
    if (currentUser == null) return;

    try {
      final raveRef = FirebaseFirestore.instance
          .collection('raves')
          .doc(rave.id);
      final isCurrentlyAttending = rave.attendingUserIds.contains(
        currentUser!.uid,
      );

      if (isCurrentlyAttending) {
        // Remove user from attending list
        await raveRef.update({
          'attendingUserIds': FieldValue.arrayRemove([currentUser!.uid]),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // Add user to attending list
        await raveRef.update({
          'attendingUserIds': FieldValue.arrayUnion([currentUser!.uid]),
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // After successfully joining rave, ask if user wants to join public group chat
        if (mounted) {
          final db = context.read<DatabaseRepository>();
          final appUser = await db.getCurrentUser();

          await showDialog(
            context: context,
            builder:
                (context) => JoinPublicGroupChatDialog(
                  raveId: rave.id,
                  raveTitle: rave.name,
                  currentUser: appUser,
                ),
          );
        }
      }

      // Success - no snackbar needed since UI updates immediately
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to update attendance'),
            backgroundColor: Palette.alarmRed,
            action: SnackBarAction(
              label: 'retry',
              textColor: Palette.glazedWhite,
              onPressed: () => _toggleAttendance(rave),
            ),
          ),
        );
      }
    }
  }

  void _showEditRaveDialog(Rave rave) {
    showDialog(
      context: context,
      builder: (context) => EditRaveDialog(rave: rave),
    );
  }

  void _showDeleteRaveDialog(Rave rave) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Palette.forgedGold, width: 2),
            ),
            title: Text(
              AppLocale.confirmDeleteRave.getString(context),
              style: GoogleFonts.sometypeMono(
                textStyle: TextStyle(
                  color: Palette.glazedWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocale.deleteRaveWarning.getString(context),
                  style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.shadowGrey.o(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.forgedGold.o(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rave.name,
                        style: TextStyle(
                          color: Palette.forgedGold,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rave.location} • ${DateFormat('MMM dd, yyyy').format(rave.startDate)}',
                        style: TextStyle(
                          color: Palette.glazedWhite.o(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocale.cancel.getString(context),
                  style: TextStyle(color: Palette.glazedWhite),
                ),
              ),
              ElevatedButton(
                onPressed: () => _deleteRave(rave),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.alarmRed,
                  foregroundColor: Palette.glazedWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocale.deleteRave.getString(context),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteRave(Rave rave) async {
    try {
      // Close the confirmation dialog
      Navigator.of(context).pop();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: Palette.primalBlack,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Palette.forgedGold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'deleting rave...',
                    style: TextStyle(color: Palette.glazedWhite),
                  ),
                ],
              ),
            ),
      );

      // Delete the rave from Firebase
      final db = context.read<DatabaseRepository>();
      await db.deleteRave(rave.id);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.raveDeleted.getString(context)),
            backgroundColor: Palette.forgedGold,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocale.raveDeleteFailed.getString(context)}: $e',
            ),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }
}
