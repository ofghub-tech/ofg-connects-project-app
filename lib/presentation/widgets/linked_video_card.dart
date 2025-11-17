// lib/presentation/widgets/linked_video_card.dart
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';

/// This widget is designed to be used in a paginated list of "link" documents
/// (like 'likes', 'history', 'watchLater'). It takes one of those documents,
/// finds the 'videoId' field inside it, and then uses that ID to
/// fetch and display the actual VideoCard.
class LinkedVideoCard extends ConsumerWidget {
  final Document linkDocument;
  final String videoIdField;

  const LinkedVideoCard({
    super.key,
    required this.linkDocument,
    this.videoIdField = 'videoId', // Default field name for the video ID
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Get the video ID from the link document
    final videoId = linkDocument.data[videoIdField];

    // 2. Handle cases where the video ID might be missing or invalid
    if (videoId == null || videoId.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(8.0),
        child: SizedBox(
          height: 100,
          child: Center(
            child: Text('Error: Video link is missing or broken.'),
          ),
        ),
      );
    }

    // 3. Use videoDetailsProvider to fetch the video
    // Riverpod handles caching, so this is very efficient.
    final videoAsync = ref.watch(videoDetailsProvider(videoId));

    // 4. Return the VideoCard, or loading/error states
    return videoAsync.when(
      data: (video) => VideoCard(video: video),
      
      loading: () => const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      ),
      
      error: (err, stack) => Card(
        margin: const EdgeInsets.all(8.0),
        color: Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error loading video (ID: $videoId). It may have been deleted.\n$err',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}