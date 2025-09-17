import '../../../../../../Data/app_imports.dart';
import '../../../../../../Data/services/rave_cleanup_service.dart';
import '../../../../domain/rave.dart';
import '../../rave_tile.dart';
import '../../join_public_group_chat_dialog.dart';
import '../../../dialogs/rave_detail_dialog.dart';
import '../rave_alerts/presentation/setup_rave_alert_dialog.dart';

/// Rave Radar Screen - Discover all raves with advanced search capabilities
///
/// Features:
/// - View all available raves in a scrollable list
/// - Real-time search across multiple fields:
///   * Rave names
///   * DJ names and genres
///   * Booker/organizer names
///   * City/location names
/// - Debounced search to optimize performance
/// - Loading states and empty state handling
/// - Navigation to individual rave details
class RaveRadarScreen extends StatefulWidget {
  const RaveRadarScreen({super.key});

  @override
  State<RaveRadarScreen> createState() => _RaveRadarScreenState();
}

class _RaveRadarScreenState extends State<RaveRadarScreen> {
  final TextEditingController _searchController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  Timer? _searchDebouncer;
  List<Rave> _allRaves = [];
  List<Rave> _filteredRaves = [];
  final Map<String, AppUser> _userCache = {}; // Cache for DJ and organizer data
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllRaves();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  /// Loads all raves from Firestore directly
  Future<void> _loadAllRaves() async {
    setState(() => _isLoading = true);

    try {
      // Get all raves from Firestore
      final ravesSnapshot =
          await FirebaseFirestore.instance.collection('raves').get();

      final raves =
          ravesSnapshot.docs.map((doc) => Rave.fromJson(doc.data())).toList();

      // Filter out expired raves (ended more than 24 hours ago)
      final activeRaves =
          raves.where((rave) {
            return !RaveCleanupService.shouldCleanupRave(
              rave.startDate,
              rave.endDate,
            );
          }).toList();

      // Preload user data for better search performance
      await _preloadUserData(activeRaves);

      setState(() {
        _allRaves = activeRaves;
        _filteredRaves = activeRaves;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocale.failedLoadRaves.getString(context)}: $e',
            ),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  /// Preloads user data (DJs, organizers, collaborators) for efficient searching
  Future<void> _preloadUserData(List<Rave> raves) async {
    final Set<String> userIds = {};

    // Collect all unique user IDs from raves
    for (final rave in raves) {
      userIds.add(rave.organizerId);
      userIds.addAll(rave.djIds);
      userIds.addAll(rave.collaboratorIds);
    }

    // Batch load user data
    for (final userId in userIds) {
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final user = AppUser.fromJson(userId, userData);
          _userCache[userId] = user;
        }
      } catch (e) {
        // Skip users that can't be loaded
        continue;
      }
    }
  }

  /// Handles search input changes with debouncing
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    // Cancel previous search
    _searchDebouncer?.cancel();

