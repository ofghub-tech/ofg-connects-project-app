// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
// --- FIX 1: Was 'packaget:', now 'package:' ---
import 'package:ofgconnects_mobile/presentation/widgets/auth_gate.dart';

Future<void> main() async {
  // Make sure .env is loaded
  WidgetsFlutterBinding.ensureInitialized(); 
  await dotenv.load(fileName: ".env");
  
  // Wrap your app in a ProviderScope
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
    return MaterialApp(
      title: 'OFG Connects',
      theme: ThemeData.light(), 
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system, 
      debugShowCheckedModeBanner: false, 
      
      // --- FIX 2: Removed 'const' ---
      home: const AuthGate(),
    );
  }
}