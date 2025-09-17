import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:intl/intl.dart';
import '../../domain/rave.dart';
import '../../../../Data/services/localization_service.dart';
import '../../../../Theme/palette.dart';

class RaveTile extends StatelessWidget {
  final Rave rave;
  final VoidCallback? onTap;
  final VoidCallback? onAttendToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isAttending;
  final bool showAttendButton;
  final bool showOrganizerOptions;

  const RaveTile({
    super.key,
    required this.rave,
    this.onTap,
    this.onAttendToggle,
    this.onEdit,
    this.onDelete,
    this.isAttending = false,
    this.showAttendButton = true,
    this.showOrganizerOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              rave.startDate.isAfter(DateTime.now())
                  ? const Color(0xFFD4AF37).o(0.3)
                  : const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rave.name,
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  rave.location,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (showOrganizerOptions) _buildOrganizerActions(),
                    if (showAttendButton && !showOrganizerOptions)
                      _buildAttendButton(),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (rave.startTime.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rave.startTime,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),

                if (rave.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    rave.description,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (rave.djIds.isNotEmpty ||
                    rave.attendingUserIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (rave.djIds.isNotEmpty) ...[
                        const Icon(
                          Icons.headset,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rave.djIds.length} DJs',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (rave.attendingUserIds.isNotEmpty) ...[
                        const Icon(
                          Icons.people,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rave.attendingUserIds.length} attending',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                if (rave.endDate != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).o(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).o(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      AppLocale.multiDay.getString(context),
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizerActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit button
        SizedBox(
          height: 32,
          width: 32,
          child: IconButton(
            onPressed: onEdit,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37).o(0.1),
              side: BorderSide(color: const Color(0xFFD4AF37), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.edit, color: Color(0xFFD4AF37), size: 16),
          ),
        ),
        const SizedBox(width: 8),
        // Delete button
        SizedBox(
          height: 32,
          width: 32,
          child: IconButton(
            onPressed: onDelete,
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.o(0.1),
              side: BorderSide(color: Colors.red, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendButton() {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onAttendToggle,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isAttending ? const Color(0xFFD4AF37) : Colors.transparent,
          foregroundColor: isAttending ? Colors.black : const Color(0xFFD4AF37),
          side: BorderSide(color: const Color(0xFFD4AF37), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
        ),
        child: Text(
          isAttending ? '✓' : '+',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatDate() {
    if (rave.endDate != null) {
      final startFormat = DateFormat('MMM dd');
      final endFormat =
          rave.startDate.year == rave.endDate!.year
              ? DateFormat('MMM dd, yyyy')
              : DateFormat('MMM dd, yyyy');

      return '${startFormat.format(rave.startDate)} - ${endFormat.format(rave.endDate!)}';
    } else {
      return DateFormat('MMM dd, yyyy').format(rave.startDate);
    }
  }
}
