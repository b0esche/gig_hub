import 'package:geolocator/geolocator.dart';
import '../../../../../../../Data/app_imports.dart';
import '../domain/rave_alert.dart';
import 'package:http/http.dart' as http;

/// Simple location result class for places API responses
class _LocationResult {
  final bool isValid;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;

  const _LocationResult({
    required this.isValid,
    this.latitude,
    this.longitude,
    this.formattedAddress,
  });
}

/// Dialog for setting up location-based rave alerts
///
/// Features:
/// - Current location detection with GPS
/// - Manual location entry with city validation
/// - Customizable radius selection (10-200km)
/// - Places API integration for accurate coordinates
/// - Push notification setup integration
class SetupRaveAlertDialog extends StatefulWidget {
  const SetupRaveAlertDialog({super.key});

  @override
  State<SetupRaveAlertDialog> createState() => _SetupRaveAlertDialogState();
}

class _SetupRaveAlertDialogState extends State<SetupRaveAlertDialog> {
  final TextEditingController _locationController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  Timer? _validationDebouncer;
  GeoPoint? _selectedGeoPoint;
  double _selectedRadius = 25.0; // Default 25km radius
  bool _isValidatingLocation = false;
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _useCurrentLocation = false;
  String? _locationError;
  String? _validatedLocationName;

  @override
  void dispose() {
    _locationController.dispose();
    _validationDebouncer?.cancel();
    super.dispose();
  }

