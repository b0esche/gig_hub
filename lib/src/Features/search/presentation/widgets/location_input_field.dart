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
  String? _suggestedCity;
  Timer? _validationDebouncer;

  @override
  void initState() {
    super.initState();
    _internalController = widget.controller ?? TextEditingController();
    _internalController.addListener(_onControllerTextChanged);
  }

  @override
  void dispose() {
    _internalController.removeListener(_onControllerTextChanged);
    _validationDebouncer?.cancel();
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  void _onControllerTextChanged() {
    final text = _internalController.text;
    if (text.isEmpty) {
      setState(() {
        _suggestedCity = null;
      });
      return;
    }

    // Don't trigger validation if there's an exact match between input and suggestion
    if (_suggestedCity != null && text == _suggestedCity) {
      return;
    }

    if (_validationDebouncer != null) {
      _validationDebouncer?.cancel();
    }

    _validationDebouncer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() {
        _suggestedCity = null; // Clear previous suggestion while validating
      });

      try {
        final result = await PlacesValidationService.validateCityWithSuggestion(
          text,
        );
        if (!mounted) return;

        setState(() {
          // Only set suggestion if it's different from current input
          if (result.isValid && result.suggestedName != text) {
            _suggestedCity = result.suggestedName;
          }
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _suggestedCity = null;
        });
      }
    });
  }

  void _applySuggestion() {
    if (_suggestedCity != null) {
      // Prevent the onControllerTextChanged callback from triggering another validation
      _internalController.removeListener(_onControllerTextChanged);

      _internalController.text = _suggestedCity!;
      widget.onCitySelected(_suggestedCity!);

      setState(() {
        _suggestedCity = null;
      });

      // Re-add the listener after applying the suggestion
      _internalController.addListener(_onControllerTextChanged);
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
