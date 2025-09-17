import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../domain/rave.dart';
import '../../../../Data/models/users.dart';
import '../../../../Data/models/group_chat.dart';
import '../../../../Data/interfaces/database_repository.dart';
import '../../../../Data/services/localization_service.dart';
import '../../../../Data/services/places_validation_service.dart';
import 'user_search_dialog.dart';

/// Simple location result class for geocoding responses
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

class CreateRaveDialog extends StatefulWidget {
  const CreateRaveDialog({super.key});

  @override
  State<CreateRaveDialog> createState() => _CreateRaveDialogState();
}

class _CreateRaveDialogState extends State<CreateRaveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketShopController = TextEditingController();
  final _additionalLinkController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  bool _isMultiDay = false;
  bool _createGroupChat = true;
  List<AppUser> _selectedDJs = [];
  List<AppUser> _selectedCollaborators = [];
  bool _isLoading = false;
  bool _isValidatingLocation = false;
  String? _locationError;
  Timer? _locationValidationTimer;
  GeoPoint? _validatedGeoPoint; // Store geocoded coordinates

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _ticketShopController.dispose();
    _additionalLinkController.dispose();
    _locationValidationTimer?.cancel();
    super.dispose();
  }

  /// Validates location using Google Places API with debouncing
  /// Ensures only real, existing locations are accepted
  /// Uses a 800ms delay to prevent excessive API calls while typing
  /// Also geocodes the location to get coordinates for rave alerts
  Future<void> _validateLocation(String value) async {
    final trimmedValue = value.trim();

    // Cancel any pending validation
    _locationValidationTimer?.cancel();

    // Clear previous error if field is empty
    if (trimmedValue.isEmpty) {
      setState(() {
        _locationError = null;
        _isValidatingLocation = false;
        _validatedGeoPoint = null;
      });
      return;
    }

    // Set validation state immediately
    setState(() {
      _isValidatingLocation = true;
      _locationError = null;
      _validatedGeoPoint = null;
    });

    // Debounce the validation to avoid excessive API calls
    _locationValidationTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        // First validate the location using the existing service
        final isValid = await PlacesValidationService.validateCity(
          trimmedValue,
        );

        if (mounted) {
          setState(() {
            _isValidatingLocation = false;
            _locationError = isValid ? null : 'Please enter a valid city name';
          });
        }

        // If validation passed, try to geocode (but don't fail if geocoding fails)
        if (isValid) {
          try {
            final geocodeResult = await _geocodeLocation(trimmedValue);
            if (mounted) {
              setState(() {
                _validatedGeoPoint =
                    geocodeResult.isValid &&
                            geocodeResult.latitude != null &&
                            geocodeResult.longitude != null
                        ? GeoPoint(
                          geocodeResult.latitude!,
                          geocodeResult.longitude!,
                        )
                        : null;
              });
            }
          } catch (e) {
            // Geocoding failed, but that's okay - we'll just create rave without geoPoint
            if (mounted) {
              setState(() {
                _validatedGeoPoint = null;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _validatedGeoPoint = null;
            });
          }
        }

        if (mounted) {
          // Trigger form validation to show/hide error
          _formKey.currentState?.validate();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isValidatingLocation = false;
            _locationError = 'Network error. Please try again.';
            _validatedGeoPoint = null;
          });
          _formKey.currentState?.validate();
        }
      }
    });
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
        final status = data['status'] as String?;

        if (status == 'OK' && data['results']?.isNotEmpty == true) {
          final result = data['results'][0];
          final geometry = result['geometry'];
          final location = geometry['location'];

          return _LocationResult(
            isValid: true,
            latitude: location['lat']?.toDouble(),
            longitude: location['lng']?.toDouble(),
            formattedAddress: result['formatted_address'],
          );
        }
      }
    } catch (e) {
      // Google API failed, will try fallback
    }

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
        }
      }
    } catch (e) {
      // Fallback failed
    }

    return const _LocationResult(isValid: false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF333333), width: 1),
      ),
      title: Text(
        AppLocale.createRave.getString(context),
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: AppLocale.raveName.getString(context),
                  validator:
                      (value) =>
                          value?.trim().isEmpty == true
                              ? 'Name is required'
                              : null,
                ),
                const SizedBox(height: 16),

                _buildDateTimeSection(),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _locationController,
                  label: AppLocale.raveLocation.getString(context),
                  validator: (value) {
                    if (value?.trim().isEmpty == true) {
                      return 'Location is required';
                    }
                    if (_locationError != null) {
                      return _locationError;
                    }
                    return null;
                  },
                  onChanged: _validateLocation,
                  isValidating: _isValidatingLocation,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _descriptionController,
                  label: AppLocale.raveDescription.getString(context),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _ticketShopController,
                  label: AppLocale.ticketShop.getString(context),
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _additionalLinkController,
                  label: AppLocale.additionalLink.getString(context),
                ),
                const SizedBox(height: 16),

                _buildUserSelection(),
                const SizedBox(height: 16),

                _buildGroupChatOption(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            AppLocale.cancel.getString(context),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createRave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                  : Text(
                    AppLocale.createRave.getString(context),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 1,
    bool isValidating = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        // Add validation indicator
        suffixIcon:
            isValidating
                ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                )
                : null,
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isMultiDay,
              onChanged: (value) {
                setState(() {
                  _isMultiDay = value ?? false;
                  if (!_isMultiDay) {
                    _endDate = null;
                  }
                });
              },
              activeColor: const Color(0xFFD4AF37),
            ),
            Text(
              AppLocale.multiDay.getString(context),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: AppLocale.raveDate.getString(context),
                date: _startDate,
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeField()),
          ],
        ),

        if (_isMultiDay) ...[
          const SizedBox(height: 12),
          _buildDateField(
            label: AppLocale.endDate.getString(context),
            date: _endDate,
            onTap: () => _selectDate(context, false),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: Color(0xFFD4AF37),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? DateFormat('MMM dd, yyyy').format(date) : label,
                style: TextStyle(
                  color: date != null ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return GestureDetector(
      onTap: () => _selectTime(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _startTime != null
                    ? _startTime!.format(context)
                    : AppLocale.startTime.getString(context),
                style: TextStyle(
                  color: _startTime != null ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserSelectionButton(
          label: AppLocale.addDJs.getString(context),
          users: _selectedDJs,
          userType: UserType.dj,
          onChanged: (users) => setState(() => _selectedDJs = users),
        ),
        const SizedBox(height: 12),
        _buildUserSelectionButton(
          label: AppLocale.addCollaborators.getString(context),
          users: _selectedCollaborators,
          userType: UserType.booker,
          onChanged: (users) => setState(() => _selectedCollaborators = users),
        ),
      ],
    );
  }

  Widget _buildUserSelectionButton({
    required String label,
    required List<AppUser> users,
    required UserType userType,
    required Function(List<AppUser>) onChanged,
  }) {
    return GestureDetector(
      onTap: () => _showUserSearch(userType, users, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            Icon(
              userType == UserType.dj ? Icons.headset : Icons.people,
              color: const Color(0xFFD4AF37),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  users.isEmpty
                      ? Text(
                        label,
                        style: const TextStyle(color: Colors.white70),
                      )
                      : Wrap(
                        spacing: 4,
                        children:
                            users.map((user) {
                              String name = '';
                              if (user is DJ) name = user.name;
                              if (user is Booker) name = user.name;
                              return Chip(
                                label: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFD4AF37),
                                deleteIcon: const Icon(
                                  Icons.close,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                onDeleted: () {
                                  final updatedUsers = List<AppUser>.from(users)
                                    ..remove(user);
                                  onChanged(updatedUsers);
                                },
                              );
                            }).toList(),
                      ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChatOption() {
    return Row(
      children: [
        Checkbox(
          value: _createGroupChat,
          onChanged: (value) {
            setState(() {
              _createGroupChat = value ?? true;
            });
          },
          activeColor: const Color(0xFFD4AF37),
        ),
        Expanded(
          child: Text(
            AppLocale.createGroupChat.getString(context),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate
              ? (_startDate ?? DateTime.now())
              : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, reset it
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  void _showUserSearch(
    UserType userType,
    List<AppUser> currentUsers,
    Function(List<AppUser>) onChanged,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => UserSearchDialog(
            userType: userType,
            selectedUsers: currentUsers,
            onUsersSelected: onChanged,
          ),
    );
  }

  Future<void> _createRave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }

    // Check if location validation is still in progress
    if (_isValidatingLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while we validate the location'),
        ),
      );
      return;
    }

    // Ensure location is valid and geocoded before proceeding
    if (_locationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Combine date and time
      DateTime startDateTime = _startDate!;
      if (_startTime != null) {
        startDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
      }

      final rave = Rave(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        organizerId: currentUser.uid,
        startDate: startDateTime,
        endDate: _endDate,
        startTime: _startTime?.format(context) ?? '00:00',
        location: _locationController.text.trim(),
        geoPoint: _validatedGeoPoint, // Include geocoded coordinates
        description: _descriptionController.text.trim(),
        ticketShopLink:
            _ticketShopController.text.trim().isNotEmpty
                ? _ticketShopController.text.trim()
                : null,
        additionalLink:
            _additionalLinkController.text.trim().isNotEmpty
                ? _additionalLinkController.text.trim()
                : null,
        djIds: _selectedDJs.map((dj) => dj.id).toList(),
        collaboratorIds:
            _selectedCollaborators.map((collab) => collab.id).toList(),
        attendingUserIds: [],
        hasGroupChat: _createGroupChat,
        groupChatId: _createGroupChat ? null : '', // Will be created if needed
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create the rave in Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('raves')
          .add(rave.toJson());

      // Update the rave with its ID
      await docRef.update({'id': docRef.id});

      // Create group chat if requested
      if (_createGroupChat) {
        await _createGroupChatForRave(docRef.id, rave);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.raveCreated.getString(context)),
            backgroundColor: const Color(0xFFD4AF37),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocale.raveCreationFailed.getString(context)}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createGroupChatForRave(String raveId, Rave rave) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return;
      }

      // Calculate auto-delete time (48 hours after rave end)
      final raveEndTime =
          rave.endDate ??
          rave.startDate.add(
            Duration(hours: 6),
          ); // Default 6 hours if no end date
      final autoDeleteAt = raveEndTime.add(Duration(hours: 48));

      // Collect all member IDs
      final memberIds =
          <String>{
            currentUser.uid, // Organizer
            ..._selectedDJs.map((dj) => dj.id),
            ..._selectedCollaborators.map((collab) => collab.id),
          }.toList();

      final groupChat = GroupChat(
        id: '', // Will be set by repository
        raveId: raveId,
        name: rave.name,
        memberIds: memberIds,
        createdAt: DateTime.now(),
        autoDeleteAt: autoDeleteAt,
      );

      // Create the group chat using repository
      final createdGroupChat = await context
          .read<DatabaseRepository>()
          .createGroupChat(groupChat);

      // Update the rave with the group chat ID
      await FirebaseFirestore.instance.collection('raves').doc(raveId).update({
        'groupChatId': createdGroupChat.id,
      });
    } catch (_) {
      // Don't fail the rave creation if group chat fails
    }
  }
}
