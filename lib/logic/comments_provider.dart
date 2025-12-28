// lib/logic/comments_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// CORRECTION: Package name must match pubspec.yaml (ofgconnects)
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart';

class CommentsState {
  final List<Document> comments;
  final bool isLoading;
  final String? lastId;
  final bool hasMore;

  CommentsState({this.comments = const [], this.isLoading = false, this.lastId, this.hasMore = true});

  CommentsState copyWith({List<Document>? comments, bool? isLoading, String? lastId, bool? hasMore}) {
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

  Future<void> loadComments(String videoId) async {
    state = state.copyWith(isLoading: true, comments: []); 
    try {
      final response = await AppwriteClient.databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdComments,
        queries: [
          Query.equal('videoId', videoId),
          Query.isNull('parent_id'), 
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
      state = state.copyWith(isLoading: false, hasMore: false);
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
          'parent_id': parentId, // Matches appwrite.config.json
        },
      );

      if (parentId == null) {
        state = state.copyWith(comments: [newComment, ...state.comments]);
        _updateCommentCount(videoId, 1);
      } else {
        ref.invalidate(repliesProvider(parentId));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateCommentCount(String videoId, int delta) async {
    try {
      final doc = await AppwriteClient.databases.getDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: videoId
      );
      final current = doc.data['commentCount'] ?? 0;
      await AppwriteClient.databases.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: {'commentCount': current + delta},
      );
      ref.invalidate(videoDetailsProvider(videoId));
    } catch (_) {}
  }
}

final commentsProvider = StateNotifierProvider<CommentsNotifier, CommentsState>((ref) => CommentsNotifier(ref));

final repliesProvider = FutureProvider.family<List<Document>, String>((ref, parentId) async {
  final res = await AppwriteClient.databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdComments,
    queries: [Query.equal('parent_id', parentId), Query.orderAsc('\$createdAt')],
  );
  return res.documents;
});