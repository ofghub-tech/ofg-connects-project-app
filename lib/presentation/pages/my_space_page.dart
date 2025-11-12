// lib/presentation/pages/my_space_page.dart
import 'package:flutter/material.dart';

class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Return the Center widget directly, NOT a Scaffold
    return const Center(
      child: Text('My Space Page'),
    );
  }
}