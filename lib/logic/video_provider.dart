// lib/logic/video_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/logic/auth_provider.dart';

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

// --- 2. ROBUST PAGINATED NOTIFIER ---
abstract class PaginatedListNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginatedListNotifier(this.ref) : super(PaginationState<T>());

  final Ref ref;
  final int _limit = 15; // Increased limit slightly to reduce network chatter
  String? _lastId;

  // Abstract methods to be implemented by children
  Future<List<Document>> fetchPage(List<String> queries);
  T fromDocument(Document doc);
  
  // Override this to implement specific filtering (e.g. blocked users)
  bool shouldFilter(T item) => false;

  // --- SAFE GUARD: MAX RECURSION ---
  // Prevents infinite loops if the database is 100% full of blocked content
  int _recursionDepth = 0;
  final int _maxRecursion = 5; 

  Future<void> fetchFirstBatch() async {
    if (state.items.isNotEmpty) return;
    
    state = state.copyWith(isLoadingMore: true, hasMore: true);
    _lastId = null;
    _recursionDepth = 0; 
    
    await _fetchRecursive(isFirstLoad: true);
  }

  Future<void> refresh() async {
    _lastId = null;
    _recursionDepth = 0;
    
    // Pass isFirstLoad=true to replace the list entirely
    await _fetchRecursive(isFirstLoad: true);
  }

  Future<void> fetchMore() async {
    // Debounce: Don't fetch if already fetching or no more items
    if (state.isLoadingMore || !state.hasMore || _lastId == null) return;
    
    state = state.copyWith(isLoadingMore: true);
    _recursionDepth = 0;

    await _fetchRecursive(isFirstLoad: false);
  }

  /// Internal Helper: Handles "Hollow Page" logic safely
  Future<void> _fetchRecursive({required bool isFirstLoad}) async {
    try {
      // 1. Prepare Queries
      final List<String> queries = [Query.limit(_limit)];
      if (_lastId != null) {
        queries.add(Query.cursorAfter(_lastId!));
      }

      // 2. Network Call
      final documents = await fetchPage(queries);

      // 3. Filter Logic
      final List<T> validItems = [];
      for (var doc in documents) {
        final item = fromDocument(doc);
        if (!shouldFilter(item)) {
          validItems.add(item);
        }
      }

      // 4. Update Cursor (Even if filtered, we moved past these docs)
      _lastId = documents.isNotEmpty ? documents.last.$id : null;
      
      // 5. Determine if Server has more data
      // Note: If we got fewer docs than limit, server is exhausted.
      final bool serverHasMore = documents.length == _limit;

      // --- CRITICAL LOGIC: HOLLOW PAGE HANDLING ---
      // If we got data from server, but filtered EVERYTHING out (validItems is empty),
      // we MUST fetch the next page immediately, unless server is empty.
      if (validItems.isEmpty && serverHasMore) {
        if (_recursionDepth < _maxRecursion) {
          _recursionDepth++;
          print("⚠️ Hollow Page detected (All items filtered). Fetching next batch internally... (Depth: $_recursionDepth)");
          await _fetchRecursive(isFirstLoad: isFirstLoad); // RECURSIVE CALL
          return;
        } else {
           print("🛑 Max recursion reached. Stopping fetch to save battery.");
           // Stop loading, keep existing data.
           state = state.copyWith(isLoadingMore: false, hasMore: true); 
           return;
        }
      }

      // 6. Update State
      if (isFirstLoad) {
        state = state.copyWith(
          items: validItems,
          isLoadingMore: false,
          hasMore: serverHasMore,
        );
      } else {
        state = state.copyWith(
          items: [...state.items, ...validItems],
          isLoadingMore: false,
          hasMore: serverHasMore,
        );
      }

    } catch (e) {
      print("Error in pagination: $e");
      // On error, stop loading but preserve existing items
      state = state.copyWith(isLoadingMore: false, hasMore: false);
    }
  }
}

// --- 3. SPECIFIC PROVIDERS ---
final databasesProvider = Provider((ref) => AppwriteClient.databases);

class VideosListNotifier extends PaginatedListNotifier<Video> {
  VideosListNotifier(super.ref) { fetchFirstBatch(); }
  
  @override Video fromDocument(Document doc) => Video.fromAppwrite(doc);
  
