// lib/logic/following_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart'; // Using PaginationState

final followingListProvider = StateNotifierProvider<FollowingListNotifier, PaginationState<Document>>((ref) {
  return FollowingListNotifier(ref);
});

class FollowingListNotifier extends StateNotifier<PaginationState<Document>> {
  final Ref ref;
  final Databases _db = AppwriteClient.databases;

  FollowingListNotifier(this.ref) : super(PaginationState<Document>());

  Future<void> fetchFirstBatch() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    
    if (state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdSubscriptions, 
        queries: [
          Query.equal('followerId', user.$id),
          Query.limit(20),
          Query.orderDesc('\$createdAt'),
        ]
      );

      state = state.copyWith(
        items: response.documents,
        isLoadingMore: false,
        hasMore: response.documents.length == 20,
      );
    } catch (e) {
      print("Error fetching following list: $e");
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // FIX: Added Pagination Support
  Future<void> fetchNextBatch() async {
    final user = ref.read(authProvider).user;
    if (user == null || !state.hasMore || state.isLoadingMore || state.items.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final lastId = state.items.last.$id;

      final response = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdSubscriptions,
        queries: [
          Query.equal('followerId', user.$id),
          Query.limit(20),
          Query.orderDesc('\$createdAt'),
          Query.cursorAfter(lastId),
        ],
      );

      state = state.copyWith(
        items: [...state.items, ...response.documents],
        isLoadingMore: false,
        hasMore: response.documents.length == 20,
      );
    } catch (e) {
      print("Error fetching more users: $e");
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // FIX: Helper to remove item instantly from UI
  void removeUserLocally(String followingId) {
    final updatedItems = state.items.where((doc) => doc.data['followingId'] != followingId).toList();
    state = state.copyWith(items: updatedItems);
  }
}