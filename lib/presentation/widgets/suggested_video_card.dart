// lib/presentation/widgets/suggested_video_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/models/video.dart';

class SuggestedVideoCard extends ConsumerWidget {
  final Video video;
  const SuggestedVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        // Navigate to the new video
        context.push('/home/watch/${video.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Thumbnail Section
            SizedBox(
              width: 160,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'suggested_thumbnail_${video.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: video.thumbnailUrl.isEmpty
                          ? Container(color: Colors.grey[900])
                          : Image.network(
                              video.thumbnailUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(color: Colors.grey[900]);
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.broken_image, color: Colors.white24),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12.0),

            // 2. Title and Creator Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  // --- CLICKABLE NAME ---
                  GestureDetector(
                    onTap: () => context.push('/profile/${video.creatorId}?name=${Uri.encodeComponent(video.creatorName)}'),
                    child: Text(
                      video.creatorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '${video.viewCount} views',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 12,
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