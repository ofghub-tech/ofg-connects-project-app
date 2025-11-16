import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart'; // for databasesProvider
import 'package:ofgconnects_mobile/models/video.dart';

// --- HELPER FUNCTION ---
// Replicates the logic of fetching video details from a list of IDs
Future<List<Video>> _fetchVideosByIds(Databases databases, List<String> videoIds) async {
  if (videoIds.isEmpty) return [];

  // Remove duplicates
  final uniqueIds = videoIds.toSet().toList();

  try {
    final response = await databases.listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('\$id', uniqueIds),
        Query.limit(uniqueIds.length), // Ensure we get all of them
      ],
    );

    // Map back to Video objects
    // We re-map them to preserve the original order (e.g., most recent history first)
    final fetchedVideos = response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
    
    List<Video> orderedVideos = [];
    for (var id in videoIds) {
      final video = fetchedVideos.firstWhere(
        (v) => v.id == id, 
        orElse: () => Video(id: '', title: 'Unknown', thumbnailId: '', videoId: '', creatorId: '', creatorName: '') // Dummy for deleted videos
      );
      if (video.id.isNotEmpty) {
        orderedVideos.add(video);
      }
    }
    return orderedVideos;

  } catch (e) {
    print('Error fetching video details: $e');
    return [];
  }
}

// 1. LIKED VIDEOS PROVIDER
final likedVideosProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  
  if (user == null) return [];

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdLikes,
    queries: [
      Query.equal('userId', user.$id),
      Query.orderDesc('\$createdAt'),
      Query.limit(50),
    ],
  );

  final videoIds = response.documents.map((doc) => doc.data['videoId'] as String).toList();
  return _fetchVideosByIds(databases, videoIds);
});

// 2. WATCH LATER PROVIDER
final watchLaterProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  
  if (user == null) return [];

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdWatchLater,
    queries: [
      Query.equal('userId', user.$id),
      Query.orderDesc('\$createdAt'),
      Query.limit(50),
    ],
  );

  final videoIds = response.documents.map((doc) => doc.data['videoId'] as String).toList();
  return _fetchVideosByIds(databases, videoIds);
});

// 3. HISTORY PROVIDER
final historyProvider = FutureProvider<List<Video>>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  
  if (user == null) return [];

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdHistory,
    queries: [
      Query.equal('userId', user.$id),
      Query.orderDesc('\$createdAt'),
      Query.limit(50),
    ],
  );

  final videoIds = response.documents.map((doc) => doc.data['videoId'] as String).toList();
  return _fetchVideosByIds(databases, videoIds);
});