// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Application imports
import 'package:ofgconnects_mobile/presentation/navigation/app_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// MyApp is a ConsumerStatefulWidget so we can access Riverpod ref in lifecycle methods.
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

  // Only re-check authentication status when the app resumes.
  // We DO NOT navigate here. Navigation is handled by AuthGate which lives
  // inside the router and therefore has a valid GoRouter context.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // small delay to allow Appwrite SDK / browser redirect to settle
      await Future.delayed(const Duration(milliseconds: 1000));

      // Use ref.read to call the notifier — this won't try to navigate.
      if (mounted) {
        ref.read(authProvider.notifier).checkUserStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT:
    // Do NOT call GoRouter.of(context) or context.go(...) from here.
    // Any provider listeners that need to navigate should be inside widgets
    // placed beneath MaterialApp.router (e.g., your AuthGate).
    return MaterialApp.router(
      routerConfig: router, // your router from app_router.dart
      title: 'OFG Connects',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}
