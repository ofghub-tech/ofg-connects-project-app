import 'dart:io';
import 'dart:async'; 
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
  final double progress; 
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
  
  String? _currentBucket;
  String? _currentKey;
  bool _cancelRequested = false;

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

  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-]'), '_');
  }

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

    _currentBucket = bucketName;
    _currentKey = objectKey;

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
        if (_cancelRequested) return; 

        if (isVideo) {
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

  Future<void> _deleteFromR2(String bucket, String key) async {
    try {
      final minio = _getR2Client();
      await minio.removeObject(bucket, key);
    } catch (e) {
      print("Failed to cleanup R2 file: $e");
    }
  }

  String? _getKeyFromUrl(String url) {
    try {
      return url.split('/').last;
    } catch (e) {
      return null;
    }
  }

  Future<void> cancelUpload() async {
    if (!state.isLoading) return;
    _cancelRequested = true;
    state = UploadState(isLoading: true, isCancelling: true, error: "Cancelling...");
  }

  Future<void> uploadVideo({
    required File videoFile,
    required File? thumbnailFile,
    required String title,
    required String description,
    required String category,
    required String tags,
  }) async {
    _cancelRequested = false; 
    final user = ref.read(authProvider).user;
    
    if (user == null) {
      state = UploadState(error: "You must be logged in to upload.");
      return;
    }

    const MAX_SIZE = 5 * 1024 * 1024 * 1024; 
    if (await videoFile.length() > MAX_SIZE) {
      state = UploadState(error: "Video too large (Max 5GB).");
      return;
    }

    state = UploadState(isLoading: true, progress: 0.0, successMessage: "Starting Upload...");

    String? uploadedVideoUrl;
    String? uploadedThumbUrl;
    String? thumbFileId; // Variable to store the specific ID
    final minio = _getR2Client();

    try {
      final uniqueId = ID.unique();

      // --- STEP 1: UPLOAD VIDEO ---
      uploadedVideoUrl = await _uploadToR2(
        minio: minio,
        file: videoFile,
        bucketName: dotenv.env['R2_TEMP_BUCKET_NAME']!,
        domainUrl: dotenv.env['R2_PUBLIC_DOMAIN']!,
        fileId: uniqueId,
        isVideo: true
      );

      // --- STEP 2: UPLOAD THUMBNAIL (Auto or Custom) ---
      if (thumbnailFile != null && !_cancelRequested) {
        state = UploadState(isLoading: true, progress: 100, successMessage: "Uploading Thumbnail...");
        
        // FIX: Explicitly set the thumbnail ID so we can save it to DB
        thumbFileId = '${uniqueId}_thumb'; 
        
        uploadedThumbUrl = await _uploadToR2(
          minio: minio,
          file: thumbnailFile,
          bucketName: dotenv.env['R2_BUCKET_ID']!,
          domainUrl: dotenv.env['R2_MAIN_DOMAIN']!,
          fileId: thumbFileId, 
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
        data: {
          'title': title,
          'description': description,
          'userId': user.$id,
          'username': user.name,
          'category': category,
          'tags': tags.trim(),
          
          'video_url': uploadedVideoUrl, 
          'url_360p': null,
          
          'thumbnailUrl': uploadedThumbUrl,
          'thumbnailId': thumbFileId, // <--- FIXED: Now storing the ID
          
          'adminStatus': 'pending',
          'compressionStatus': 'Processing',
          'sourceFileId': videoKey,
          'likeCount': 0,
          'commentCount': 0,
          'view_count': 0,
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ]
      );

      uploadedVideoUrl = null; 
      uploadedThumbUrl = null;
      _currentKey = null;

      state = UploadState(isLoading: false, progress: 100, successMessage: "Video Uploaded Successfully!");

    } catch (e) {
      print("Upload Error/Cancel: $e");
      String msg = e.toString().contains("Cancelled") ? "Upload Cancelled" : "Upload Failed: ${e.toString()}";
      state = UploadState(isLoading: false, error: msg);

      if (uploadedVideoUrl != null) {
        final key = _getKeyFromUrl(uploadedVideoUrl!);
        if (key != null) await _deleteFromR2(dotenv.env['R2_TEMP_BUCKET_NAME']!, key);
      } else if (_currentBucket != null && _currentKey != null) {
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