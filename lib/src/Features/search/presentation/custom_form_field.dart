import 'package:gig_hub/src/Data/app_imports.dart';

class CustomFormField extends StatelessWidget {
  final String label;
  final void Function()? onPressed;
  final bool readOnly;
  final TextEditingController? controller;
  final void Function(String)? onChanged;
  final Widget? suffixIcon;

  const CustomFormField({
    required this.label,
    required this.onPressed,
    required this.readOnly,
    this.controller,
    this.onChanged,
    this.suffixIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 32,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        onTap: onPressed,
        readOnly: readOnly,
        style: GoogleFonts.sometypeMono(
          textStyle: TextStyle(
            color: Palette.glazedWhite,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            overflow: TextOverflow.ellipsis,
            wordSpacing: -4,
          ),
        ),
        decoration: InputDecoration(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Palette.forgedGold, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Palette.gigGrey, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon:
              suffixIcon ??
              Icon(Icons.chevron_right, color: Palette.glazedWhite),
          labelText: label,
          labelStyle: GoogleFonts.sometypeMono(
            textStyle: TextStyle(
              color: Palette.glazedWhite,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 10,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Palette.primalBlack,
        ),
      ),
    );
  }
}
