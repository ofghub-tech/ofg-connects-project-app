// lib/logic/video_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart'; // <-- 1. ADDED THIS IMPORT
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// --- NEW: GENERIC PAGINATION STATE ---
class PaginationState<T> {
  final List<T> items;
  final bool isLoadingMore;
  final bool hasMore;

  PaginationState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// --- NEW: GENERIC PAGINATED NOTIFIER ---
abstract class PaginatedListNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginatedListNotifier(this.ref) : super(PaginationState<T>()) {
    fetchFirstBatch();
  }

  final Ref ref;
  final int _limit = 10; // Load 10 items at a time
  String? _lastId;

  // --- 2. CHANGED List<Query> to List<String> ---
  Future<List<Document>> _fetchPage(List<String> queries);
  T _fromDocument(Document doc);

  Future<void> fetchFirstBatch() async {
    if (state.items.isNotEmpty) return;

    state = state.copyWith(isLoadingMore: true, hasMore: true);
    _lastId = null; 

    try {
      // --- 3. UPDATED to use Query.limit (which returns a String) ---
      final documents = await _fetchPage([Query.limit(_limit)]);
      
      final newItems = documents.map(_fromDocument).toList();
      _lastId = documents.isNotEmpty ? documents.last.$id : null;

      state = state.copyWith(
        items: newItems,
        isLoadingMore: false,
        hasMore: newItems.length == _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      print("Error fetching first batch: $e");
    }
  }

  Future<void> fetchMore() async {
    if (state.isLoadingMore || !state.hasMore || _lastId == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      // --- 4. UPDATED to use Query.limit and Query.cursorAfter (which return Strings) ---
      final documents = await _fetchPage([
        Query.limit(_limit),
        Query.cursorAfter(_lastId!), // Use the cursor
      ]);

      final newItems = documents.map(_fromDocument).toList();
      _lastId = documents.isNotEmpty ? documents.last.$id : null;

      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        hasMore: newItems.length == _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      print("Error fetching more: $e");
    }
  }
}

// --- UPDATED PROVIDERS (NOW USING PAGINATION) ---

// 1. Provider to get the Appwrite Databases service
final databasesProvider = Provider((ref) => AppwriteClient.databases);

// 2. Notifier for ONLY SHORTS (Paginated)
class ShortsListNotifier extends PaginatedListNotifier<Video> {
  ShortsListNotifier(super.ref);

  @override
  Video _fromDocument(Document doc) => Video.fromAppwrite(doc);

  // --- 5. CHANGED List<Query> to List<String> ---
  @override
  Future<List<Document>> _fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('category', 'shorts'), // Filter by category
        Query.orderDesc('\$createdAt'),
        ...queries, // This includes limit() and cursorAfter()
      ],
    );
    return response.documents;
  }
}

final shortsListProvider = StateNotifierProvider<ShortsListNotifier, PaginationState<Video>>((ref) {
  return ShortsListNotifier(ref);
});

// 3. Notifier for ONLY NORMAL VIDEOS (Paginated)
class VideosListNotifier extends PaginatedListNotifier<Video> {
  VideosListNotifier(super.ref);

  @override
  Video _fromDocument(Document doc) => Video.fromAppwrite(doc);

  // --- 6. CHANGED List<Query> to List<String> ---
  @override
  Future<List<Document>> _fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.notEqual('category', 'shorts'), // Filter out shorts
        Query.orderDesc('\$createdAt'),
        ...queries, // This includes limit() and cursorAfter()
      ],
    );
    return response.documents;
  }
}

final videosListProvider = StateNotifierProvider<VideosListNotifier, PaginationState<Video>>((ref) {
  return VideosListNotifier(ref);
});


// --- OTHER PROVIDERS (Unchanged for now) ---
// We can apply pagination to these later if needed, following the same pattern.

// OLD provider that fetches ALL videos
final videoListProvider = FutureProvider<List<Video>>((ref) async {
  // ... (this is still here but unused by HomePage)
  final databases = ref.watch(databasesProvider);
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [Query.orderDesc('\$createdAt')],
  );
  return response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});

// The provider that fetches a SINGLE video's details
final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  // ... (unchanged)
  final databases = ref.watch(databasesProvider);
  final document = await databases.getDocument(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    documentId: videoId,
  );
  return Video.fromAppwrite(document);
});

// The provider that fetches all videos for the CURRENT user
final userVideosProvider = FutureProvider<List<Video>>((ref) async {
  // ... (unchanged)
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

// ... (followingVideosProvider, likedVideosProvider, etc. remain unchanged for now) ...
// Base function to get videos from a "link" collection (History, Likes, etc.)
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
// 11. Provider for Suggested Videos
final suggestedVideosProvider = FutureProvider.family<List<Video>, String>((ref, currentVideoId) async {
  final databases = ref.watch(databasesProvider);
  
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.limit(10),
      Query.orderDesc('\$createdAt'),
    ],
  );
  
  final allVideos = response.documents.map((d) => Video.fromAppwrite(d)).toList();
  
  // Filter out the video currently being watched
  return allVideos.where((v) => v.id != currentVideoId).toList();
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