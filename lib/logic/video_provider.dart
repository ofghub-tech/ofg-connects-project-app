// lib/logic/video_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/models/video.dart';

// 1. Provider to get the Appwrite Databases service
final databasesProvider = Provider((ref) => AppwriteClient.databases);

// 2. The provider that fetches the list of videos
final videoListProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  
  try {
    final response = await databases.listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      // You can add queries here, e.g., Query.limit(25)
    );
    
    // Convert the documents into a list of Video objects
    final videos = response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
    return videos;

  } catch (e) {
    print('Error fetching videos: $e');
    rethrow;
  }
});