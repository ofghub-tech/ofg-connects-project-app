// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';

// --- THIS IS THE FIX ---
// This line *must* be here for 'VideoCard' to work
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart'; 
// --- END OF FIX ---

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoListAsync = ref.watch(videoListProvider);

    return videoListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(child: Text('No videos found.'));
        }

        return ListView.builder(
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            // This will now work
            return VideoCard(video: video);
          },
        );
      },
    );
  }
}