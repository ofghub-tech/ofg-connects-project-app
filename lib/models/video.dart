// lib/models/video.dart
import 'package:appwrite/models.dart';

class Video {
  final String id;
  final String title;
  final String thumbnailId;
  final String videoId;
  final String creatorId;
  final String creatorName;
  // Add any other fields you need, like view_count, description, etc.

  Video({
    required this.id,
    required this.title,
    required this.thumbnailId,
    required this.videoId,
    required this.creatorId,
    required this.creatorName,
  });

  // A factory constructor to create a Video from an Appwrite document
  factory Video.fromAppwrite(Document doc) {
    return Video(
      id: doc.$id,
      title: doc.data['title'] ?? 'Untitled',
      thumbnailId: doc.data['thumbnail_id'] ?? '',
      videoId: doc.data['video_id'] ?? '',
      creatorId: doc.data['creator_id'] ?? '',
      creatorName: doc.data['creator_name'] ?? 'Unknown Creator',
      // Safely access other fields here
    );
  }
}