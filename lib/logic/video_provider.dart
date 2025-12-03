import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart'; 
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// --- 1. GENERIC PAGINATION STATE ---
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

// --- 2. GENERIC PAGINATED NOTIFIER ---
abstract class PaginatedListNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginatedListNotifier(this.ref) : super(PaginationState<T>());

  final Ref ref;
  final int _limit = 10; 
  String? _lastId;

  // PUBLIC METHODS
  Future<List<Document>> fetchPage(List<String> queries);
  T fromDocument(Document doc);

  Future<void> fetchFirstBatch() async {
    if (state.items.isNotEmpty) return;

    state = state.copyWith(isLoadingMore: true, hasMore: true);
    _lastId = null; 

    try {
      final documents = await fetchPage([Query.limit(_limit)]);
      
      final newItems = documents.map(fromDocument).toList();
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
      final documents = await fetchPage([
        Query.limit(_limit),
        Query.cursorAfter(_lastId!), 
      ]);

      final newItems = documents.map(fromDocument).toList();
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

// --- 3. SPECIFIC PROVIDERS ---

final databasesProvider = Provider((ref) => AppwriteClient.databases);

// A. SHORTS NOTIFIER
class ShortsListNotifier extends PaginatedListNotifier<Video> {
  ShortsListNotifier(super.ref);

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  Future<void> init(String? startWithVideoId) async {
    if (state.items.isNotEmpty) return;

    if (startWithVideoId != null) {
      try {
        final doc = await ref.read(databasesProvider).getDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdVideos,
          documentId: startWithVideoId,
        );
        final video = Video.fromAppwrite(doc);
        
        state = PaginationState(
          items: [video],
          isLoadingMore: true, 
          hasMore: true,
        );
        
        await fetchFirstBatch(); 
      } catch (e) {
        print("Error fetching deep linked short: $e");
        fetchFirstBatch();
      }
    } else {
      fetchFirstBatch();
    }
  }

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('category', 'shorts'),
        Query.equal('adminStatus', 'approved'), // --- ADDED: Filter Approved ---
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

// B. NORMAL VIDEOS NOTIFIER
class VideosListNotifier extends PaginatedListNotifier<Video> {
  VideosListNotifier(super.ref) {
    fetchFirstBatch();
  }

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.notEqual('category', 'shorts'),
        Query.equal('adminStatus', 'approved'), // --- ADDED: Filter Approved ---
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

// C. USER VIDEOS NOTIFIER (My Space - Current User)
class UserVideosNotifier extends PaginatedListNotifier<Video> {
  UserVideosNotifier(super.ref);

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];

    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('userId', user.$id),
        // Note: We DO NOT filter by 'approved' here so users can see their own pending uploads.
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }
}

final paginatedUserVideosProvider = StateNotifierProvider<UserVideosNotifier, PaginationState<Video>>((ref) {
  return UserVideosNotifier(ref);
});

// D. LINK NOTIFIERS (Likes, History, Watch Later)
class PaginatedLinkNotifier extends PaginatedListNotifier<Document> {
  PaginatedLinkNotifier(super.ref, {required this.collectionId}) {
    fetchFirstBatch();
  }
  
  final String collectionId;

  @override
  Document fromDocument(Document doc) => doc;

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
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

// E. FOLLOWING FEED NOTIFIER
class PaginatedFollowingNotifier extends PaginatedListNotifier<Video> {
  PaginatedFollowingNotifier(super.ref) {
    fetchFirstBatch();
  }

  List<String>? _followingIds;

  Future<List<String>> _getFollowingIds() async {
    if (_followingIds != null) return _followingIds!;

    final currentUserId = ref.read(authProvider).user?.$id;
    if (currentUserId == null) return [];

    try {
      final followingResponse = await ref.read(databasesProvider).listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdSubscriptions,
        queries: [
          Query.equal('followerId', currentUserId),
          Query.limit(100)
        ],
      );
      
      _followingIds = followingResponse.documents
          .map((doc) => doc.data['followingId'] as String)
          .toList();
      
      return _followingIds!;
    } catch (e) {
      print("Error fetching following IDs: $e");
      return [];
    }
  }

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    final followingIds = await _getFollowingIds();
    if (followingIds.isEmpty) return [];

    final safeIds = followingIds.length > 100 
        ? followingIds.sublist(0, 100) 
        : followingIds;

    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('userId', safeIds),
        Query.equal('adminStatus', 'approved'), // --- ADDED: Filter Approved ---
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }
}

final paginatedFollowingProvider = StateNotifierProvider<PaginatedFollowingNotifier, PaginationState<Video>>((ref) {
  return PaginatedFollowingNotifier(ref);
});

// --- 4. SINGLE ITEM & HELPER PROVIDERS ---

final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  final databases = ref.watch(databasesProvider);
  final document = await databases.getDocument(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    documentId: videoId,
  );
  return Video.fromAppwrite(document);
});

final suggestedVideosProvider = FutureProvider.family<List<Video>, String>((ref, currentVideoId) async {
  final databases = ref.watch(databasesProvider);
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('adminStatus', 'approved'), // --- ADDED: Filter Approved ---
      Query.limit(10),
      Query.orderDesc('\$createdAt'),
    ],
  );
  final allVideos = response.documents.map((d) => Video.fromAppwrite(d)).toList();
  return allVideos.where((v) => v.id != currentVideoId).toList();
});

// Deprecated
final userVideosProvider = FutureProvider<List<Video>>((ref) async => []);
final likedVideosProvider = FutureProvider<List<Video>>((ref) async => []);
final watchLaterProvider = FutureProvider<List<Video>>((ref) async => []);
final historyProvider = FutureProvider<List<Video>>((ref) async => []);
final followingVideosProvider = FutureProvider<List<Video>>((ref) async => []);