// lib/models/video.dart
import 'package:appwrite/models.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl; // This field is for the URL
  final String videoUrl;     // This field is for the URL
  final String creatorId;
  final String creatorName;
  final String category;
  final List<String> tags;
  final int viewCount;
  final int likeCount;
  final DateTime createdAt;

  // --- FIX ---
  // These are getters that point to the real URL fields.
  // This makes the model compatible with your existing UI code
  // that still uses `video.videoId` and `video.thumbnailId`.
  String get videoId => videoUrl;
  String get thumbnailId => thumbnailUrl;
  // --- END FIX ---


  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.creatorId,
    required this.creatorName,
    required this.category,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    required this.createdAt,
  });

  factory Video.fromAppwrite(Document doc) {
    // Read from the database fields `thumbnailUrl` and `videoUrl`
    // just like the web app does.
    return Video(
      id: doc.$id,
      title: doc.data['title'] ?? 'Untitled',
      description: doc.data['description'] ?? '',
      thumbnailUrl: doc.data['thumbnailUrl'] ?? '', // Read from correct DB field
      videoUrl: doc.data['videoUrl'] ?? '',       // Read from correct DB field
      creatorId: doc.data['userId'] ?? '',
      creatorName: doc.data['username'] ?? 'Unknown',
      category: doc.data['category'] ?? 'general',
      tags: (doc.data['tags'] as String? ?? '').split(',').map((e) => e.trim()).toList(),
      viewCount: doc.data['view_count'] ?? 0,
      likeCount: doc.data['likeCount'] ?? 0,
      createdAt: DateTime.parse(doc.$createdAt),
    );
  }
}