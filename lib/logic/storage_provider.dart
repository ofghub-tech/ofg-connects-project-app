// lib/logic/storage_provider.dart
import 'dart:typed_data'; // Import this
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';

final storageProvider = Provider((ref) => AppwriteClient.storage);

// 1. Change the return type from FutureProvider<String> to FutureProvider<Uint8List>
final thumbnailProvider = FutureProvider.family<Uint8List, String>((ref, fileId) async {
  if (fileId.isEmpty) {
    // 2. Return an empty list for empty IDs
    return Uint8List(0); 
  }

  final storage = ref.watch(storageProvider);
  
  try {
    // 3. This method returns Future<Uint8List>
    final result = storage.getFilePreview(
      bucketId: AppwriteClient.bucketIdThumbnails,
      fileId: fileId,
    );
    return result; // 4. Return the bytes directly
  } catch (e) {
    print('Error getting thumbnail $fileId: $e');
    return Uint8List(0); // 5. Return an empty list on error
  }
});