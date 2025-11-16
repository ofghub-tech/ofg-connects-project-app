import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
// --- THIS IS THE FIX ---
// We import the file containing the `historyProvider`
import 'package:ofgconnects_mobile/logic/video_provider.dart';
// --- END FIX ---

class HistoryPage extends ConsumerWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This line will now work correctly
    final videosAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return const Center(child: Text('No videos in your history.'));
          }
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return VideoCard(video: videos[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}