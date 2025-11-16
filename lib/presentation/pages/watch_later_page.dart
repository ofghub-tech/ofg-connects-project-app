import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';

class WatchLaterPage extends ConsumerWidget {
  const WatchLaterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(watchLaterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Watch Later')),
      body: videosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (videos) {
          if (videos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.watch_later_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your list is empty.'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) => VideoCard(video: videos[index]),
          );
        },
      ),
    );
  }
}