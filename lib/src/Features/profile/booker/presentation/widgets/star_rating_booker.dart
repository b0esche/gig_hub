import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UserStarRating extends StatefulWidget {
  const UserStarRating({super.key, required this.widget});

  final ProfileScreenBooker widget;

  @override
  State<UserStarRating> createState() => _UserStarRatingState();
}

class _UserStarRatingState extends State<UserStarRating> {
  double currentRating = 0;
  int ratingCount = 0;

  Future<void> submitRating(double value) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    try {
      final functions = FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'us-central1',
      );

      final callable = functions.httpsCallable('submitRating');

      final result = await callable.call({
        'raterId': currentUser!.uid,
        'targetUserId': widget.widget.booker.id,
        'rawRating': value,
      });

      setState(() {
        currentRating = (result.data['avgRating'] as num).toDouble();
        ratingCount = result.data['ratingCount'] ?? ratingCount;
      });
      if (mounted) {
        final ratingInt = value.toInt();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.forgedGold,
            duration: Duration(milliseconds: 3150),
            content: Column(
              children: [
                Center(
                  child: Text(
                    'rating submitted! ($ratingInt stars)',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Center(
                  child: Text(
                    'overall rating: ${currentRating.toStringAsFixed(1)}  ($ratingCount ratings)',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.forgedGold,
            duration: Duration(milliseconds: 1050),
            content: Center(
              child: Text(
                'error submitting rating: $e',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    currentRating = widget.widget.booker.avgRating;
    ratingCount = widget.widget.booker.ratingCount;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            topLeft: Radius.circular(12),
          ),
          color: Palette.primalBlack.o(0.7),
          border: Border(
            left: BorderSide(width: 2, color: Palette.gigGrey.o(0.6)),
            top: BorderSide(width: 2, color: Palette.gigGrey.o(0.6)),
            bottom: BorderSide(width: 2, color: Palette.gigGrey.o(0.6)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 2.5, top: 2.5, bottom: 2.5),
          child: RatingStars(
            value: currentRating,
            starBuilder:
                (index, color) => Icon(Icons.star, color: color, size: 22.5),
            starCount: 5,
            maxValue: 5,
            axis: Axis.vertical,
            angle: 15,
            starSpacing: 0,
            starSize: 22.5,
            valueLabelVisibility: false,
            animationDuration: const Duration(milliseconds: 350),
            starOffColor: Palette.shadowGrey,
            starColor: Palette.forgedGold,
            onValueChanged: (value) async {
              await submitRating(value);
            },
          ),
        ),
      ),
    );
  }
}