  @override
  bool shouldFilter(Video video) {
    final user = ref.read(authProvider).user;
    if (user == null) return false;

    // Use safe access "?" to avoid crashes if keys don't exist
    final prefs = user.prefs.data;
    
    // Check Blocked Creators 
    final blockedCreators = (prefs['blockedCreators'] as List<dynamic>?)?.cast<String>() ?? [];
    if (blockedCreators.contains(video.creatorId)) return true; 
    
    // Check Ignored Videos
    final ignoredVideos = (prefs['ignoredVideos'] as List<dynamic>?)?.cast<String>() ?? [];
    if (ignoredVideos.contains(video.id)) return true;

    return false;
  }

  @override Future<List<Document>> fetchPage(List<String> queries) async {
    return (await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId, 
      collectionId: AppwriteClient.collectionIdVideos, 
      queries: [
        Query.notEqual('category', 'shorts'), 
        Query.equal('adminStatus', 'approved'), 
        Query.orderDesc('\$createdAt'), 
        ...queries
      ]
    )).documents;
  }
}
final videosListProvider = StateNotifierProvider<VideosListNotifier, PaginationState<Video>>((ref) => VideosListNotifier(ref));

class UserLongVideosNotifier extends PaginatedListNotifier<Video> {
  UserLongVideosNotifier(super.ref);
  @override Video fromDocument(Document doc) => Video.fromAppwrite(doc);
  @override Future<List<Document>> fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];
    return (await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId, 
      collectionId: AppwriteClient.collectionIdVideos, 
      queries: [
        Query.equal('userId', user.$id), 
        Query.notEqual('category', 'shorts'), 
        Query.orderDesc('\$createdAt'), 
        ...queries
      ]
    )).documents;
  }
}
final paginatedUserLongVideosProvider = StateNotifierProvider<UserLongVideosNotifier, PaginationState<Video>>((ref) => UserLongVideosNotifier(ref));

class UserShortsNotifier extends PaginatedListNotifier<Video> {
  UserShortsNotifier(super.ref);
  @override Video fromDocument(Document doc) => Video.fromAppwrite(doc);
  @override Future<List<Document>> fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];
    return (await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId, 
      collectionId: AppwriteClient.collectionIdVideos, 
      queries: [
        Query.equal('userId', user.$id), 
        Query.equal('category', 'shorts'), 
        Query.orderDesc('\$createdAt'), 
        ...queries
      ]
    )).documents;
  }
}
final paginatedUserShortsProvider = StateNotifierProvider<UserShortsNotifier, PaginationState<Video>>((ref) => UserShortsNotifier(ref));

class PaginatedLinkNotifier extends PaginatedListNotifier<Document> {
  PaginatedLinkNotifier(super.ref, {required this.collectionId}) { fetchFirstBatch(); }
  final String collectionId;
  @override Document fromDocument(Document doc) => doc;
  @override Future<List<Document>> fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];
    return (await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId, 
      collectionId: collectionId, 
      queries: [
        Query.equal('userId', user.$id), 
        Query.orderDesc('\$createdAt'), 
        ...queries
      ]
    )).documents;
  }
}

final paginatedHistoryProvider = StateNotifierProvider<PaginatedLinkNotifier, PaginationState<Document>>((ref) => PaginatedLinkNotifier(ref, collectionId: AppwriteClient.collectionIdHistory));
final paginatedWatchLaterProvider = StateNotifierProvider<PaginatedLinkNotifier, PaginationState<Document>>((ref) => PaginatedLinkNotifier(ref, collectionId: AppwriteClient.collectionIdWatchLater));

final videoDetailsProvider = FutureProvider.family<Video, String>((ref, videoId) async {
  final doc = await ref.watch(databasesProvider).getDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: videoId);
  return Video.fromAppwrite(doc);
});

final suggestedVideosProvider = FutureProvider.family<List<Video>, String>((ref, currentVideoId) async {
  final response = await ref.watch(databasesProvider).listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('adminStatus', 'approved'),
      Query.notEqual('category', 'shorts'), 
      Query.limit(10),
      Query.orderDesc('\$createdAt')
    ]
  );
  return response.documents.map((d) => Video.fromAppwrite(d)).where((v) => v.id != currentVideoId).toList();
});