// lib/logic/comments_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:state_notifier/state_notifier.dart'; // <--- ADDED
import 'package:ofgconnects_mobile/logic/video_provider.dart'; // Important for refreshing video details

// 1. State Class
class CommentsState {
  final List<Document> comments;
  final bool isLoading;
  final String? lastId;
  final bool hasMore;

  CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.lastId,
    this.hasMore = true,
  });

  CommentsState copyWith({
    List<Document>? comments,
    bool? isLoading,
    String? lastId,
    bool? hasMore,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      lastId: lastId ?? this.lastId,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// 2. Notifier Class
class CommentsNotifier extends StateNotifier<CommentsState> {
  CommentsNotifier(this.ref) : super(CommentsState());
  final Ref ref;
  final int _limit = 20;

  // Load Initial Comments
  Future<void> loadComments(String videoId) async {
    state = CommentsState(isLoading: true); 
    try {
      final response = await AppwriteClient.databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        queries: [
          Query.equal('videoId', videoId),
          Query.isNull('parent_id'), // Only fetch top-level comments
          Query.orderDesc('\$createdAt'),
          Query.limit(_limit),
        ],
      );
      
      state = state.copyWith(
        comments: response.documents,
        isLoading: false,
        lastId: response.documents.isNotEmpty ? response.documents.last.$id : null,
        hasMore: response.documents.length == _limit,
      );
    } catch (e) {
      print("Error loading comments: $e");
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }

  // Load More Comments (Pagination)
  Future<void> loadMore(String videoId) async {
    if (state.isLoading || !state.hasMore || state.lastId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await AppwriteClient.databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        queries: [
          Query.equal('videoId', videoId),
          Query.isNull('parent_id'),
          Query.orderDesc('\$createdAt'),
          Query.limit(_limit),
          Query.cursorAfter(state.lastId!),
        ],
      );

      state = state.copyWith(
        comments: [...state.comments, ...response.documents],
        isLoading: false,
        lastId: response.documents.isNotEmpty ? response.documents.last.$id : null,
        hasMore: response.documents.length == _limit,
      );
    } catch (e) {
       state = state.copyWith(isLoading: false, hasMore: false);
    }
  }

  // Post Comment
  Future<void> postComment({required String videoId, required String content, String? parentId}) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception("Login required to comment");

    final databases = AppwriteClient.databases;

    try {
      // A. Create Comment in DB
      final newComment = await databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        documentId: ID.unique(),
        data: {
          'content': content,
          'videoId': videoId,
          'username': user.name,
          'userId': user.$id,
          'parent_id': parentId,
          'createdAt': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.any()), // Visible to all
          Permission.update(Role.user(user.$id)), // Editable by owner
          Permission.delete(Role.user(user.$id)), // Deletable by owner
        ]
      );

      // B. Update local state (Optimistic UI)
      // If it's a top-level comment, add it to the top of the list immediately
      if (parentId == null) {
        state = state.copyWith(comments: [newComment, ...state.comments]);
        
        // C. Increment Comment Count on Video
        try {
           // Fetch fresh video data to be safe
           final videoDoc = await databases.getDocument(
             databaseId: AppwriteClient.databaseId, 
             collectionId: AppwriteClient.collectionIdVideos, 
             documentId: videoId
           );
           
           final currentCount = videoDoc.data['commentCount'] ?? 0;
           
           await databases.updateDocument(
             databaseId: AppwriteClient.databaseId,
             collectionId: AppwriteClient.collectionIdVideos,
             documentId: videoId,
             data: { 'commentCount': currentCount + 1 }
           );
           
           // Refresh video details provider so the "Comment Icon" count updates in UI
           ref.invalidate(videoDetailsProvider(videoId));
           
        } catch (e) {
          print("Failed to update comment count: $e");
        }
      } else {
        // If reply, invalidate the specific replies provider
        ref.invalidate(repliesProvider(parentId));
      }
    } catch (e) {
      print("Error posting comment: $e");
      rethrow;
    }
  }
}

// 3. Providers
final commentsProvider = StateNotifierProvider<CommentsNotifier, CommentsState>((ref) {
  return CommentsNotifier(ref);
});

// Provider to fetch replies for a specific comment
final repliesProvider = FutureProvider.family<List<Document>, String>((ref, parentId) async {
  try {
    final response = await AppwriteClient.databases.listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdComments,
      queries: [
        Query.equal('parent_id', parentId),
        Query.orderAsc('\$createdAt'),
      ],
    );
    return response.documents;
  } catch (e) {
    return [];
  }
});