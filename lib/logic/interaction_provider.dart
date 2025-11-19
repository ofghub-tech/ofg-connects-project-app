// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
// --- FIX IS HERE: Hide the old historyProvider ---
import 'package:ofgconnects_mobile/logic/video_provider.dart' hide historyProvider; 
import 'package:ofgconnects_mobile/logic/history_provider.dart';

final interactionProvider = Provider((ref) => InteractionLogic(ref));

final isLikedProvider = FutureProvider.family<bool, String>((ref, videoId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  return ref.read(interactionProvider).checkIfLiked(videoId);
});

final isSavedProvider = FutureProvider.family<bool, String>((ref, videoId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  return ref.read(interactionProvider).isVideoSaved(videoId);
});

class InteractionLogic {
  final Ref ref;
  final Databases _db = AppwriteClient.databases;
  
  InteractionLogic(this.ref);

  // --- HISTORY LOGIC ---
  
  Future<void> logVideoView(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      // 1. Check if User already watched this
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1)
        ],
      );

      if (check.total > 0) {
        // ALREADY WATCHED: Delete old, Create new (to bump timestamp)
        try {
          await _db.deleteDocument(
            databaseId: AppwriteClient.databaseId,
            collectionId: AppwriteClient.collectionIdHistory,
            documentId: check.documents.first.$id,
          );
        } catch (e) {
          print("Error deleting old history: $e");
        }

        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            // No 'createdAt' needed, Appwrite handles $createdAt automatically
          },
          permissions: [
             Permission.read(Role.user(user.$id)),
             Permission.write(Role.user(user.$id)),
          ]
        );
        
      } else {
        // NEW VIEW
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
          },
          permissions: [
             Permission.read(Role.user(user.$id)),
             Permission.write(Role.user(user.$id)),
          ]
        );

        await _incrementViewCount(videoId);
      } 
      
      // Refresh UI lists
      ref.invalidate(historyProvider); 

    } catch (e) {
      print("History Log Error: $e");
    }
  }

  Future<void> _incrementViewCount(String videoId) async {
    try {
      final videoDoc = await _db.getDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: videoId
      );
      
      int currentViews = videoDoc.data['view_count'] ?? 0;
      
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: { 'view_count': currentViews + 1 },
      );
      
      ref.invalidate(videoDetailsProvider(videoId));
    } catch (e) {
       print("Failed to increment view count: $e");
    }
  }

  // --- LIKE LOGIC ---
  Future<bool> checkIfLiked(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return false;
    try {
      final response = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1), 
        ]
      );
      return response.total > 0;
    } catch (e) { return false; }
  }

  Future<void> toggleLike(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ],
      );

      final videoDoc = await _db.getDocument(
         databaseId: AppwriteClient.databaseId,
         collectionId: AppwriteClient.collectionIdVideos,
         documentId: videoId
      );
      int currentLikes = videoDoc.data['likeCount'] ?? 0;

      if (check.total > 0) {
        // Unlike
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: check.documents.first.$id,
        );
        await _updateVideoField(videoId, 'likeCount', (currentLikes > 0 ? currentLikes - 1 : 0));
      } else {
        // Like
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            'type': 'video',
          },
          permissions: [
             Permission.read(Role.any()),
             Permission.write(Role.user(user.$id)),
          ]
        );
        await _updateVideoField(videoId, 'likeCount', currentLikes + 1);
      }
      ref.invalidate(isLikedProvider(videoId));
      ref.invalidate(videoDetailsProvider(videoId));
      ref.invalidate(paginatedLikedVideosProvider);
    } catch (e) {
      print("Like Error: $e");
    }
  }

  // --- WATCH LATER LOGIC ---
  Future<bool> isVideoSaved(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return false;
    try {
      final response = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ]
      );
      return response.total > 0;
    } catch (_) { return false; }
  }

  Future<void> toggleWatchLater(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ],
      );

      if (check.total > 0) {
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: check.documents.first.$id,
        );
      } else {
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
          },
           permissions: [
            Permission.read(Role.user(user.$id)),
            Permission.write(Role.user(user.$id)),
          ]
        );
      }
      ref.invalidate(isSavedProvider(videoId));
      ref.invalidate(paginatedWatchLaterProvider);
    } catch (e) {
      print("Save Error: $e");
    }
  }

  Future<void> _updateVideoField(String videoId, String field, int value) async {
     try {
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: { field: value },
      );
    } catch (e) { print("Failed to update video stats: $e"); }
  }
}