import '../../../../Data/app_imports.dart';

/// Wrapper screen that loads a booker profile by ID and displays it
///
/// This is used for deep linking from notifications and other external sources
/// where we only have the booker's ID but need to load the full profile data.
class BookerProfileLoaderScreen extends StatefulWidget {
  final String bookerId;
  final String? highlightedRaveId;

  const BookerProfileLoaderScreen({
    super.key,
    required this.bookerId,
    this.highlightedRaveId,
  });

  @override
  State<BookerProfileLoaderScreen> createState() =>
      _BookerProfileLoaderScreenState();
}

class _BookerProfileLoaderScreenState extends State<BookerProfileLoaderScreen> {
  Booker? _booker;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooker();
  }

  /// Load booker data by ID
  Future<void> _loadBooker() async {
    try {
      final db = Provider.of<DatabaseRepository>(context, listen: false);
      final user = await db.getUserById(widget.bookerId);

      if (user is Booker) {
        setState(() {
          _booker = user;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'User is not a booker';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load booker profile: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Palette.primalBlack,
        appBar: AppBar(
          backgroundColor: Palette.primalBlack,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Palette.glazedWhite),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Loading Profile...',
            style: TextStyle(color: Palette.glazedWhite),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Palette.forgedGold),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading booker profile...',
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

    if (_error != null) {
      return Scaffold(
        backgroundColor: Palette.primalBlack,
        appBar: AppBar(
          backgroundColor: Palette.primalBlack,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Palette.glazedWhite),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Error', style: TextStyle(color: Palette.glazedWhite)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Palette.alarmRed, size: 64),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  style: TextStyle(color: Palette.glazedWhite, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadBooker();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.forgedGold,
                  foregroundColor: Palette.primalBlack,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_booker != null) {
      final db = Provider.of<DatabaseRepository>(context, listen: false);
      return ProfileScreenBooker(
        booker: _booker!,
        db: db,
        showEditButton:
            false, // Don't show edit button when viewing from notification
      );
    }

    // This shouldn't happen, but just in case
    return Scaffold(
      backgroundColor: Palette.primalBlack,
      body: Center(
        child: Text(
          'Something went wrong',
          style: TextStyle(color: Palette.glazedWhite),
        ),
      ),
    );
  }
}
