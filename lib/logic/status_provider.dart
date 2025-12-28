import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:state_notifier/state_notifier.dart'; // <--- ADDED
import 'package:ofgconnects/models/status.dart';
import 'package:path/path.dart' as p;

class StatusFeedState {
  final Map<String, List<Status>> groupedStatuses;
  final bool isLoading;

  StatusFeedState({this.groupedStatuses = const {}, this.isLoading = false});
}

class StatusNotifier extends StateNotifier<StatusFeedState> {
  StatusNotifier(this.ref) : super(StatusFeedState());
  final Ref ref;

  Future<void> fetchStatuses() async {
    state = StatusFeedState(isLoading: true, groupedStatuses: state.groupedStatuses);

    try {
      final now = DateTime.now().toIso8601String();

      final response = await AppwriteClient.databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdStatuses,
        queries: [
          // Only get statuses that haven't expired yet
          Query.greaterThan('expiresAt', now),
          Query.orderDesc('\$createdAt'),
          Query.limit(100),
        ],
      );

      final allStatuses = response.documents.map((d) => Status.fromAppwrite(d)).toList();

      // Group by User ID
      final Map<String, List<Status>> grouped = {};
      for (var status in allStatuses) {
        if (!grouped.containsKey(status.userId)) {
          grouped[status.userId] = [];
        }
        grouped[status.userId]!.add(status);
      }

      state = StatusFeedState(isLoading: false, groupedStatuses: grouped);
    } catch (e) {
      print("Error fetching statuses: $e");
      state = StatusFeedState(isLoading: false);
    }
  }

  Future<void> uploadStatus({required File file, String? caption}) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      // 1. Upload Media
      final fileId = ID.unique();
      final fileExt = p.extension(file.path);
      // Simple check for image vs video
      final type = ['jpg', 'jpeg', 'png', 'webp'].contains(fileExt.replaceAll('.', '').toLowerCase()) ? 'image' : 'video';
      
      await AppwriteClient.storage.createFile(
        bucketId: AppwriteClient.bucketIdThumbnails, // Reusing thumbnails bucket for statuses for now
        fileId: fileId,
        file: InputFile.fromPath(path: file.path, filename: 'status_$fileId$fileExt'),
        permissions: [Permission.read(Role.any())],
      );

      final url = AppwriteClient.storage.getFileView(
        bucketId: AppwriteClient.bucketIdThumbnails,
        fileId: fileId,
      ).toString();

      // 2. Create Document (Expires in 24 hours)
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      await AppwriteClient.databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdStatuses,
        documentId: ID.unique(),
        data: {
          'userId': user.$id,
          'username': user.name,
          'userAvatar': user.prefs.data['avatar'],
          'contentUrl': url,
          'type': type,
          'caption': caption,
          'expiresAt': expiresAt.toIso8601String(),
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.delete(Role.user(user.$id)),
        ]
      );

      // Refresh feed
      fetchStatuses();
    } catch (e) {
      print("Error uploading status: $e");
      rethrow;
    }
  }
}

final statusProvider = StateNotifierProvider<StatusNotifier, StatusFeedState>((ref) {
  return StatusNotifier(ref);
});