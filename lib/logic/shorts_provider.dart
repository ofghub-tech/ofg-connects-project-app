// lib/logic/shorts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// We use autoDispose so the index resets to 0 when you leave the Shorts page.
// This ensures the first video plays correctly every time you enter.
final activeShortsIndexProvider = StateProvider.autoDispose<int>((ref) {
  return 0; 
});