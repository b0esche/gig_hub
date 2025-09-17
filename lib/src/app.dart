import 'package:gig_hub/src/Data/app_imports.dart';

class RouteObserverProvider extends InheritedWidget {
  final RouteObserver<PageRoute> observer;
  const RouteObserverProvider({
    required this.observer,
    required super.child,
    super.key,
  });

  static RouteObserver<PageRoute> of(BuildContext context) {
    final RouteObserverProvider? provider =
        context.dependOnInheritedWidgetOfExactType<RouteObserverProvider>();
    assert(provider != null, 'No RouteObserverProvider found in context');
    return provider!.observer;
  }

  @override
  bool updateShouldNotify(RouteObserverProvider oldWidget) =>
      observer != oldWidget.observer;
}

class App extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const App({super.key, this.navigatorKey});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final FlutterLocalization localization = FlutterLocalization.instance;
  @override
  void initState() {
    localization.init(
      mapLocales: [
        const MapLocale('en', AppLocale.en),
        const MapLocale('de', AppLocale.de),
        const MapLocale('es', AppLocale.es),
        const MapLocale('it', AppLocale.it),
        const MapLocale('pt', AppLocale.pt),
        const MapLocale('fr', AppLocale.fr),
        const MapLocale('nl', AppLocale.nl),
        const MapLocale('pl', AppLocale.pl),
        const MapLocale('uk', AppLocale.uk),
        const MapLocale('ar', AppLocale.ar),
        const MapLocale('tr', AppLocale.tr),
        const MapLocale('ja', AppLocale.ja),
        const MapLocale('ko', AppLocale.ko),
        const MapLocale('zh', AppLocale.zh),
      ],
      initLanguageCode: 'en',
    );
    localization.onTranslatedLanguage = _onTranslatedLanguage;
    super.initState();
  }

  void _onTranslatedLanguage(Locale? locale) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final db = context.watch<DatabaseRepository>();
    final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
    return RouteObserverProvider(
      observer: routeObserver,
      child: MaterialApp(
        supportedLocales: localization.supportedLocales,
        localizationsDelegates: localization.localizationsDelegates,
        navigatorKey: widget.navigatorKey,
        navigatorObservers: [routeObserver],
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: StreamBuilder(
          stream: auth.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Palette.primalBlack,
                body: Center(
                  child: CircularProgressIndicator(
                    color: Palette.forgedGold,
                    strokeWidth: 1.65,
                  ),
                ),
              );
            }

            final fbUser = authSnap.data;
            if (fbUser == null) {
              return LoginScreen();
            }

            return FutureBuilder<AppUser>(
              future: db.getCurrentUser(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    backgroundColor: Palette.primalBlack,
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Palette.forgedGold,
                        strokeWidth: 1.65,
                      ),
                    ),
                  );
                }

                if (userSnap.hasError || userSnap.data == null) {
                  // If user is authenticated but no document exists, they might be completing social signup
                  // Show a brief loading state before returning to LoginScreen to allow social login flow to complete
                  return FutureBuilder(
                    future: Future.delayed(Duration(milliseconds: 500)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Scaffold(
                          backgroundColor: Palette.primalBlack,
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Palette.forgedGold,
                                  strokeWidth: 1.65,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Completing setup...',
                                  style: TextStyle(
                                    color: Palette.glazedWhite,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return LoginScreen();
                    },
                  );
                }
                if (authSnap.connectionState == ConnectionState.done) {
                  return MainScreen(initialUser: userSnap.data!);
                }
                return MainScreen(initialUser: userSnap.data!);
              },
            );
          },
        ),
      ),
    );
  }
}
