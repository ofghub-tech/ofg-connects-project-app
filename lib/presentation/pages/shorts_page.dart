// lib/presentation/pages/shorts_page.dart
import 'package:flutter/material.dart'; // <--- THIS WAS THE BROKEN LINE
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_player.dart';

class ShortsPage extends ConsumerWidget {
  const ShortsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. We'll reuse the main videoListProvider for this.
    //    Later, you could create a new 'shortsVideoProvider' that
    //    queries for videos with a 'short' category.
    final videosAsync = ref.watch(videoListProvider);

    return videosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(child: Text('No shorts found.'));
        }

        // 2. A PageView.builder is used for vertical swiping
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: videos.length,
          
          // 3. This is the key:
          //    When the page changes, we update the activeShortsIndexProvider
          onPageChanged: (index) {
            ref.read(activeShortsIndexProvider.notifier).state = index;
          },
          
          itemBuilder: (context, index) {
            final video = videos[index];
            
            // 4. Return the ShortsPlayer we created
            return ShortsPlayer(
              video: video,
              index: index,
            );
          },
        );
      },
    );
  }
}