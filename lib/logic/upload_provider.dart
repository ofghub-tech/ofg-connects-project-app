import 'dart:io';
import 'dart:async'; // Required for Completer/Cancel
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:path/path.dart' as p;
import 'package:minio/minio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- STATE CLASS ---
class UploadState {
  final bool isLoading;
  final double progress; // 0.0 to 100.0
  final String? error;
  final String? successMessage;
  final bool isCancelling;

  UploadState({
    this.isLoading = false,
    this.progress = 0.0,
    this.error,
    this.successMessage,
    this.isCancelling = false,
  });
}

// --- NOTIFIER CLASS ---
class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier(this.ref) : super(UploadState());
  
  final Ref ref;
  
  // Track keys for cleanup if upload fails or is cancelled
  String? _currentBucket;
  String? _currentKey;
  bool _cancelRequested = false;

  // --- R2 CONFIG ---
  Minio _getR2Client() {
    final endpoint = dotenv.env['R2_ENDPOINT']!.replaceAll('https://', '');
    return Minio(
      endPoint: endpoint,
      accessKey: dotenv.env['R2_ACCESS_KEY_ID']!,
      secretKey: dotenv.env['R2_SECRET_ACCESS_KEY']!,
      region: 'auto',
      useSSL: true, 
    );
  }

  // --- 1. SANITIZE FILENAME (Matches Web Logic) ---
  String _sanitizeFilename(String filename) {
    // Replaces non-alphanumeric (except . and -) with _
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-]'), '_');
  }

  // --- 2. UPLOAD HELPER ---
  Future<String> _uploadToR2({
    required Minio minio,
    required File file,
    required String bucketName,
    required String domainUrl,
    required String fileId,
    required bool isVideo,
  }) async {
    if (_cancelRequested) throw Exception("Upload Cancelled by User");

    final rawFilename = p.basename(file.path);
    final cleanName = _sanitizeFilename(rawFilename);
    final objectKey = '${fileId}_$cleanName';

    // Store for cleanup
    _currentBucket = bucketName;
    _currentKey = objectKey;

    // HTTPS Safety
    String finalDomain = domainUrl;
    if (!finalDomain.startsWith('http')) {
      finalDomain = 'https://$finalDomain';
    }

    final fileSize = await file.length();
    final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));

    await minio.putObject(
      bucketName,
      objectKey,
      stream,
      size: fileSize,
      onProgress: (bytes) {
        if (_cancelRequested) return; // Stop updating if cancelled

        if (isVideo) {
          // Calculate percentage exactly like Web: (loaded / total) * 100
          double percent = (bytes / fileSize) * 100;
          state = UploadState(
            isLoading: true,
            progress: percent,
            successMessage: "Uploading... ${percent.toInt()}%"
          );
        }
      },
    );

    if (_cancelRequested) throw Exception("Upload Cancelled by User");

    return '$finalDomain/$objectKey';
  }

  // --- 3. CLEANUP HELPER ---
  Future<void> _deleteFromR2(String bucket, String key) async {
    try {
      final minio = _getR2Client();
      print("Cleaning up file: $key from $bucket");
      await minio.removeObject(bucket, key);
    } catch (e) {
      print("Failed to cleanup R2 file: $e");
    }
  }

  // --- 4. EXTRACT KEY HELPER ---
  String? _getKeyFromUrl(String url) {
    try {
      return url.split('/').last;
    } catch (e) {
      return null;
    }
  }

  // --- PUBLIC: CANCEL UPLOAD ---
  Future<void> cancelUpload() async {
    if (!state.isLoading) return;

    _cancelRequested = true;
    state = UploadState(isLoading: true, isCancelling: true, error: "Cancelling...");
    
    // The loop in uploadVideo will catch the exception and trigger cleanup
    // We strictly handle the cleanup in the catch block below.
  }

  // --- MAIN: UPLOAD VIDEO ---
  Future<void> uploadVideo({
    required File videoFile,
    required File? thumbnailFile,
    required String title,
    required String description,
    required String category,
    required String tags,
  }) async {
    _cancelRequested = false; // Reset cancel flag
    final user = ref.read(authProvider).user;
    
    if (user == null) {
      state = UploadState(error: "You must be logged in to upload.");
      return;
    }

    // Validation (Matches Web 5GB limit)
    const MAX_SIZE = 5 * 1024 * 1024 * 1024; 
    if (await videoFile.length() > MAX_SIZE) {
      state = UploadState(error: "Video too large (Max 5GB).");
      return;
    }

    state = UploadState(isLoading: true, progress: 0.0, successMessage: "Starting Upload...");

    String? uploadedVideoUrl;
    String? uploadedThumbUrl;
    final minio = _getR2Client();

    try {
      final uniqueId = ID.unique();

      // --- STEP 1: UPLOAD VIDEO (Temp Bucket) ---
      // No compression, just like Web
      uploadedVideoUrl = await _uploadToR2(
        minio: minio,
        file: videoFile,
        bucketName: dotenv.env['R2_TEMP_BUCKET_NAME']!,
        domainUrl: dotenv.env['R2_PUBLIC_DOMAIN']!,
        fileId: uniqueId,
        isVideo: true
      );

      // --- STEP 2: UPLOAD THUMBNAIL (Main Bucket) ---
      if (thumbnailFile != null && !_cancelRequested) {
        state = UploadState(isLoading: true, progress: 100, successMessage: "Uploading Thumbnail...");
        
        uploadedThumbUrl = await _uploadToR2(
          minio: minio,
          file: thumbnailFile,
          bucketName: dotenv.env['R2_BUCKET_ID']!,
          domainUrl: dotenv.env['R2_MAIN_DOMAIN']!,
          fileId: '${uniqueId}_thumb',
          isVideo: false
        );
      }

      // --- STEP 3: CREATE DB DOCUMENT ---
      if (_cancelRequested) throw Exception("Upload Cancelled");

      state = UploadState(isLoading: true, progress: 100, successMessage: "Finalizing...");

      final videoKey = _getKeyFromUrl(uploadedVideoUrl!);
      final databases = AppwriteClient.databases;

      await databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: uniqueId,
        // Matches Web Code Data Structure Exactly
        data: {
          'title': title,
          'description': description,
          'userId': user.$id,
          'username': user.name,
          'category': category,
          'tags': tags.trim(),
          
          // --- UPDATED: Save Raw Video to video_url ---
          'video_url': uploadedVideoUrl, 
          'url_360p': null, // Initialize compressed URL as null
          
          'thumbnailUrl': uploadedThumbUrl,
          'adminStatus': 'pending',
          'compressionStatus': 'Processing', // Set to Processing so app knows to use video_url
          'sourceFileId': videoKey,
          'likeCount': 0,
          'commentCount': 0,
          'view_count': 0,
          // No createdAt (System handles it)
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ]
      );

      // Success
      uploadedVideoUrl = null; 
      uploadedThumbUrl = null;
      _currentKey = null; // Clear cleanup reference

      state = UploadState(isLoading: false, progress: 100, successMessage: "Video Uploaded Successfully!");

    } catch (e) {
      // --- ERROR & CLEANUP HANDLER ---
      print("Upload Error/Cancel: $e");
      
      String msg = e.toString().contains("Cancelled") ? "Upload Cancelled" : "Upload Failed: ${e.toString()}";
      state = UploadState(isLoading: false, error: msg);

      // Execute Cleanup
      if (uploadedVideoUrl != null) {
        final key = _getKeyFromUrl(uploadedVideoUrl!);
        if (key != null) await _deleteFromR2(dotenv.env['R2_TEMP_BUCKET_NAME']!, key);
      }
      // If we failed mid-upload, use the tracked keys
      else if (_currentBucket != null && _currentKey != null) {
        await _deleteFromR2(_currentBucket!, _currentKey!);
      }
      
      if (uploadedThumbUrl != null) {
         final key = _getKeyFromUrl(uploadedThumbUrl!);
         if (key != null) await _deleteFromR2(dotenv.env['R2_BUCKET_ID']!, key);
      }
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});