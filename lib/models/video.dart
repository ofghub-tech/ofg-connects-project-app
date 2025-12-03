import 'package:appwrite/models.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String creatorId;
  final String creatorName;
  final String category;
  final List<String> tags;
  final int viewCount;
  final int likeCount;
  final DateTime createdAt;

  // ... (keep your existing getters and constructor) ...
  String get thumbnailId => thumbnailUrl;
  String get videoId => videoUrl; 

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
    return Video(
      id: doc.$id,
      title: doc.data['title'] ?? 'Untitled',
      description: doc.data['description'] ?? '',
      thumbnailUrl: doc.data['thumbnailUrl'] ?? '',
      // --- FIX IS HERE ---
      // Try 'url_4k' first (where the web uploads to). If empty, try 'videoUrl'.
      videoUrl: (doc.data['url_4k'] != null && doc.data['url_4k'].isNotEmpty)
          ? doc.data['url_4k']
          : (doc.data['videoUrl'] ?? ''), 
      // -------------------
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