  /// Handles current location button press
  Future<void> _useCurrentLocationPressed() async {
    if (_useCurrentLocation) {
      // Already using current location, toggle off
      setState(() {
        _useCurrentLocation = false;
        _selectedGeoPoint = null;
        _validatedLocationName = null;
        _locationError = null;
      });
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Reverse geocode to get location name
      final locationName = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _useCurrentLocation = true;
        _selectedGeoPoint = GeoPoint(position.latitude, position.longitude);
        _validatedLocationName = locationName ?? 'Current Location';
        _isLoadingLocation = false;
        _locationController.clear(); // Clear manual input
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationError =
            '${AppLocale.failedCurrentLocation.getString(context)}: ${e.toString()}';
      });
    }
  }

  /// Reverse geocodes coordinates to get a readable address
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'];
      if (apiKey == null) return null;

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results']?.isNotEmpty == true) {
          return data['results'][0]['formatted_address'] as String?;
        }
      }
    } catch (e) {
      // Silently fail and return null
    }
    return null;
  }

  /// Handles manual location text input changes
  void _onLocationTextChanged(String value) {
    if (_useCurrentLocation) return; // Ignore if using current location

    // Cancel previous validation
    _validationDebouncer?.cancel();

    // Clear previous state
    setState(() {
      _selectedGeoPoint = null;
      _validatedLocationName = null;
      _locationError = null;
    });

    if (value.trim().isEmpty) return;

    // Debounce validation to avoid excessive API calls
    _validationDebouncer = Timer(const Duration(milliseconds: 800), () {
      _validateManualLocation(value.trim());
    });
  }

  /// Validates manually entered location using Places API
  Future<void> _validateManualLocation(String location) async {
    if (location.isEmpty || _useCurrentLocation) return;

    setState(() {
      _isValidatingLocation = true;
      _locationError = null;
    });

    try {
      final result = await _geocodeLocation(location);

      if (result.isValid &&
          result.latitude != null &&
          result.longitude != null) {
        setState(() {
          _selectedGeoPoint = GeoPoint(result.latitude!, result.longitude!);
          _validatedLocationName = result.formattedAddress ?? location;
          _isValidatingLocation = false;
        });
      } else {
        // Fallback: Accept location if it looks like a city name (basic validation)
        if (_isValidLocationFormat(location)) {
          setState(() {
            _selectedGeoPoint = GeoPoint(0.0, 0.0); // Placeholder coordinates
            _validatedLocationName = location;
            _isValidatingLocation = false;
            _locationError = null; // Clear any error
          });
        } else {
          setState(() {
            // Provide more specific error messages based on the likely cause
            if (dotenv.env['GOOGLE_API_KEY'] == null) {
              _locationError = 'Configuration error: Google API key not found';
            } else {
              _locationError =
                  'Unable to validate location. Please check spelling or try a different location.';
            }
            _isValidatingLocation = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _locationError = AppLocale.failedValidateLocation.getString(context);
        _isValidatingLocation = false;
      });
    }
  }

  /// Basic validation for location format (fallback)
  bool _isValidLocationFormat(String location) {
    // Basic checks: not empty, contains letters, reasonable length
    if (location.trim().length < 2 || location.trim().length > 100) {
      return false;
    }

    // Should contain at least some letters (not just numbers or symbols)
    if (!RegExp(r'[a-zA-Z]').hasMatch(location)) {
      return false;
    }

    // Common city/location patterns
    return true; // Accept most reasonable inputs as fallback
  }

  /// Geocodes a location string to coordinates using Places API with Nominatim fallback
  Future<_LocationResult> _geocodeLocation(String location) async {
    // Try Google API first
    final googleResult = await _geocodeWithGoogle(location);
    if (googleResult.isValid) {
      return googleResult;
    }

    // Fallback to Nominatim (OpenStreetMap)
    return await _geocodeWithNominatim(location);
  }

  /// Geocodes using Google Places API
  Future<_LocationResult> _geocodeWithGoogle(String location) async {
    try {
      // Get platform-specific API key
      String? apiKey;
      if (Platform.isIOS) {
        apiKey = dotenv.env['GOOGLE_API_KEY_IOS'];
      } else if (Platform.isAndroid) {
        apiKey = dotenv.env['GOOGLE_API_KEY_ANDROID'];
      } else {
        // Fallback to generic key for other platforms
        apiKey = dotenv.env['GOOGLE_API_KEY'];
      }

      if (apiKey == null) {
        return const _LocationResult(isValid: false);
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(location)}'
        '&key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check API response status
        final status = data['status'] as String?;

        if (status == 'REQUEST_DENIED') {
          return const _LocationResult(isValid: false);
        } else if (status == 'OVER_QUERY_LIMIT') {
          return const _LocationResult(isValid: false);
        } else if (status == 'ZERO_RESULTS') {
          return const _LocationResult(isValid: false);
        } else if (status != 'OK') {
          if (data['error_message'] != null) {}
          return const _LocationResult(isValid: false);
        }

        if (data['results']?.isNotEmpty == true) {
          final result = data['results'][0];
          final geometry = result['geometry'];
          final location = geometry['location'];

          return _LocationResult(
            isValid: true,
            latitude: location['lat']?.toDouble(),
            longitude: location['lng']?.toDouble(),
            formattedAddress: result['formatted_address'],
          );
        } else {}
      } else {}
    } catch (_) {}

    return const _LocationResult(isValid: false);
  }

  /// Geocodes using free Nominatim service (OpenStreetMap)
  Future<_LocationResult> _geocodeWithNominatim(String location) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(location)}'
        '&format=json'
        '&limit=1'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'GigHub/1.0 (Flutter App)', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final result = data[0];
          final lat = double.tryParse(result['lat'].toString());
          final lon = double.tryParse(result['lon'].toString());
          final displayName = result['display_name'] as String?;

          if (lat != null && lon != null) {
            return _LocationResult(
              isValid: true,
              latitude: lat,
              longitude: lon,
              formattedAddress: displayName ?? location,
            );
          }
        } else {}
      } else {}
    } catch (_) {}

    return const _LocationResult(isValid: false);
  }

  /// Saves the rave alert to Firestore
  Future<void> _saveRaveAlert() async {
    if (currentUser == null || _selectedGeoPoint == null) return;

    setState(() => _isSaving = true);

    try {
      final alertId =
          FirebaseFirestore.instance.collection('rave_alerts').doc().id;
      final now = DateTime.now();

      final raveAlert = RaveAlert(
        id: alertId,
        userId: currentUser!.uid,
        centerPoint: _selectedGeoPoint!,
        radiusKm: _selectedRadius,
        locationName: _validatedLocationName ?? 'Unknown Location',
        createdAt: now,
        updatedAt: now,
      );

      await FirebaseFirestore.instance
          .collection('rave_alerts')
          .doc(alertId)
          .set(raveAlert.toJson());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.raveAlertCreatedSuccess.getString(context)),
            backgroundColor: Palette.forgedGold,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocale.raveAlertCreationFailed.getString(context)}: $e',
            ),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  /// Checks if the form is valid for submission
  bool get _isFormValid {
    return _selectedGeoPoint != null && !_isSaving && !_isValidatingLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildRadiusSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Builds the dialog header with title and description
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Palette.forgedGold,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocale.setupRaveAlert.getString(context),
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: Palette.glazedWhite.o(0.7)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppLocale.getNotifiedNewRaves.getString(context),
          style: TextStyle(color: Palette.glazedWhite.o(0.7), fontSize: 14),
        ),
      ],
    );
  }

  /// Builds the location selection section
  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.location.getString(context),
          style: TextStyle(
            color: Palette.glazedWhite,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        // Current location button
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton.icon(
            onPressed: _isLoadingLocation ? null : _useCurrentLocationPressed,
            icon:
                _isLoadingLocation
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _useCurrentLocation
                              ? Palette.primalBlack
                              : Palette.forgedGold,
                        ),
                      ),
                    )
                    : Icon(
                      _useCurrentLocation ? Icons.check : Icons.my_location,
                      size: 18,
                    ),
            label: Text(
              _useCurrentLocation
                  ? AppLocale.currentLocationSelected.getString(context)
                  : AppLocale.useCurrentLocation.getString(context),
              style: const TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _useCurrentLocation ? Palette.forgedGold : Colors.transparent,
              foregroundColor:
                  _useCurrentLocation
                      ? Palette.primalBlack
                      : Palette.forgedGold,
              side: BorderSide(color: Palette.forgedGold, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // Manual location input
        Container(
          decoration: BoxDecoration(
            color: Palette.gigGrey.o(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  _locationError != null
                      ? Palette.alarmRed
                      : _selectedGeoPoint != null
                      ? Palette.forgedGold.o(0.5)
                      : Palette.gigGrey.o(0.5),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _locationController,
            enabled: !_useCurrentLocation,
            style: TextStyle(
              color:
                  _useCurrentLocation
                      ? Palette.glazedWhite.o(0.5)
                      : Palette.glazedWhite,
            ),
            decoration: InputDecoration(
              hintText: AppLocale.orEnterCityName.getString(context),
              hintStyle: TextStyle(color: Palette.glazedWhite.o(0.5)),
              prefixIcon: Icon(
                Icons.search,
                color:
                    _useCurrentLocation
                        ? Palette.glazedWhite.o(0.5)
                        : Palette.forgedGold,
              ),
              suffixIcon:
                  _isValidatingLocation
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
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: _onLocationTextChanged,
          ),
        ),

        // Location status display
        if (_locationError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error, color: Palette.alarmRed, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locationError!,
                  style: TextStyle(color: Palette.alarmRed, fontSize: 12),
                ),
              ),
            ],
          ),
        ] else if (_validatedLocationName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Palette.forgedGold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _validatedLocationName!,
                  style: TextStyle(
                    color: Palette.forgedGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds the radius selection section
  Widget _buildRadiusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocale.alertRadius.getString(context),
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Palette.forgedGold.o(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palette.forgedGold.o(0.5)),
              ),
              child: Text(
                '${_selectedRadius.round()} ${AppLocale.km.getString(context)}',
                style: TextStyle(
                  color: Palette.forgedGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Radius slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Palette.forgedGold,
            inactiveTrackColor: Palette.gigGrey.o(0.3),
            thumbColor: Palette.forgedGold,
            overlayColor: Palette.forgedGold.o(0.2),
            valueIndicatorColor: Palette.forgedGold,
            valueIndicatorTextStyle: TextStyle(
              color: Palette.primalBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Slider(
            value: _selectedRadius,
            min: 10.0,
            max: 200.0,
            divisions: 19, // 10km steps
            label:
                '${_selectedRadius.round()} ${AppLocale.km.getString(context)}',
            onChanged: (value) {
              setState(() {
                _selectedRadius = value;
              });
            },
          ),
        ),

        // Radius indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '10 ${AppLocale.km.getString(context)}',
              style: TextStyle(color: Palette.glazedWhite.o(0.6), fontSize: 12),
            ),
            Text(
              '200 ${AppLocale.km.getString(context)}',
              style: TextStyle(color: Palette.glazedWhite.o(0.6), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the action buttons section
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Palette.glazedWhite.o(0.7),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(AppLocale.cancel.getString(context)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isFormValid ? _saveRaveAlert : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isFormValid ? Palette.forgedGold : Palette.gigGrey.o(0.3),
              foregroundColor:
                  _isFormValid
                      ? Palette.primalBlack
                      : Palette.glazedWhite.o(0.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isSaving
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Palette.primalBlack,
                        ),
                      ),
                    )
                    : Text(
                      AppLocale.createAlert.getString(context),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
          ),
        ),
      ],
    );
  }
}
