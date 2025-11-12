// lib/presentation/widgets/suggested_video_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/storage_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

class SuggestedVideoCard extends ConsumerWidget {
  final Video video;
  const SuggestedVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider to get the thumbnail bytes
    final thumbnailDataAsync = ref.watch(thumbnailProvider(video.thumbnailId));

    return InkWell(
      onTap: () {
        // Navigate to the new video
        context.go('/home/watch/${video.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Thumbnail Section (This is the fix)
            thumbnailDataAsync.when(
              loading: () => Container(
                width: 160,
                height: 90,
                color: Colors.grey[800],
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Container(
                width: 160,
                height: 90,
                color: Colors.grey[800],
                child: const Icon(Icons.error, color: Colors.red),
              ),
              data: (bytes) {
                if (bytes.isEmpty) {
                  // This is the placeholder you are seeing
                  return Container(
                    width: 160,
                    height: 90,
                    color: Colors.grey[800],
                    child: const Icon(Icons.image_not_supported, color: Colors.white54),
                  );
                }
                
                // Use Image.memory() to display the bytes
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: 160,
                  height: 90,
                );
              },
            ),

            const SizedBox(width: 12.0),

            // 2. Title and Creator Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    video.creatorName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}