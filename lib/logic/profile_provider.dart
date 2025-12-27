import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// --- 1. VIDEOS TAB (Long form, excludes shorts) ---
final otherUserLongVideosProvider = StateNotifierProvider.family<OtherUserContentNotifier, PaginationState<Video>, String>((ref, userId) {
  return OtherUserContentNotifier(ref, userId: userId, categoryFilter: 'videos');
});

// --- 2. SONGS TAB (Category == 'music' or 'song') ---
final otherUserSongsProvider = StateNotifierProvider.family<OtherUserContentNotifier, PaginationState<Video>, String>((ref, userId) {
  return OtherUserContentNotifier(ref, userId: userId, categoryFilter: 'music');
});

// --- 3. SHORTS TAB (Category == 'shorts') ---
final otherUserShortsProvider = StateNotifierProvider.family<OtherUserContentNotifier, PaginationState<Video>, String>((ref, userId) {
  return OtherUserContentNotifier(ref, userId: userId, categoryFilter: 'shorts');
});

class OtherUserContentNotifier extends PaginatedListNotifier<Video> {
  final String userId;
  final String categoryFilter; // 'videos', 'music', 'shorts'
  
  OtherUserContentNotifier(super.ref, {required this.userId, required this.categoryFilter}); 

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    // 1. Get Current User ID to check if "It's Me"
    final currentUser = ref.read(authProvider).user;
    final isMe = currentUser?.$id == userId;

    final List<String> filterQueries = [
      Query.equal('userId', userId),
      Query.orderDesc('\$createdAt'),
    ];

    // 2. LOGIC FIX: 
    // If it is NOT me (Public view) -> Show ONLY Approved.
    // If it IS me (Owner view) -> Show EVERYTHING (Approved + Pending + Rejected).
    if (!isMe) {
      filterQueries.add(Query.equal('adminStatus', 'approved'));
    }

    // 3. Category Filters
    if (categoryFilter == 'shorts') {
      filterQueries.add(Query.equal('category', 'shorts'));
    } else if (categoryFilter == 'music') {
      // Checks for 'music' OR 'song' OR 'songs'
      filterQueries.add(Query.equal('category', ['music', 'song', 'songs']));
    } else {
      // For standard 'Videos' tab, exclude shorts
      filterQueries.add(Query.notEqual('category', 'shorts'));
    }

    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        ...filterQueries,
        ...queries,
      ],
    );
    return response.documents;
  }
}

// --- STATS PROVIDER ---
final otherUserStatsProvider = FutureProvider.family<Map<String, int>, String>((ref, userId) async {
  final databases = ref.watch(databasesProvider);
  final followers = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [Query.equal('followingId', userId), Query.limit(0)],
  );
  final following = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [Query.equal('followerId', userId), Query.limit(0)],
  );
  return {'followers': followers.total, 'following': following.total};
});