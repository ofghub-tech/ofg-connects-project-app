import 'dart:typed_data'; // Make sure this is imported
import 'package:flutter_riverpod/flutter_riverpod.dart'; // CORRECT
import 'package:ofgconnects_mobile/api/appwrite_client.dart'; // Ensure this path is correct

// This provider is simple and just gives us the Appwrite Storage instance
final storageProvider = Provider((ref) => AppwriteClient.storage);

// 1. Thumbnail provider (This logic was correct)
// This uses Appwrite's getFilePreview, which returns image bytes.
final thumbnailProvider = FutureProvider.family<Uint8List, String>((ref, fileId) async {
  if (fileId.isEmpty) {
    // Return an empty list instead of throwing an error,
    // so the UI can just show a placeholder.
    return Uint8List(0);
  }

  final storage = ref.watch(storageProvider);

  try {
    // This directly gets the image bytes from Appwrite
    final result = await storage.getFilePreview(
      bucketId: AppwriteClient.bucketIdThumbnails,
      fileId: fileId,
    );
    return result;
  } catch (e) {
    print('Error getting thumbnail $fileId: $e');
    return Uint8List(0); // Return empty on error
  }
});


// 2. Provider for Video STREAMING (FIXED)
// This provider gets the video's FILE ID and returns a
// temporary, streamable URL.
final videoStreamUrlProvider = FutureProvider.family<String, String>((ref, videoId) async {

  if (videoId.isEmpty) {
    throw Exception('Video file ID is empty');
  }

  final storage = ref.watch(storageProvider);

  try {
    
    // --- THIS IS THE FIX ---
    // Use 'getFileView' to get a direct URL string.
    // This method does NOT need 'await' as it builds the URL locally.
    final url = storage.getFileView(
      bucketId: AppwriteClient.bucketIdVideos,
      fileId: videoId,
    );
    
    // 'url' is a 'String', and the async function will correctly 
    // return it as a 'Future<String>'.
    return url; 
    // --- END FIX ---

  } catch (e) {
    print('Error getting video stream URL $videoId: $e');
    throw Exception('Could not get video stream: $e');
  }
});