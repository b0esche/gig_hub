import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../domain/rave.dart';
import '../../../../Data/models/users.dart';
import '../../../../Data/interfaces/database_repository.dart';
import '../../../../Data/services/localization_service.dart';
import '../../../../Data/services/places_validation_service.dart';
import 'user_search_dialog.dart';

class EditRaveDialog extends StatefulWidget {
  final Rave rave;

  const EditRaveDialog({super.key, required this.rave});

  @override
  State<EditRaveDialog> createState() => _EditRaveDialogState();
}

class _EditRaveDialogState extends State<EditRaveDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ticketShopController;
  late final TextEditingController _additionalLinkController;

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  bool _isMultiDay = false;
  List<AppUser> _selectedDJs = [];
  List<AppUser> _selectedCollaborators = [];
  bool _isLoading = false;
  bool _isValidatingLocation = false;
  String? _locationError;
  Timer? _locationValidationTimer;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing rave data
    _nameController = TextEditingController(text: widget.rave.name);
    _locationController = TextEditingController(text: widget.rave.location);
    _descriptionController = TextEditingController(
      text: widget.rave.description,
    );
    _ticketShopController = TextEditingController(
      text: widget.rave.ticketShopLink ?? '',
    );
    _additionalLinkController = TextEditingController(
      text: widget.rave.additionalLink ?? '',
    );

    // Initialize date and time
    _startDate = widget.rave.startDate;
    _endDate = widget.rave.endDate;
    _isMultiDay = widget.rave.endDate != null;

    // Parse time from startTime string
    if (widget.rave.startTime.isNotEmpty && widget.rave.startTime != '00:00') {
      try {
        final timeParts = widget.rave.startTime.split(':');
        if (timeParts.length >= 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          _startTime = TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        // If parsing fails, leave _startTime as null
      }
    }

    // Load existing DJs and collaborators
    _loadExistingUsers();
  }

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

  Future<void> _loadExistingUsers() async {
    try {
      // Load existing DJs
      for (String djId in widget.rave.djIds) {
        try {
          final dj = await context.read<DatabaseRepository>().getUserById(djId);
          if (dj is DJ) {
            _selectedDJs.add(dj);
          }
        } catch (e) {
          // Skip if user not found
        }
      }

      // Load existing collaborators
      for (String collabId in widget.rave.collaboratorIds) {
        try {
          final collaborator = await context
              .read<DatabaseRepository>()
              .getUserById(collabId);
          if (collaborator is Booker) {
            _selectedCollaborators.add(collaborator);
          }
        } catch (e) {
          // Skip if user not found
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error gracefully
    }
  }

  /// Validates location using Google Places API with debouncing
  Future<void> _validateLocation(String value) async {
    final trimmedValue = value.trim();

    // Cancel any pending validation
    _locationValidationTimer?.cancel();

    // Clear previous error if field is empty
    if (trimmedValue.isEmpty) {
      setState(() {
        _locationError = null;
        _isValidatingLocation = false;
      });
      return;
    }

    // Set validation state immediately
    setState(() {
      _isValidatingLocation = true;
      _locationError = null;
    });

    // Debounce the validation to avoid excessive API calls
    _locationValidationTimer = Timer(
      const Duration(milliseconds: 800),
      () async {
        try {
          // Validate the location using Google Places API
          final isValid = await PlacesValidationService.validateCity(
            trimmedValue,
          );

          if (mounted) {
            setState(() {
              _isValidatingLocation = false;
              if (!isValid) {
                _locationError = 'Please enter a valid city name';
              } else {
                _locationError = null;
              }
            });

            // Trigger form validation to show/hide error
            _formKey.currentState?.validate();
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isValidatingLocation = false;
              _locationError =
                  'Unable to validate location. Please check your connection.';
            });
            _formKey.currentState?.validate();
          }
        }
      },
    );
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
        AppLocale.editRave.getString(context),
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
          onPressed: _isLoading ? null : _updateRave,
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
                    AppLocale.editRave.getString(context),
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

  Future<void> _updateRave() async {
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

    // Ensure location is valid before proceeding
    if (_locationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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

      // Create update map with only the fields that can be updated
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'startDate': startDateTime.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'startTime': _startTime?.format(context) ?? '00:00',
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ticketShopLink':
            _ticketShopController.text.trim().isNotEmpty
                ? _ticketShopController.text.trim()
                : null,
        'additionalLink':
            _additionalLinkController.text.trim().isNotEmpty
                ? _additionalLinkController.text.trim()
                : null,
        'djIds': _selectedDJs.map((dj) => dj.id).toList(),
        'collaboratorIds':
            _selectedCollaborators.map((collab) => collab.id).toList(),
      };

      // Update the rave in Firestore
      await context.read<DatabaseRepository>().updateRave(
        widget.rave.id,
        updates,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.raveUpdated.getString(context)),
            backgroundColor: const Color(0xFFD4AF37),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocale.raveUpdateFailed.getString(context)}: $e',
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
}
