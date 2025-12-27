import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ofgconnects_mobile/models/video.dart';

class VideoCard extends ConsumerWidget {
  final Video video;
  const VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. DETERMINE ASPECT RATIO BASED ON CATEGORY
    final bool isShorts = video.category == 'shorts';
    final double aspectRatio = isShorts ? 9 / 16 : 16 / 9;

    return GestureDetector(
      onTap: () {
        if (isShorts) {
          // FIX: Use push instead of go to maintain navigation history for back gestures
          context.push('/shorts?id=${video.id}');
        } else {
          context.push('/watch/${video.id}');
        }
      },
      child: Column(
        children: [
          // 2. APPLY DYNAMIC ASPECT RATIO
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.grey[900],
                  child: video.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.error, color: Colors.white)),
                        )
                      : const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 50)),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      isShorts ? "SHORTS" : "VIDEO", 
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  radius: 18,
                  child: Text(video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${video.creatorName} • ${video.viewCount} views • ${timeago.format(video.createdAt)}",
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert, color: Colors.white, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}