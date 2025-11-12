// lib/presentation/widgets/video_card.dart
import 'dart:typed_data'; // Make sure this is imported
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/storage_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

class VideoCard extends ConsumerWidget {
  final Video video;
  const VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This provider now returns AsyncValue<Uint8List>
    final thumbnailDataAsync = ref.watch(thumbnailProvider(video.thumbnailId));

    return InkWell(
      onTap: () {
        context.go('/home/watch/${video.id}');
      },
      child: Card(
        margin: const EdgeInsets.all(8.0),
        elevation: 2.0,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Thumbnail Section
            thumbnailDataAsync.when(
              loading: () => const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.error, color: Colors.red),
                ),
              ),
              // The data is now a Uint8List
              data: (bytes) {
                // Check if the byte list is empty
                if (bytes.isEmpty) {
                  return AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
                  );
                }
                
                // Use Image.memory() to display the bytes
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200, 
                );
              },
            ),

            // 2. Title and Subtitle Section (Unchanged)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Text(video.creatorName.isNotEmpty ? video.creatorName[0] : 'U'),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: Theme.of(context).textTheme.titleMedium,
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
          ],
        ),
      ),
    );
  }
}