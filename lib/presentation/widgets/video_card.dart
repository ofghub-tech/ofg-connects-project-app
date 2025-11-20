import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/models/video.dart';

class VideoCard extends ConsumerWidget {
  final Video video;
  const VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24), // Professional spacing
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Slightly lighter than bg
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/home/watch/${video.id}'),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Thumbnail with optimized cache
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Hero(
                      tag: 'video_thumbnail_${video.id}',
                      child: Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        // CRITICAL: Reduces memory usage by 70%+ on large feeds
                        cacheWidth: 800, 
                        loadingBuilder: (context, child, loadingProgress) => (loadingProgress == null) ? child : Container(color: const Color(0xFF2C2C2C)),
                        errorBuilder: (_,__,___) => Container(color: const Color(0xFF2C2C2C), child: const Icon(Icons.broken_image, color: Colors.white24)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("VIDEO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              // 2. Content Info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile/${video.creatorId}?name=${Uri.encodeComponent(video.creatorName)}'),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Row(
                            children: [
                              Text(video.creatorName, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                              const SizedBox(width: 4),
                              Icon(Icons.circle, size: 2, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text('${video.viewCount} views', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}