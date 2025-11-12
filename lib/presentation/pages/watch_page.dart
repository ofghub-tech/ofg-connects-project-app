// lib/presentation/pages/watch_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';

// --- THIS IS THE FIX ---
// This line *must* be here for 'SuggestedVideoCard' to work
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart'; 
// --- END OF FIX ---

class WatchPage extends ConsumerWidget {
  final String videoId;
  
  const WatchPage({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allVideosAsync = ref.watch(videoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Video $videoId'),
      ),
      body: ListView(
        children: [
          // THIS IS THE BLACK BOX (placeholder for the main video)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Center(
                child: Text(
                  'Main video player for $videoId will go here',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          
          const Divider(),

          // Suggested Videos List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Suggested Videos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          
          allVideosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => const Center(child: Text('Could not load suggestions')),
            data: (allVideos) {
              final suggestedVideos = allVideos.where((v) => v.id != videoId).toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestedVideos.length,
                itemBuilder: (context, index) {
                  final suggestedVideo = suggestedVideos[index];
                  // This will now work
                  return SuggestedVideoCard(video: suggestedVideo);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}