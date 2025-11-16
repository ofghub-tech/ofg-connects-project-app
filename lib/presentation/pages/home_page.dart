// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_card.dart'; // Import the new widget

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch our two new providers
    final shortsAsync = ref.watch(shortsListProvider);
    final videosAsync = ref.watch(videosListProvider);

    return ListView(
      children: [
        // --- SHORTS SECTION ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Shorts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        shortsAsync.when(
          loading: () => const SizedBox(
            height: 250, // Fixed height for the horizontal list
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (shorts) {
            if (shorts.isEmpty) {
              return const SizedBox(height: 100, child: Center(child: Text('No shorts found.')));
            }
            return SizedBox(
              height: 250, // Constrain the height of the horizontal list
              child: ListView.builder(
                scrollDirection: Axis.horizontal, // Scroll left-to-right
                itemCount: shorts.length,
                itemBuilder: (context, index) {
                  final short = shorts[index];
                  // Use our new ShortsCard widget
                  return SizedBox(
                    width: 150, // Fixed width for the 9:16 card
                    child: ShortsCard(video: short),
                  );
                },
              ),
            );
          },
        ),

        const Divider(height: 32),

        // --- VIDEOS SECTION ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Videos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        videosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (videos) {
            if (videos.isEmpty) {
              return const Center(child: Text('No videos found.'));
            }
            // Use standard VideoCard for normal videos
            // We use shrinkWrap and physics because it's inside another ListView
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return VideoCard(video: video);
              },
            );
          },
        ),
      ],
    );
  }
}