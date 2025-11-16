// lib/logic/upload_provider.dart
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// State to track upload progress
class UploadState {
  final bool isLoading;
  final double progress;
  final String? error;
  final String? successMessage;

  UploadState({
    this.isLoading = false,
    this.progress = 0.0,
    this.error,
    this.successMessage,
  });
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier(this.ref) : super(UploadState());
  
  final Ref ref;

  Future<void> uploadVideo({
    required File videoFile,
    required File? thumbnailFile,
    required String title,
    required String description,
    required String category,
    required String tags,
  }) async {
    // 1. Get Current User
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = UploadState(error: "You must be logged in to upload.");
      return;
    }

    state = UploadState(isLoading: true, progress: 0.1);

    String? videoId;
    String? thumbnailId;

    try {
      final storage = AppwriteClient.storage;
      final databases = AppwriteClient.databases;

      // 2. Upload Video File
      // Replicates: storage.createFile(BUCKET_ID_VIDEOS...)
      videoId = ID.unique();
      await storage.createFile(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: videoId,
        file: InputFile.fromPath(path: videoFile.path),
        permissions: [Permission.read(Role.any())],
        onProgress: (uploadProgress) {
          // Update state with progress (0% to 80% allocated for video)
          final percent = (uploadProgress.progress / 100) * 0.8;
          state = UploadState(isLoading: true, progress: percent);
        },
      );

      // Generate View URL immediately after upload
      final videoUrlPath = storage.getFileView(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: videoId,
      ).toString();

      // 3. Upload Thumbnail (Optional)
      // Replicates: if (thumbnailFile) ... storage.createFile(...)
      String? thumbnailUrlPath;
      if (thumbnailFile != null) {
        thumbnailId = ID.unique();
        await storage.createFile(
          bucketId: AppwriteClient.bucketIdVideos, // Web app uses same bucket
          fileId: thumbnailId,
          file: InputFile.fromPath(path: thumbnailFile.path),
          permissions: [Permission.read(Role.any())],
        );
        
        thumbnailUrlPath = storage.getFileView(
          bucketId: AppwriteClient.bucketIdVideos,
          fileId: thumbnailId,
        ).toString();
      }

      state = UploadState(isLoading: true, progress: 0.9);

      // 4. Create Database Document
      // Replicates: databases.createDocument(...)
      await databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId, // Using video file ID as doc ID is a common pattern
        data: {
          'title': title,
          'description': description,
          'category': category,
          'tags': tags,
          'videoUrl': videoUrlPath,
          'thumbnailUrl': thumbnailUrlPath,
          'userId': user.$id,
          'username': user.name,
          'view_count': 0,
          'likeCount': 0,
          'commentCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      state = UploadState(isLoading: false, progress: 1.0, successMessage: "Upload Successful!");

    } catch (e) {
      // 5. Cleanup (Replicating the useEffect cleanup logic from web)
      // If DB write fails, delete the uploaded files to save space
      final storage = AppwriteClient.storage;
      if (videoId != null) {
        try { await storage.deleteFile(bucketId: AppwriteClient.bucketIdVideos, fileId: videoId); } catch (_) {}
      }
      if (thumbnailId != null) {
        try { await storage.deleteFile(bucketId: AppwriteClient.bucketIdVideos, fileId: thumbnailId); } catch (_) {}
      }

      state = UploadState(isLoading: false, error: e.toString());
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});