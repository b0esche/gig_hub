import '../../../Data/app_imports.dart';

class SortButtonsWidget extends StatelessWidget {
  const SortButtonsWidget({
    super.key,
    required this.selectedSortOption,
    required this.onSortOptionChanged,
    this.onExpandedChanged,
  });

  final String selectedSortOption;
  final void Function(String) onSortOptionChanged;
  final void Function()? onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = Palette.forgedGold;
    final Color defaultColor = Palette.glazedWhite;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSortButton('genre', selectedColor, defaultColor, context),
        _buildSortButton('bpm', selectedColor, defaultColor, context),
        //  _buildSortButton('location', selectedColor, defaultColor, context),
      ],
    );
  }

  Widget _buildSortButton(
    String option,
    Color selectedColor,
    Color defaultColor,
    BuildContext context,
  ) {
    final isSelected = selectedSortOption == option;
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        foregroundColor: isSelected ? selectedColor : defaultColor,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
      onPressed: () {
        onSortOptionChanged(option);
        onExpandedChanged?.call();
      },
      child: Text(option),
    );
  }
}
