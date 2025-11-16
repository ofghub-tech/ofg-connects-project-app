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


// 5. The provider that fetches a SINGLE video's details
final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  final databases = ref.watch(databasesProvider);

  final document = await databases.getDocument(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    documentId: videoId,
  );
  
  return Video.fromAppwrite(document);
});


// 6. The provider that fetches all videos for the CURRENT user
final userVideosProvider = FutureProvider<List<Video>>((ref) async {
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


// 7. The provider that fetches videos from FOLLOWED users
final followingVideosProvider = FutureProvider<List<Video>>((ref) async {
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

// --- NEWLY ADDED PROVIDERS ---

// Base function to get videos from a "link" collection (History, Likes, etc.)
// This avoids duplicating code.
Future<List<Video>> _getVideosFromLinkCollection({
  required Ref ref,
  required String collectionId,
  required String userId,
  required String videoIdField,
}) async {
  final databases = ref.watch(databasesProvider);

  // 1. Get all documents from the link collection (e.g., all history items)
  final linkDocsResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: collectionId,
    queries: [
      Query.equal('userId', userId),
      Query.orderDesc('\$createdAt'),
    ],
  );

  // 2. Extract all the unique video IDs from those documents
  final videoIds = linkDocsResponse.documents
      .map((doc) => doc.data[videoIdField] as String?)
      .where((id) => id != null)
      .toSet() // Use a Set to remove duplicates
      .toList();

  if (videoIds.isEmpty) {
    return [];
  }

  // 3. Fetch all videos that match those IDs
  final videoResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('\$id', videoIds), // Find all videos whose ID is in our list
    ],
  );

  // 4. Convert to Video objects and return
  return videoResponse.documents.map((doc) => Video.fromAppwrite(doc)).toList();
}

// 8. Provider for Liked Videos
final likedVideosProvider = FutureProvider<List<Video>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];

  return _getVideosFromLinkCollection(
    ref: ref,
    collectionId: AppwriteClient.collectionIdLikes,
    userId: user.$id,
    videoIdField: 'videoId', // The field in the 'likes' collection that holds the video ID
  );
});

// 9. Provider for Watch Later
final watchLaterProvider = FutureProvider<List<Video>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];

  return _getVideosFromLinkCollection(
    ref: ref,
    collectionId: AppwriteClient.collectionIdWatchLater,
    userId: user.$id,
    videoIdField: 'videoId', // The field in the 'watch_later' collection
  );
});

// 10. Provider for History
final historyProvider = FutureProvider<List<Video>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];

  return _getVideosFromLinkCollection(
    ref: ref,
    collectionId: AppwriteClient.collectionIdHistory,
    userId: user.$id,
    videoIdField: 'videoId', // The field in the 'history' collection
  );
});