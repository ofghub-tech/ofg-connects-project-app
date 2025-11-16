// lib/logic/video_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// 1. Provider to get the Appwrite Databases service
final databasesProvider = Provider((ref) => AppwriteClient.databases);

// 2. OLD provider that fetches ALL videos
final videoListProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [Query.orderDesc('\$createdAt')],
  );
  
  return response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});

// --- NEW ---
// 3. Provider that fetches ONLY SHORTS
final shortsListProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('category', 'shorts'), // Filter by category
      Query.orderDesc('\$createdAt'),
    ],
  );
  
  return response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});

// --- NEW ---
// 4. Provider that fetches ONLY NORMAL VIDEOS
final videosListProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.notEqual('category', 'shorts'), // Filter out shorts
      Query.orderDesc('\$createdAt'),
    ],
  );
  
  return response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});
// --- END NEW ---


// 5. The provider that fetches a SINGLE video's details (Unchanged)
final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  // ... (rest of your existing code is fine) ...
  final databases = ref.watch(databasesProvider);

  final document = await databases.getDocument(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    documentId: videoId,
  );
  
  return Video.fromAppwrite(document);
});


// 6. The provider that fetches all videos for the CURRENT user (Unchanged)
final userVideosProvider = FutureProvider<List<Video>>((ref) async {
  // ... (rest of your existing code is fine) ...
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;

  if (user == null) return [];

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('userId', user.$id),
      Query.orderDesc('\$createdAt')
    ],
  );
  
  return response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});


// 7. The provider that fetches videos from FOLLOWED users (Unchanged)
final followingVideosProvider = FutureProvider<List<Video>>((ref) async {
  // ... (rest of your existing code is fine) ...
  final databases = ref.watch(databasesProvider);
  final currentUserId = ref.watch(authProvider).user?.$id;

  if (currentUserId == null) return [];

  final followingResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [Query.equal('followerId', currentUserId)],
  );

  final followingIds = followingResponse.documents
      .map((doc) => doc.data['followingId'] as String)
      .toList();

  if (followingIds.isEmpty) return [];

  final videoResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('userId', followingIds),
      Query.orderDesc('\$createdAt'),
    ],
  );

  return videoResponse.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});