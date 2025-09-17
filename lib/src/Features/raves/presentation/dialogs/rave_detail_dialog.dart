import 'package:intl/intl.dart';
import '../../domain/rave.dart';
import '../../../../Data/app_imports.dart';

class RaveDetailDialog extends StatefulWidget {
  final Rave rave;
  final bool isAttending;
  final VoidCallback? onAttendToggle;
  final List<AppUser> djs;
  final List<AppUser> collaborators;
  final String organizerName;
  final String? organizerAvatarUrl;

  const RaveDetailDialog({
    super.key,
    required this.rave,
    this.isAttending = false,
    this.onAttendToggle,
    this.djs = const [],
    this.collaborators = const [],
    this.organizerName = 'Unknown',
    this.organizerAvatarUrl,
  });

  @override
  State<RaveDetailDialog> createState() => _RaveDetailDialogState();
}

class _RaveDetailDialogState extends State<RaveDetailDialog> {
  late bool _isAttending;

  @override
  void initState() {
    super.initState();
    _isAttending = widget.isAttending;
  }

  void _handleAttendToggle() {
    setState(() {
      _isAttending = !_isAttending;
    });
    widget.onAttendToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Palette.forgedGold, width: 2),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.rave.name,
              style: TextStyle(
                color: Palette.forgedGold,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Palette.glazedWhite.o(0.7)),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(Icons.location_on, widget.rave.location),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.calendar_today, _formatDate()),
              if (widget.rave.startTime.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.access_time, widget.rave.startTime),
              ],

              if (widget.rave.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(
                  AppLocale.raveDescription.getString(context),
                  widget.rave.description,
                ),
              ],

              const SizedBox(height: 16),
              _buildSection(
                AppLocale.organizer.getString(context),
                widget.organizerName,
              ),

              if (widget.djs.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDJSection(),
              ],

              if (widget.collaborators.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCollaboratorsSection(),
              ],

              if (widget.rave.attendingUserIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(
                  AppLocale.attending.getString(context),
                  '${widget.rave.attendingUserIds.length} people',
                ),
              ],

              if (widget.rave.ticketShopLink != null ||
                  widget.rave.additionalLink != null) ...[
                const SizedBox(height: 16),
                _buildLinksSection(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onAttendToggle != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleAttendToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isAttending ? Colors.transparent : const Color(0xFFD4AF37),
                foregroundColor:
                    _isAttending ? const Color(0xFFD4AF37) : Colors.black,
                side: BorderSide(color: const Color(0xFFD4AF37), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _isAttending ? 'leave event' : 'attend event',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDJSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DJs',
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.djs.map((dj) => _buildUserAvatar(dj)).toList(),
        ),
      ],
    );
  }

  Widget _buildCollaboratorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'collaborators',
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              widget.collaborators
                  .map((user) => _buildUserAvatar(user))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(AppUser user) {
    return Builder(
      builder:
          (context) => GestureDetector(
            onTap: () => _navigateToUserProfile(user, context),
            child: SizedBox(
              width: 80, // Increased width to accommodate name
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child:
                          user.avatarUrl.isNotEmpty
                              ? Image.network(
                                user.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF333333),
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFFD4AF37),
                                      size: 25,
                                    ),
                                  );
                                },
                              )
                              : Container(
                                color: const Color(0xFF333333),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFFD4AF37),
                                  size: 25,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'links',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.rave.ticketShopLink != null)
          _buildLinkButton(
            'tickets',
            widget.rave.ticketShopLink!,
            Icons.confirmation_number,
          ),
        if (widget.rave.additionalLink != null) ...[
          if (widget.rave.ticketShopLink != null) const SizedBox(height: 8),
          _buildLinkButton(
            'More Info',
            widget.rave.additionalLink!,
            Icons.link,
          ),
        ],
      ],
    );
  }

  Widget _buildLinkButton(String label, String url, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD4AF37),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  String _formatDate() {
    if (widget.rave.endDate != null) {
      final startFormat = DateFormat('MMM dd');
      final endFormat =
          widget.rave.startDate.year == widget.rave.endDate!.year
              ? DateFormat('MMM dd, yyyy')
              : DateFormat('MMM dd, yyyy');

      return '${startFormat.format(widget.rave.startDate)} - ${endFormat.format(widget.rave.endDate!)}';
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(widget.rave.startDate);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }

  void _navigateToUserProfile(AppUser user, BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          if (user is DJ) {
            return ProfileScreenDJ(
              dj: user,
              showChatButton:
                  false, // Disable chat since we don't have current user context
              showEditButton: true,
              showFavoriteIcon: true,
              currentUser: Guest(
                id: '',
                avatarImageUrl: '',
              ), // Placeholder guest user
            );
          } else if (user is Booker) {
            return ProfileScreenBooker(
              booker: user,
              showEditButton: true,
              db: CachedFirestoreRepository(),
            );
          } else {
            // For Guest users, you could show a simple info dialog or profile view
            return Scaffold(
              appBar: AppBar(
                title: Text(user.displayName),
                backgroundColor: Palette.primalBlack,
                foregroundColor: Palette.glazedWhite,
              ),
              backgroundColor: Palette.primalBlack,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Palette.forgedGold.o(0.2),
                      backgroundImage:
                          user.avatarUrl.isNotEmpty
                              ? NetworkImage(user.avatarUrl)
                              : null,
                      child:
                          user.avatarUrl.isEmpty
                              ? Icon(
                                Icons.person,
                                size: 60,
                                color: Palette.forgedGold,
                              )
                              : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      user.displayName,
                      style: TextStyle(
                        color: Palette.glazedWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'guest user',
                      style: TextStyle(
                        color: Palette.glazedWhite.o(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
