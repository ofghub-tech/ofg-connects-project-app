// lib/logic/video_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// 1. Provider to get the Appwrite Databases service
//    (MUST BE DEFINED FIRST)
final databasesProvider = Provider((ref) => AppwriteClient.databases);

// 2. The provider that fetches the list of videos
final videoListProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    // You can add queries here, e.g., Query.limit(25)
  );
  
  // Convert the documents into a list of Video objects
  final videos = response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
  return videos;
});

// 3. The provider that fetches a SINGLE video's details
final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  final databases = ref.watch(databasesProvider);

  final document = await databases.getDocument(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    documentId: videoId,
  );
  
  // Convert the document into a Video object
  return Video.fromAppwrite(document);
});


// 4. The provider that fetches all videos for the CURRENT user
final userVideosProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  
  // Depend on authProvider to get the user's ID
  final user = ref.watch(authProvider).user;

  // If user is not logged in, return an empty list
  if (user == null) {
    return [];
  }

  // Fetch documents where 'userId' matches the logged-in user's ID
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('userId', user.$id),
      Query.orderDesc('\$createdAt') // Show newest videos first
    ],
  );
  
  final videos = response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
  return videos;
});


// 5. The provider that fetches videos from FOLLOWED users
final followingVideosProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  final currentUserId = ref.watch(authProvider).user?.$id;

  if (currentUserId == null) {
    return []; // Not logged in, no feed
  }

  // 1. Get the list of users the current user is following
  final followingResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [Query.equal('followerId', currentUserId)],
  );

  final followingIds = followingResponse.documents
      .map((doc) => doc.data['followingId'] as String)
      .toList();

  // 2. If the user isn't following anyone, return an empty list
  if (followingIds.isEmpty) {
    return [];
  }

  // 3. Fetch all videos where the 'userId' is in our list of followed IDs
  final videoResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('userId', followingIds), // Appwrite's 'equal' with a list acts as an 'IN' query
      Query.orderDesc('\$createdAt'),
    ],
  );

  final videos = videoResponse.documents.map((doc) => Video.fromAppwrite(doc)).toList();
  return videos;
});