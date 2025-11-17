// lib/logic/video_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// --- GENERIC PAGINATION STATE ---
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

// --- GENERIC PAGINATED NOTIFIER ---
abstract class PaginatedListNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginatedListNotifier(this.ref) : super(PaginationState<T>()) {
    fetchFirstBatch();
  }

  final Ref ref;
  final int _limit = 10; // Load 10 items at a time
  String? _lastId;

  Future<List<Document>> _fetchPage(List<String> queries);
  T _fromDocument(Document doc);

  Future<void> fetchFirstBatch() async {
    if (state.items.isNotEmpty) return;

    state = state.copyWith(isLoadingMore: true, hasMore: true);
    _lastId = null; 

    try {
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

// --- PROVIDERS ---

final databasesProvider = Provider((ref) => AppwriteClient.databases);

// Notifier for ONLY SHORTS (Paginated)
class ShortsListNotifier extends PaginatedListNotifier<Video> {
  ShortsListNotifier(super.ref);

  @override
  Video _fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> _fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('category', 'shorts'),
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }
}

final shortsListProvider = StateNotifierProvider<ShortsListNotifier, PaginationState<Video>>((ref) {
  return ShortsListNotifier(ref);
});

// Notifier for ONLY NORMAL VIDEOS (Paginated)
class VideosListNotifier extends PaginatedListNotifier<Video> {
  VideosListNotifier(super.ref);

  @override
  Video _fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> _fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.notEqual('category', 'shorts'),
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }
}

final videosListProvider = StateNotifierProvider<VideosListNotifier, PaginationState<Video>>((ref) {
  return VideosListNotifier(ref);
});


// Notifier for "link" collections (Likes, History, Watch Later)
class PaginatedLinkNotifier extends PaginatedListNotifier<Document> {
  PaginatedLinkNotifier(super.ref, {required this.collectionId});
  
  final String collectionId;

  @override
  Document _fromDocument(Document doc) => doc;

  @override
  Future<List<Document>> _fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];

    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: collectionId,
      queries: [
        Query.equal('userId', user.$id),
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }
}

final paginatedLikedVideosProvider = StateNotifierProvider<PaginatedLinkNotifier, PaginationState<Document>>((ref) {
  return PaginatedLinkNotifier(ref, collectionId: AppwriteClient.collectionIdLikes);
});

final paginatedHistoryProvider = StateNotifierProvider<PaginatedLinkNotifier, PaginationState<Document>>((ref) {
  return PaginatedLinkNotifier(ref, collectionId: AppwriteClient.collectionIdHistory);
});

final paginatedWatchLaterProvider = StateNotifierProvider<PaginatedLinkNotifier, PaginationState<Document>>((ref) {
  return PaginatedLinkNotifier(ref, collectionId: AppwriteClient.collectionIdWatchLater);
});

// ---
// --- NEW: PAGINATED PROVIDER FOR FOLLOWING FEED
// ---

class PaginatedFollowingNotifier extends PaginatedListNotifier<Video> {
  PaginatedFollowingNotifier(super.ref);

  List<String>? _followingIds;

  // Helper to get the list of followed IDs *once*
  Future<List<String>> _getFollowingIds() async {
    if (_followingIds != null) return _followingIds!;

    final currentUserId = ref.read(authProvider).user?.$id;
    if (currentUserId == null) return [];

    final followingResponse = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdSubscriptions,
      queries: [
        Query.equal('followerId', currentUserId),
        Query.limit(5000) // Max users a person can follow
      ],
    );
    
    _followingIds = followingResponse.documents
        .map((doc) => doc.data['followingId'] as String)
        .toList();
    
    return _followingIds!;
  }

  @override
  Video _fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> _fetchPage(List<String> queries) async {
    final followingIds = await _getFollowingIds();
    if (followingIds.isEmpty) return [];

    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('userId', followingIds), // Filter by followed users
        Query.orderDesc('\$createdAt'),
        ...queries, // This includes limit() and cursorAfter()
      ],
    );
    return response.documents;
  }
}

final paginatedFollowingProvider = StateNotifierProvider<PaginatedFollowingNotifier, PaginationState<Video>>((ref) {
  return PaginatedFollowingNotifier(ref);
});

// ---
// --- END: NEW FOLLOWING PROVIDER
// ---


// --- OTHER PROVIDERS ---

final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  final databases = ref.watch(databasesProvider);
  final document = await databases.getDocument(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    documentId: videoId,
  );
  return Video.fromAppwrite(document);
});

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

// Base function (BUGGY - kept for old providers)
Future<List<Video>> _getVideosFromLinkCollection({
  required Ref ref,
  required String collectionId,
  required String userId,
  required String videoIdField,
}) async {
  final databases = ref.watch(databasesProvider);
  final linkDocsResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: collectionId,
    queries: [
      Query.equal('userId', userId),
      Query.orderDesc('\$createdAt'),
    ],
  );
  final videoIds = linkDocsResponse.documents
      .map((doc) => doc.data[videoIdField] as String?)
      .where((id) => id != null)
      .toSet()
      .toList();
  if (videoIds.isEmpty) {
    return [];
  }
  final videoResponse = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('\$id', videoIds),
    ],
  );
  return videoResponse.documents.map((doc) => Video.fromAppwrite(doc)).toList();
}

// OLD, BUGGY providers (kept for reference, but new pages don't use them)
final likedVideosProvider = FutureProvider<List<Video>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  return _getVideosFromLinkCollection(
    ref: ref,
    collectionId: AppwriteClient.collectionIdLikes,
    userId: user.$id,
    videoIdField: 'videoId',
  );
});
final watchLaterProvider = FutureProvider<List<Video>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  return _getVideosFromLinkCollection(
    ref: ref,
    collectionId: AppwriteClient.collectionIdWatchLater,
    userId: user.$id,
    videoIdField: 'videoId',
  );
});
final historyProvider = FutureProvider<List<Video>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  return _getVideosFromLinkCollection(
    ref: ref,
    collectionId: AppwriteClient.collectionIdHistory,
    userId: user.$id,
    videoIdField: 'videoId',
  );
});

// Suggested Videos Provider
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
  return allVideos.where((v) => v.id != currentVideoId).toList();
});

// OLD Following Videos Provider (BUGGY)
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