import 'package:gig_hub/src/Data/app_imports.dart';

class LocationInputField extends StatelessWidget {
  const LocationInputField({
    super.key,
    required TextEditingController locationController,
    required FocusNode locationFocusNode,
    required String? locationError,
  }) : _locationController = locationController,
       _locationFocusNode = locationFocusNode,
       _locationError = locationError;

  final TextEditingController _locationController;
  final FocusNode _locationFocusNode;
  final String? _locationError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Palette.glazedWhite, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Palette.glazedWhite.o(0.2),
      ),
      child: TextFormField(
        style: TextStyle(fontSize: 14, color: Palette.glazedWhite),
        controller: _locationController,
        focusNode: _locationFocusNode,
        validator: (value) {
          return _locationError;
        },
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Palette.forgedGold, width: 3),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Palette.forgedGold),
          ),
          errorStyle: TextStyle(fontSize: 0, height: 0),
        ),
      ),
    );
  }
}
