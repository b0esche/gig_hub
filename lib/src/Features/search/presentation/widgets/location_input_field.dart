import 'package:gig_hub/src/Data/app_imports.dart';

class LocationAutocompleteField extends StatefulWidget {
  final void Function(String) onCitySelected;
  final TextEditingController? controller;

  const LocationAutocompleteField({
    super.key,
    required this.onCitySelected,
    this.controller,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  late TextEditingController _internalController;
  // ignore: unused_field
  String? _validationMessage;
  String? _suggestedCity;
  Timer? _debounceTimer;
  // ignore: unused_field
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _internalController = widget.controller ?? TextEditingController();
    _internalController.addListener(_onControllerTextChanged);
  }

  @override
  void dispose() {
    _internalController.removeListener(_onControllerTextChanged);
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  void _onControllerTextChanged() {
    final input = _internalController.text.trim();

    if (input.isEmpty) {
      setState(() {
        _validationMessage = null;
        _isValidating = false;
      });
      widget.onCitySelected('');
      return;
    }

    // Call the callback immediately with the input
    widget.onCitySelected(input);

    // Cancel previous validation timer
    _debounceTimer?.cancel();

    // Set validating state
    setState(() {
      _isValidating = true;
      _validationMessage = null;
    });

    // Start new validation timer
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _validateCity(input);
    });
  }

  Future<void> _validateCity(String input) async {
    if (input.isEmpty) {
      setState(() {
        _validationMessage = null;
        _suggestedCity = null;
        _isValidating = false;
      });
      return;
    }

    try {
      final result = await PlacesValidationService.validateCityWithSuggestion(
        input,
      );

      if (mounted) {
        setState(() {
          _isValidating = false;
          if (result.isValid) {
            _validationMessage = "✓ City found";
            _suggestedCity = result.suggestedName;
          } else {
            _validationMessage = "City not found";
            _suggestedCity = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _validationMessage = "Unable to validate city";
          _suggestedCity = null;
        });
      }
    }
  }

  void _applySuggestion() {
    if (_suggestedCity != null) {
      _internalController.text = _suggestedCity!;
      widget.onCitySelected(_suggestedCity!);
      setState(() {
        _suggestedCity = null;
        _validationMessage = "✓ City selected";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CustomFormField(
          controller: _internalController,
          readOnly: false,
          label: "city...",
          onPressed: null,
          onChanged: (value) {},
          suffixIcon:
              _suggestedCity != null &&
                      _suggestedCity != _internalController.text
                  ? GestureDetector(
                    onTap: _applySuggestion,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        _suggestedCity!,
                        style: TextStyle(
                          color: Palette.forgedGold,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  : null,
        ),
      ],
    );
  }
}
