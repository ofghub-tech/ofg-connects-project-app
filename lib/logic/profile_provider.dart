import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

// 1. Provider to fetch a specific user's videos (Paginated)
final otherUserVideosProvider = StateNotifierProvider.family<OtherUserVideosNotifier, PaginationState<Video>, String>((ref, userId) {
  return OtherUserVideosNotifier(ref, userId: userId);
});

// Extended from PaginatedListNotifier (inherits public methods now)
class OtherUserVideosNotifier extends PaginatedListNotifier<Video> {
  final String userId;
  
  OtherUserVideosNotifier(super.ref, {required this.userId}); 

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('userId', userId),
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }
}

// 2. Provider to get a specific user's stats (Followers/Following)
final otherUserStatsProvider = FutureProvider.family<Map<String, int>, String>((ref, userId) async {
  final databases = ref.watch(databasesProvider);

  // Fetch Follower Count
  final followers = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [
      Query.equal('followingId', userId),
      Query.limit(0),
    ],
  );

  // Fetch Following Count
  final following = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [
      Query.equal('followerId', userId),
      Query.limit(0),
    ],
  );

  return {
    'followers': followers.total,
    'following': following.total,
  };
});