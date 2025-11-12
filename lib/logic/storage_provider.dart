// lib/logic/storage_provider.dart
import 'dart:typed_data'; // Import this
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';

// --- ADD THESE IMPORTS ---
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// THIS IS THE FIX
import 'package:ofgconnects_mobile/logic/video_provider.dart'; 
// ---

final storageProvider = Provider((ref) => AppwriteClient.storage);

// 1. Thumbnail provider
final thumbnailProvider = FutureProvider.family<Uint8List, String>((ref, fileId) async {
  if (fileId.isEmpty) {
    return Uint8List(0); 
  }

  final storage = ref.watch(storageProvider);
  
  try {
    final result = await storage.getFilePreview(
      bucketId: AppwriteClient.bucketIdThumbnails,
      fileId: fileId,
    );
    return result;
  } catch (e) {
    print('Error getting thumbnail $fileId: $e');
    return Uint8List(0);
  }
});

// 2. Provider to download a video file and return its local File path
final videoFileProvider = FutureProvider.family<File, String>((ref, documentId) async {
  
  // This line will now work
  final video = await ref.watch(videoDetailsProvider(documentId).future);
  // This line will also work
  final videoFileId = video.videoId; 

  if (videoFileId.isEmpty) {
    throw Exception('Video file ID is empty');
  }

  final storage = ref.watch(storageProvider);
  
  // 1. Get the temporary directory
  final tempDir = await getTemporaryDirectory();
  final tempPath = tempDir.path;
  final tempFile = File('$tempPath/$videoFileId.mp4');

  // 2. Check if the file is already downloaded
  if (await tempFile.exists()) {
    print('Video $videoFileId already exists in cache.');
    return tempFile;
  }

  // 3. If not, download the file bytes
  print('Downloading video $videoFileId...');
  final bytes = await storage.getFileDownload(
    bucketId: AppwriteClient.bucketIdVideos,
    fileId: videoFileId,
  );

  // 4. Write the bytes to the temporary file
  await tempFile.writeAsBytes(bytes);
  print('Video $videoFileId downloaded and saved.');
  return tempFile;
});