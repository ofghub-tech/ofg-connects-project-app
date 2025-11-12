// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
// 1. Import the new router
import 'package:ofgconnects_mobile/presentation/navigation/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await dotenv.load(fileName: ".env");
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Use MaterialApp.router
    return MaterialApp.router(
      routerConfig: router, // 3. Pass the router config
      title: 'OFG Connects',
      theme: ThemeData.light(), 
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system, 
      debugShowCheckedModeBanner: false,
    );
  }
}