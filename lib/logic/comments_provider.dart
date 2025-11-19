// lib/logic/comments_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

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
          Query.equal('parent_id', null), 
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

  // Load More Comments
  Future<void> loadMore(String videoId) async {
    if (state.isLoading || !state.hasMore || state.lastId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await AppwriteClient.databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        queries: [
          Query.equal('videoId', videoId),
          Query.equal('parent_id', null),
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

  Future<void> postComment({required String videoId, required String content, String? parentId}) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception("Login required");

    final newComment = await AppwriteClient.databases.createDocument(
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
        Permission.read(Role.any()),
        Permission.update(Role.user(user.$id)),
        Permission.delete(Role.user(user.$id)),
      ]
    );

    if (parentId == null) {
      state = state.copyWith(comments: [newComment, ...state.comments]);
    } else {
      ref.invalidate(repliesProvider(parentId));
    }
  }
}

final commentsProvider = StateNotifierProvider<CommentsNotifier, CommentsState>((ref) {
  return CommentsNotifier(ref);
});

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