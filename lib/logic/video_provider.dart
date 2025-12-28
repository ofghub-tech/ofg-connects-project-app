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

// --- 2. GENERIC PAGINATED NOTIFIER ---
abstract class PaginatedListNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginatedListNotifier(this.ref) : super(PaginationState<T>());

  final Ref ref;
  final int _limit = 10; 
  String? _lastId;

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

  Future<void> refresh() async {
    _lastId = null; 
    try {
      final documents = await fetchPage([Query.limit(_limit)]);
      final newItems = documents.map(fromDocument).toList();
      _lastId = documents.isNotEmpty ? documents.last.$id : null;
      state = state.copyWith(items: newItems, isLoadingMore: false, hasMore: newItems.length == _limit);
    } catch (e) {
      print("Error refreshing: $e");
    }
  }

  Future<void> fetchMore() async {
    if (state.isLoadingMore || !state.hasMore || _lastId == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final documents = await fetchPage([Query.limit(_limit), Query.cursorAfter(_lastId!)]);
      final newItems = documents.map(fromDocument).toList();
      _lastId = documents.isNotEmpty ? documents.last.$id : null;
      state = state.copyWith(items: [...state.items, ...newItems], isLoadingMore: false, hasMore: newItems.length == _limit);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      print("Error fetching more: $e");
    }
  }
}

// --- 3. SPECIFIC PROVIDERS ---
final databasesProvider = Provider((ref) => AppwriteClient.databases);

class VideosListNotifier extends PaginatedListNotifier<Video> {
  VideosListNotifier(super.ref) { fetchFirstBatch(); }
  @override Video fromDocument(Document doc) => Video.fromAppwrite(doc);
  @override Future<List<Document>> fetchPage(List<String> queries) async {
    return (await ref.read(databasesProvider).listDocuments(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, queries: [
      Query.notEqual('category', 'shorts'), Query.equal('adminStatus', 'approved'), Query.orderDesc('\$createdAt'), ...queries])).documents;
  }
}
final videosListProvider = StateNotifierProvider<VideosListNotifier, PaginationState<Video>>((ref) => VideosListNotifier(ref));

class UserLongVideosNotifier extends PaginatedListNotifier<Video> {
  UserLongVideosNotifier(super.ref);
  @override Video fromDocument(Document doc) => Video.fromAppwrite(doc);
  @override Future<List<Document>> fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];
    return (await ref.read(databasesProvider).listDocuments(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, queries: [
      Query.equal('userId', user.$id), Query.notEqual('category', 'shorts'), Query.orderDesc('\$createdAt'), ...queries])).documents;
  }
}
final paginatedUserLongVideosProvider = StateNotifierProvider<UserLongVideosNotifier, PaginationState<Video>>((ref) => UserLongVideosNotifier(ref));

class UserShortsNotifier extends PaginatedListNotifier<Video> {
  UserShortsNotifier(super.ref);
  @override Video fromDocument(Document doc) => Video.fromAppwrite(doc);
  @override Future<List<Document>> fetchPage(List<String> queries) async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];
    return (await ref.read(databasesProvider).listDocuments(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, queries: [
      Query.equal('userId', user.$id), Query.equal('category', 'shorts'), Query.orderDesc('\$createdAt'), ...queries])).documents;
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
    return (await ref.read(databasesProvider).listDocuments(databaseId: AppwriteClient.databaseId, collectionId: collectionId, queries: [
      Query.equal('userId', user.$id), Query.orderDesc('\$createdAt'), ...queries])).documents;
  }
}
// REMOVED: paginatedLikedVideosProvider
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