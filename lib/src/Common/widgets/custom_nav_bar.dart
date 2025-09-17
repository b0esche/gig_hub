import 'package:gig_hub/src/Data/app_imports.dart';
import '../../Features/raves/presentation/widgets/radar/presentation/rave_radar_screen.dart';

class CustomNavBar extends StatefulWidget {
  final AppUser currentUser;
  const CustomNavBar({super.key, required this.currentUser});

  @override
  State<CustomNavBar> createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar> with RouteAware {
  RouteObserver<PageRoute>? _routeObserver;
  PageRoute? _myRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver =
        ModalRoute.of(context)?.navigator?.widget.observers
            .whereType<RouteObserver<PageRoute>>()
            .firstOrNull;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _myRoute = route;
      _routeObserver?.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_routeObserver != null && _myRoute != null) {
      _routeObserver!.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseRepository>();
    return StreamBuilder<List<ChatMessage>>(
      stream: db.getChatsStream(widget.currentUser.id),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        final hasUnreadMessages = messages.any(
          (msg) => msg.read == false && msg.senderId != widget.currentUser.id,
        );
        return Stack(
          children: [
            Padding(
              padding: EdgeInsetsGeometry.only(
                bottom: 36,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: LiquidGlass(
                shape: LiquidRoundedRectangle(borderRadius: Radius.circular(8)),
                settings: LiquidGlassSettings(
                  thickness: 20,
                  refractiveIndex: 1.1,
                  glassColor: Palette.forgedGold.o(0.025),
                ),
                child: Container(
                  color: Palette.glazedWhite.o(0.075),
                  height: 48,
                  width: 420,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.home_filled,
                            color: Palette.forgedGold,
                          ),
                        ),
                      ),
                      if (widget.currentUser is! Guest)
                        VerticalDivider(color: Palette.primalBlack),
                      if (widget.currentUser is! Guest)
                        IconButton(
                          onPressed: () async {
                            if (widget.currentUser is DJ) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProfileScreenDJ(
                                        currentUser: widget.currentUser,
                                        dj: widget.currentUser as DJ,

                                        showChatButton: false,
                                        showEditButton: false,
                                        showFavoriteIcon: false,
                                      ),
                                ),
                              );
                            } else if (widget.currentUser is Booker) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProfileScreenBooker(
                                        booker: widget.currentUser as Booker,
                                        db: db,

                                        showEditButton: false,
                                      ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: Duration(milliseconds: 950),
                                  backgroundColor: Palette.forgedGold,
                                  content: Center(
                                    child: Text(
                                      'sign up as DJ or booker to create a profile!',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            Icons.account_box_rounded,
                            color: Palette.glazedWhite,
                          ),
                        ),
                      VerticalDivider(color: Palette.primalBlack),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              // Allow all users (including guests) to access chat
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ChatListScreen(
                                        currentUser: widget.currentUser,
                                      ),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.question_answer_outlined,
                              color: Palette.glazedWhite,
                            ),
                          ),
                          if (hasUnreadMessages)
                            Positioned(
                              right: 2,
                              bottom: 12,
                              child: Container(
                                height: 8,
                                width: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Palette.forgedGold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      VerticalDivider(color: Palette.primalBlack),

                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RaveRadarScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.radar_rounded,
                            color: Palette.glazedWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
