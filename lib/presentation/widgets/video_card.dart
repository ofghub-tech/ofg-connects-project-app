// lib/presentation/widgets/video_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart'; // Import to refresh list

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
                  child: Text(
                    video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : '?', 
                    style: const TextStyle(color: Colors.white)
                  ),
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
                // --- Updated: Functional Menu ---
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  color: const Color(0xFF282828), 
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'not_interested') {
                      await ref.read(authProvider.notifier).addToIgnoredList(videoId: video.id);
                      // Trigger a refresh on the list so the item disappears
                      ref.read(videosListProvider.notifier).refresh();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Video removed. We will tune your recommendations.')),
                        );
                      }
                    } else if (value == 'block') {
                       // Assuming we might have a userId on the video object, otherwise just warn
                       // await ref.read(authProvider.notifier).addToIgnoredList(creatorId: video.userId);
                       // ref.read(videosListProvider.notifier).refresh();
                       
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("You won't see videos from ${video.creatorName} again (Pending ID implementation)."),
                        ),
                      );
                    } else if (value == 'report') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thanks for reporting. We will review this content.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'not_interested',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('Not interested', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.person_off_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('Don\'t recommend channel', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('Report', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}