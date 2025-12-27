import 'package:appwrite/models.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  
  final String videoUrl; // Raw file
  
  // New Quality Columns
  final String? url1080p;
  final String? url720p;
  final String? url480p;
  final String? url360p;
  
  final String compressionStatus;
  final String creatorId;
  final String creatorName;
  final String category;
  final List<String> tags;
  final int viewCount;
  final int likeCount;
  final DateTime createdAt;

  String get thumbnailId => thumbnailUrl;
  String get videoId => videoUrl; 

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    this.url1080p,
    this.url720p,
    this.url480p,
    this.url360p,
    required this.compressionStatus,
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
      
      videoUrl: doc.data['video_url'] ?? '',
      
      // Map the new quality columns
      url1080p: doc.data['url_1080p'],
      url720p: doc.data['url_720p'],
      url480p: doc.data['url_480p'],
      url360p: doc.data['url_360p'],
      
      compressionStatus: doc.data['compressionStatus'] ?? 'Processing',
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