import '../../../Data/app_imports.dart';

class GuestUsernameDialog extends StatefulWidget {
  final Guest guestUser;
  final VoidCallback? onUsernameSet;

  const GuestUsernameDialog({
    super.key,
    required this.guestUser,
    this.onUsernameSet,
  });

  @override
  State<GuestUsernameDialog> createState() => _GuestUsernameDialogState();
}

class _GuestUsernameDialogState extends State<GuestUsernameDialog> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current name if it exists
    if (widget.guestUser.name.isNotEmpty) {
      _usernameController.text = widget.guestUser.name;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username';
      });
      return;
    }

    if (username.length < 2) {
      setState(() {
        _errorMessage = 'Username must be at least 2 characters';
      });
      return;
    }

    if (username.length > 20) {
      setState(() {
        _errorMessage = 'Username must be less than 20 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = context.read<DatabaseRepository>();

      // Update the guest user's name
      final updatedGuest = Guest(
        id: widget.guestUser.id,
        name: username,
        avatarImageUrl: widget.guestUser.avatarImageUrl,
        favoriteUIds: widget.guestUser.favoriteUIds,
      );

      await db.updateUser(updatedGuest);

      if (widget.onUsernameSet != null) {
        widget.onUsernameSet!();
      }

      if (mounted) {
        Navigator.of(context).pop(updatedGuest);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save username. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.guestUser.name.isEmpty ? 'Choose a Username' : 'Change Username',
        style: TextStyle(
          color: Palette.glazedWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.guestUser.name.isEmpty
                ? 'To join group chats, please choose a username that other users will see.'
                : 'Enter a new username for group chats.',
            style: TextStyle(color: Palette.glazedWhite.o(0.8), fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            style: TextStyle(color: Palette.glazedWhite),
            decoration: InputDecoration(
              hintText: 'Enter username...',
              hintStyle: TextStyle(color: Palette.glazedWhite.o(0.5)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Palette.forgedGold.o(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Palette.forgedGold, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              errorText: _errorMessage,
            ),
            maxLength: 20,
            enabled: !_isLoading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Palette.glazedWhite.o(0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUsername,
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.forgedGold,
            foregroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Palette.primalBlack,
                      ),
                    ),
                  )
                  : Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
