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
    
    // Prevent double loading
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
}