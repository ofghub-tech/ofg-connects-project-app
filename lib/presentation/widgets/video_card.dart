import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

class VideoCard extends ConsumerWidget {
  final Video video;
  const VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShorts = video.category == 'shorts';
    final aspectRatio = isShorts ? 9 / 16 : 16 / 9;

    return GestureDetector(
      onTap: () {
        if (isShorts) {
          context.push('/shorts?id=${video.id}');
        } else {
          context.push('/watch/${video.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        decoration: OfgUi.cardDecoration(elevated: true),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: video.thumbnailUrl.isNotEmpty
                        ? Image.network(video.thumbnailUrl, fit: BoxFit.cover)
                        : Container(
                            color: OfgUi.surface2,
                            child: const Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white70,
                              size: 48,
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x55000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isShorts ? 'SHORTS' : 'VIDEO',
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
                    backgroundColor: OfgUi.surface2,
                    radius: 18,
                    child: Text(
                      video.creatorName.isNotEmpty
                          ? video.creatorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${video.creatorName} - ${video.viewCount} views - ${timeago.format(video.createdAt)}',
                          style: const TextStyle(color: OfgUi.muted2, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: OfgUi.muted2, size: 20),
                    color: const Color(0xFF282828),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) async {
                      if (value == 'not_interested') {
                        await ref
                            .read(authProvider.notifier)
                            .addToIgnoredList(videoId: video.id);
                        ref.read(videosListProvider.notifier).refresh();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Video removed. We will tune your recommendations.',
                              ),
                            ),
                          );
                        }
                      } else if (value == 'block') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "You won't see videos from ${video.creatorName} again (Pending ID implementation).",
                            ),
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
                            Text("Don't recommend channel", style: TextStyle(color: Colors.white)),
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
      ),
    );
  }
}
