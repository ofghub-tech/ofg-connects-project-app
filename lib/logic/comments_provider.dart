// lib/logic/comments_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:appwrite/models.dart';

final commentsProvider = StateNotifierProvider<CommentsNotifier, AsyncValue<List<Document>>>((ref) {
  return CommentsNotifier(ref);
});

// --- NEW PROVIDER ---
// Fetches replies for a specific parent comment ID
final repliesProvider = FutureProvider.family<List<Document>, String>((ref, parentId) async {
  try {
    final response = await AppwriteClient.databases.listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdComments,
      queries: [
        Query.equal('parent_id', parentId),
        Query.orderAsc('\$createdAt'), // Show oldest replies first
      ],
    );
    return response.documents;
  } catch (e) {
    print('Error fetching replies: $e');
    return [];
  }
});
// --- END NEW PROVIDER ---


class CommentsNotifier extends StateNotifier<AsyncValue<List<Document>>> {
  CommentsNotifier(this.ref) : super(const AsyncValue.loading());
  
  final Ref ref;

  Future<void> loadComments(String videoId) async {
    try {
      state = const AsyncValue.loading();
      final response = await AppwriteClient.databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        queries: [
          Query.equal('videoId', videoId),
          Query.equal('parent_id', null), // <-- THIS IS THE FIX (fetches top-level only)
          Query.orderDesc('\$createdAt'),
        ],
      );
      // We store the raw documents. 
      // Note: Logic for nesting (replies) handles best in the UI builder 
      // or a separate transformer, similar to the web app's `useMemo`.
      state = AsyncValue.data(response.documents);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> postComment({required String videoId, required String content, String? parentId}) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception("Login required");

    try {
      final newComment = await AppwriteClient.databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        documentId: ID.unique(),
        data: {
          'content': content,
          'videoId': videoId,
          'username': user.name,
          'userId': user.$id,
          'parent_id': parentId, // Nullable for top-level comments
          'createdAt': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ]
      );
      
      // --- UPDATE LOGIC ---
      if (parentId == null) {
        // This is a new TOP-LEVEL comment, add it to the top of the main list
        state.whenData((comments) {
          state = AsyncValue.data([newComment, ...comments]);
        });
      } else {
        // This is a REPLY, invalidate the repliesProvider so it refetches
        ref.invalidate(repliesProvider(parentId));
      }
      // --- END UPDATE LOGIC ---
      
    } catch (e) {
      rethrow;
    }
  }
}