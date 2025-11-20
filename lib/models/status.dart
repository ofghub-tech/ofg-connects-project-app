import 'package:appwrite/models.dart';

class Status {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String contentUrl;
  final String type; // 'image' or 'video'
  final String? caption;
  final DateTime expiresAt;
  final DateTime createdAt;

  Status({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.contentUrl,
    required this.type,
    this.caption,
    required this.expiresAt,
    required this.createdAt,
  });

  factory Status.fromAppwrite(Document doc) {
    return Status(
      id: doc.$id,
      userId: doc.data['userId'],
      username: doc.data['username'],
      userAvatar: doc.data['userAvatar'],
      contentUrl: doc.data['contentUrl'],
      type: doc.data['type'] ?? 'image',
      caption: doc.data['caption'],
      expiresAt: DateTime.parse(doc.data['expiresAt']),
      createdAt: DateTime.parse(doc.$createdAt),
    );
  }
}