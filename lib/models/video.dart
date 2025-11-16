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

  // --- BACKWARD COMPATIBILITY GETTERS ---
  // These map the old property names to the new URL fields
  String get thumbnailId => thumbnailUrl;
  String get videoId => videoUrl; 
  // --------------------------------------

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
      videoUrl: doc.data['videoUrl'] ?? '',
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