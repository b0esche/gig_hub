import 'package:gig_hub/src/Data/app_imports.dart';

class StatusMessageDialog extends StatefulWidget {
  const StatusMessageDialog({super.key});

  @override
  State<StatusMessageDialog> createState() => _StatusMessageDialogState();
}

class _StatusMessageDialogState extends State<StatusMessageDialog> {
  final TextEditingController _messageController = TextEditingController();
  int _selectedDays = 1;

  final List<int> _dayOptions = [1, 7, 30];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Palette.forgedGold, width: 2),
      ),
      title: Text(
        AppLocale.enterStatusMsg.getString(context),
        style: GoogleFonts.sometypeMono(
          textStyle: TextStyle(
            color: Palette.glazedWhite,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Palette.glazedWhite, width: 1),
              borderRadius: BorderRadius.circular(8),
              color: Palette.glazedWhite.o(0.1),
            ),
            child: TextFormField(
              controller: _messageController,
              maxLength: 70,
              maxLines: 3,
              style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
              decoration: InputDecoration(
                counterStyle: TextStyle(color: Palette.shadowGrey.o(0.85)),
                hintText: AppLocale.enterStatusMsg.getString(context),
                hintStyle: TextStyle(color: Palette.glazedWhite.o(0.6)),
                contentPadding: EdgeInsets.all(12),
                border: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Palette.forgedGold, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            AppLocale.displayFor.getString(context),
            style: TextStyle(
              color: Palette.glazedWhite,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                _dayOptions.map((days) {
                  final isSelected = _selectedDays == days;
                  return ChoiceChip(
                    checkmarkColor: Palette.glazedWhite,
                    label: Text(_getDayLabel(days, context)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedDays = days);
                      }
                    },
                    selectedColor: Palette.forgedGold.o(0.8),
                    backgroundColor: Palette.gigGrey.o(0.25),
                    labelStyle: TextStyle(
                      color: Palette.primalBlack,

                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color:
                          isSelected
                              ? Palette.forgedGold
                              : Palette.concreteGrey,
                      width: isSelected ? 2 : 1,
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocale.cancel.getString(context),
            style: TextStyle(color: Palette.glazedWhite),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final message = _messageController.text.trim();
            if (message.isNotEmpty) {
              Navigator.of(
                context,
              ).pop({'message': message, 'days': _selectedDays});
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.forgedGold,
            foregroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            AppLocale.postStatus.getString(context),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Palette.glazedWhite,
            ),
          ),
        ),
      ],
    );
  }

  String _getDayLabel(int days, BuildContext context) {
    switch (days) {
      case 1:
        return AppLocale.day1.getString(context);

      case 7:
        return AppLocale.days7.getString(context);
      case 30:
        return AppLocale.days30.getString(context);
      default:
        return '$days days';
    }
  }
}
