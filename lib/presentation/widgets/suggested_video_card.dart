import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

class SuggestedVideoCard extends StatelessWidget {
  final Video video;
  const SuggestedVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: OfgUi.cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 132,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: video.thumbnailUrl.isNotEmpty
                            ? Image.network(video.thumbnailUrl, fit: BoxFit.cover)
                            : Container(color: OfgUi.surface2),
                      ),
                      if (isShorts)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.black.withOpacity(0.7),
                            child: const Icon(
                              Icons.movie_filter_outlined,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.creatorName,
                    style: const TextStyle(color: OfgUi.muted2, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${video.viewCount} views - ${timeago.format(video.createdAt, locale: 'en_short')}",
                    style: const TextStyle(color: OfgUi.muted2, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, size: 18, color: OfgUi.muted2),
          ],
        ),
      ),
    );
  }
}


