// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:media_kit/media_kit.dart'; 
import 'package:ofgconnects/presentation/navigation/app_router.dart'; 
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize AdMob (Safe unawaited call)
  MobileAds.instance.initialize();

  // 2. Initialize MediaKit (REQUIRED for video)
  MediaKit.ensureInitialized(); 

  // 3. Load Env (Safe Mode)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found. Ensure it exists in assets.");
  }
  
  // 4. Lock Orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 5. Immersive UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) ref.read(authProvider.notifier).checkUserStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'OFG Connects',
      debugShowCheckedModeBanner: false,
      
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: OfgUi.bg,
        primaryColor: OfgUi.accent,
        dividerColor: OfgUi.border,
        colorScheme: const ColorScheme.dark(
          primary: OfgUi.accent,
          secondary: OfgUi.accentWarm,
          surface: OfgUi.surface,
          outline: OfgUi.border,
        ),
        
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(), 
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            letterSpacing: -0.5,
            color: Colors.white
          ),
        ),
        
        cardTheme: CardThemeData( 
          color: const Color(0xFF1E1E1E),
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF262626),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: OfgUi.accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: OfgUi.accent,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: OfgUi.accent.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: OfgUi.text,
            letterSpacing: 0.2,
          ),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
          bodyMedium: TextStyle(fontSize: 14, color: OfgUi.muted2),
        ),
      ),
    );
  }
}
