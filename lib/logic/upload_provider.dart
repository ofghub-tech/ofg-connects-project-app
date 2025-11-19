// lib/logic/upload_provider.dart
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as p;

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
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = UploadState(error: "You must be logged in to upload.");
      return;
    }

    state = UploadState(isLoading: true, progress: 0.0, successMessage: "Preparing...");

    String? videoId;
    String? thumbnailId;
    Subscription? subscription;

    try {
      final storage = AppwriteClient.storage;
      final databases = AppwriteClient.databases;

      // --- 1. COMPRESSION LOGIC ---
      File fileToUpload = videoFile;
      
      try {
        state = UploadState(isLoading: true, progress: 0.05, successMessage: "Compressing video...");
        
        subscription = VideoCompress.compressProgress$.subscribe((progress) {
           state = UploadState(
             isLoading: true, 
             progress: (progress / 100) * 0.3, // First 30% is compression
             successMessage: "Compressing... ${progress.toInt()}%"
           );
        });

        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality, 
          deleteOrigin: false,
        );

        if (mediaInfo != null && mediaInfo.file != null) {
          fileToUpload = mediaInfo.file!;
        }
      } catch (e) {
        print("Compression failed, uploading original file: $e");
        // Fallback to original file if compression fails
      }

      // --- 2. UPLOAD VIDEO ---
      state = UploadState(isLoading: true, progress: 0.3, successMessage: "Uploading Video...");

      videoId = ID.unique();
      final String videoFileName = 'video_${DateTime.now().millisecondsSinceEpoch}${p.extension(fileToUpload.path)}';

      await storage.createFile(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: videoId,
        // Explicitly provide filename for correct mime-type detection
        file: InputFile.fromPath(
          path: fileToUpload.path, 
          filename: videoFileName
        ),
        permissions: [Permission.read(Role.any())],
        onProgress: (uploadProgress) {
          // Map upload (0-100) to progress range (0.3 - 0.9)
          final percent = 0.3 + ((uploadProgress.progress / 100) * 0.6);
          state = UploadState(
            isLoading: true, 
            progress: percent, 
            successMessage: "Uploading... ${uploadProgress.progress.toInt()}%"
          );
        },
      );

      final videoUrlPath = storage.getFileView(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: videoId,
      ).toString();

      // --- 3. UPLOAD THUMBNAIL ---
      String? thumbnailUrlPath;
      if (thumbnailFile != null) {
        state = UploadState(isLoading: true, progress: 0.92, successMessage: "Uploading Thumbnail...");
        thumbnailId = ID.unique();
        final String thumbFileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}${p.extension(thumbnailFile.path)}';

        await storage.createFile(
          bucketId: AppwriteClient.bucketIdVideos,
          fileId: thumbnailId,
          file: InputFile.fromPath(
            path: thumbnailFile.path, 
            filename: thumbFileName
          ),
          permissions: [Permission.read(Role.any())],
        );
        
        thumbnailUrlPath = storage.getFileView(
          bucketId: AppwriteClient.bucketIdVideos,
          fileId: thumbnailId,
        ).toString();
      }

      // --- 4. CREATE DATABASE DOCUMENT ---
      state = UploadState(isLoading: true, progress: 0.98, successMessage: "Finalizing...");

      await databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId, // Use video file ID as doc ID
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
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ]
      );
      
      // Cleanup cache
      await VideoCompress.deleteAllCache();

      state = UploadState(isLoading: false, progress: 1.0, successMessage: "Upload Successful!");

    } catch (e) {
      print("Upload Error: $e");
      // Cleanup orphaned files using static client
      if (videoId != null) {
        try { await AppwriteClient.storage.deleteFile(bucketId: AppwriteClient.bucketIdVideos, fileId: videoId); } catch (_) {}
      }
      if (thumbnailId != null) {
        try { await AppwriteClient.storage.deleteFile(bucketId: AppwriteClient.bucketIdVideos, fileId: thumbnailId); } catch (_) {}
      }

      state = UploadState(isLoading: false, error: e.toString());
    } finally {
      subscription?.unsubscribe();
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});