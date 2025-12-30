import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ofgconnects/models/video.dart';

class SuggestedVideoCard extends StatelessWidget {
  final Video video;
  const SuggestedVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    // 1. Check if it is a Short
    final bool isShorts = video.category == 'shorts';
    
    // 2. Define Aspect Ratio based on type
    final double aspectRatio = isShorts ? 9 / 16 : 16 / 9;

    return GestureDetector(
      onTap: () {
        // 3. Navigate to appropriate page
        if (isShorts) {
          // Use push to allow going back to the current video
          context.push('/shorts?id=${video.id}');
        } else {
          context.push('/watch/${video.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.transparent, // Ensures hit test works on empty space
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- THUMBNAIL SECTION ---
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                // We fix the width, and let the height adjust based on aspect ratio
                width: 140, 
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.grey[900],
                        width: double.infinity,
                        height: double.infinity,
                        child: video.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                video.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.error, color: Colors.white)),
                              )
                            : const Center(child: Icon(Icons.play_circle_outline, color: Colors.white)),
                      ),
                      // Optional: Add "Shorts" label on the thumbnail
                      if (isShorts)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.black.withOpacity(0.7),
                            child: const Icon(Icons.movie_filter_outlined, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // --- TEXT DETAILS SECTION ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.creatorName,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${video.viewCount} views • ${timeago.format(video.createdAt, locale: 'en_short')}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Option Menu Icon
            GestureDetector(
              onTap: () {
                // Show bottom sheet options if needed
              },
              child: const Icon(Icons.more_vert, size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}