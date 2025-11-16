// lib/presentation/widgets/shorts_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/storage_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

class ShortsCard extends ConsumerWidget {
  final Video video;
  const ShortsCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use the thumbnailProvider to load the image from the URL
    final thumbnailDataAsync = ref.watch(thumbnailProvider(video.thumbnailId));

    return InkWell(
      onTap: () {
        // Navigate to the shorts player, passing the video ID
        // so it can jump to this specific short.
        context.go('/shorts?id=${video.id}');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 9:16 Aspect Ratio
            AspectRatio(
              aspectRatio: 9 / 16,
              child: thumbnailDataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.error, color: Colors.red),
                ),
                data: (bytes) {
                  if (bytes.isEmpty) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.image_not_supported, color: Colors.white54),
                    );
                  }
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Title
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}