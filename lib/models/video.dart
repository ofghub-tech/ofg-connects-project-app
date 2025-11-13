// lib/models/video.dart
import 'package:appwrite/models.dart';

class Video {
  final String id;
  final String title;
  final String thumbnailId; // This is poorly named, it will hold the URL
  final String videoId;     // This is poorly named, it will hold the URL
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

      // --- THIS IS THE FIX ---
      // This now correctly reads the URL fields from your database
      thumbnailId: doc.data['thumbnailUrl'] ?? '',  // Use 'thumbnailUrl'
      videoId: doc.data['videoUrl'] ?? '',        // Use 'videoUrl'
      // --- END FIX ---
      
      creatorId: doc.data['userId'] ?? '',        
      creatorName: doc.data['username'] ?? 'Unknown Creator',
    );
  }
}