    // Debounce search to avoid excessive filtering
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// Performs the actual search across all rave fields
  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _filteredRaves = _allRaves;
        _isSearching = false;
      });
      return;
    }

    final filtered =
        _allRaves.where((rave) {
          // Search in rave name
          if (rave.name.toLowerCase().contains(query)) return true;

          // Search in location/city
          if (rave.location.toLowerCase().contains(query)) return true;

          // Search in description
          if (rave.description.toLowerCase().contains(query)) return true;

          // Search in organizer name
          final organizer = _userCache[rave.organizerId];
          if (organizer != null) {
            final organizerName = _getUserDisplayName(organizer).toLowerCase();
            if (organizerName.contains(query)) return true;
          }

          // Search in DJ names and genres
          for (final djId in rave.djIds) {
            final dj = _userCache[djId];
            if (dj != null) {
              final djName = _getUserDisplayName(dj).toLowerCase();
              if (djName.contains(query)) return true;

              // Search in DJ genres
              if (dj is DJ && dj.genres.isNotEmpty) {
                for (final genre in dj.genres) {
                  if (genre.toLowerCase().contains(query)) return true;
                }
              }
            }
          }

          // Search in collaborator names
          for (final collabId in rave.collaboratorIds) {
            final collaborator = _userCache[collabId];
            if (collaborator != null) {
              final collabName =
                  _getUserDisplayName(collaborator).toLowerCase();
              if (collabName.contains(query)) return true;
            }
          }

          return false;
        }).toList();

    setState(() {
      _filteredRaves = filtered;
      _isSearching = false;
    });
  }

  /// Gets display name for any user type
  String _getUserDisplayName(AppUser user) {
    if (user is DJ) return user.name;
    if (user is Booker) return user.name;
    if (user is Guest) {
      return AppLocale.guest.getString(
        context,
      ); // Guest doesn't have a name field
    }
    return AppLocale.unknown.getString(context);
  }

  /// Gets a user by ID from Firestore
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

  /// Gets multiple users by their IDs
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.primalBlack,
      appBar: AppBar(
        title: Text(
          AppLocale.raveRadar.getString(context),
          style: TextStyle(
            color: Palette.glazedWhite,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Palette.primalBlack,
        iconTheme: IconThemeData(color: Palette.glazedWhite),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Rave Alerts Button
          _buildRaveAlertsButton(),

          // Search Bar
          _buildSearchBar(),

          // Results
          Expanded(child: _buildRavesList()),
        ],
      ),
    );
  }

  /// Builds the rave alerts button above the search bar
  Widget _buildRaveAlertsButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const SetupRaveAlertDialog(),
          );
        },
        icon: Icon(
          Icons.notifications_active,
          size: 18,
          color: Palette.primalBlack,
        ),
        label: Text(
          AppLocale.raveAlerts.getString(context),
          style: TextStyle(
            color: Palette.primalBlack,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.forgedGold,
          foregroundColor: Palette.primalBlack,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: Palette.forgedGold.o(0.3),
        ),
      ),
    );
  }

  /// Builds the search input field with loading indicator
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.gigGrey.o(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.gigGrey.o(0.5), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Palette.glazedWhite),
        decoration: InputDecoration(
          hintText: AppLocale.searchRavesDjsGenres.getString(context),
          hintStyle: TextStyle(color: Palette.glazedWhite.o(0.6)),
          prefixIcon: Icon(Icons.search, color: Palette.forgedGold),
          suffixIcon:
              _isSearching
                  ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Palette.forgedGold,
                        ),
                      ),
                    ),
                  )
                  : _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.clear, color: Palette.glazedWhite.o(0.6)),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  /// Builds the main raves list with loading and empty states
  Widget _buildRavesList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Palette.forgedGold),
            const SizedBox(height: 16),
            Text(
              AppLocale.loadingRaves.getString(context),
              style: TextStyle(color: Palette.glazedWhite.o(0.7), fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_filteredRaves.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Palette.glazedWhite.o(0.3)),
            const SizedBox(height: 16),
            Text(
              AppLocale.noRavesFound.getString(context),
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocale.tryDifferentKeywords.getString(context),
              style: TextStyle(color: Palette.glazedWhite.o(0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_allRaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Palette.glazedWhite.o(0.3)),
            const SizedBox(height: 16),
            Text(
              AppLocale.noRavesAvailable.getString(context),
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocale.checkBackLater.getString(context),
              style: TextStyle(color: Palette.glazedWhite.o(0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllRaves,
      color: Palette.forgedGold,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _filteredRaves.length,
        itemBuilder: (context, index) {
          final rave = _filteredRaves[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: RaveTile(
              rave: rave,
              isAttending: rave.attendingUserIds.contains(currentUser?.uid),
              onTap: () => _showRaveDetail(rave),
              onAttendToggle:
                  currentUser?.uid != rave.organizerId
                      ? () => _toggleAttendance(rave)
                      : null,
              showAttendButton: currentUser?.uid != rave.organizerId,
            ),
          );
        },
      ),
    );
  }

  /// Shows detailed rave information dialog
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
                  AppLocale.loadingDetails.getString(context),
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

      String organizerName = AppLocale.unknown.getString(context);
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
            content: Text(AppLocale.failedLoadRaveDetails.getString(context)),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  /// Toggles user attendance for a rave
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

      // Update local state
      setState(() {
        final raveIndex = _filteredRaves.indexWhere((r) => r.id == rave.id);
        if (raveIndex != -1) {
          final attendingUsers = List<String>.from(rave.attendingUserIds);
          if (isCurrentlyAttending) {
            attendingUsers.remove(currentUser!.uid);
          } else {
            attendingUsers.add(currentUser!.uid);
          }
          _filteredRaves[raveIndex] = rave.copyWith(
            attendingUserIds: attendingUsers,
          );
        }
      });

      // Success - no snackbar needed since UI updates immediately
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.failedUpdateAttendance.getString(context)),
            backgroundColor: Palette.alarmRed,
            action: SnackBarAction(
              label: AppLocale.retry.getString(context),
              textColor: Palette.glazedWhite,
              onPressed: () => _toggleAttendance(rave),
            ),
          ),
        );
      }
    }
  }
}
