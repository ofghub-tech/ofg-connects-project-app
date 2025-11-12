// lib/logic/shorts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This simple provider will just hold the index (0, 1, 2, etc.)
// of the short that is currently visible on the screen.
final activeShortsIndexProvider = StateProvider<int>((ref) {
  return 0; // Default to the first video
});