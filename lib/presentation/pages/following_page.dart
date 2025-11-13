// lib/presentation/pages/following_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';

// 1. Convert to ConsumerWidget
class FollowingPage extends ConsumerWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. Watch the 'followingVideosProvider'
    final videoListAsync = ref.watch(followingVideosProvider);

    // 3. Build the UI, handling loading, error, and data states
    return videoListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'You are not following anyone, or the users you follow haven\'t posted videos yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // 4. Display the list of videos using VideoCard
        return ListView.builder(
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return VideoCard(video: video);
          },
        );
      },
    );
  }
}