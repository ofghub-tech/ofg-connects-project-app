// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';

final interactionProvider = Provider((ref) => InteractionLogic(ref));

// Provider to check if a specific video is liked
final isLikedProvider = FutureProvider.family<bool, String>((ref, videoId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  return ref.watch(interactionProvider).checkIfLiked(videoId);
});

// Provider to check if a video is saved (Watch Later)
final isSavedProvider = FutureProvider.family<bool, String>((ref, videoId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  return ref.watch(interactionProvider).isVideoSaved(videoId);
});

class InteractionLogic {
  final Ref ref;
  final Databases _db = AppwriteClient.databases;
  
  InteractionLogic(this.ref);

  // --- 1. LIKE LOGIC ---
  
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
    } catch (e) {
      return false;
    }
  }

  // FIXED: Now only takes videoId. It fetches the real count from DB to avoid UI desync.
  Future<void> toggleLike(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception("User not logged in");

    try {
      // A. Check if already liked
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ],
      );

      // B. Get Fresh Video Data
      final videoDoc = await _db.getDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
      );
      int currentCount = videoDoc.data['likeCount'] ?? 0;

      if (check.total > 0) {
        // --- UNLIKE ---
        final docId = check.documents.first.$id;
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: docId,
        );
        
        // Decrement safely
        final newCount = currentCount > 0 ? currentCount - 1 : 0;
        await _updateVideoCount(videoId, 'likeCount', newCount);

      } else {
        // --- LIKE ---
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            'type': 'video',
            'createdAt': DateTime.now().toIso8601String(),
          },
          permissions: [
            Permission.read(Role.any()),
            Permission.write(Role.user(user.$id)),
          ]
        );

        // Increment
        await _updateVideoCount(videoId, 'likeCount', currentCount + 1);
      }
      
      // C. Refresh UI
      ref.invalidate(videoDetailsProvider(videoId));
      ref.invalidate(isLikedProvider(videoId));

    } catch (e) {
      print("Like Error: $e");
      rethrow;
    }
  }

  // --- 2. WATCH LATER / SAVE LOGIC ---

  // FIXED: Renamed to match what WatchPage was looking for
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
        // Unsave
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: check.documents.first.$id,
        );
      } else {
        // Save
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            'createdAt': DateTime.now().toIso8601String(),
          },
           permissions: [
            Permission.read(Role.user(user.$id)),
            Permission.write(Role.user(user.$id)),
          ]
        );
      }
      // Force refresh the provider so UI updates
      ref.invalidate(isSavedProvider(videoId)); 
    } catch (e) {
      print("Save Error: $e");
    }
  }

  // --- 3. HISTORY LOGIC ---
  
  Future<void> logVideoView(String videoId, int currentViews) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
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
        // Update existing view time
        await _db.updateDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: check.documents.first.$id,
          data: {'createdAt': DateTime.now().toIso8601String()},
        );
      } else {
        // New View
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            'createdAt': DateTime.now().toIso8601String(),
          },
          permissions: [
            Permission.read(Role.user(user.$id)),
            Permission.write(Role.user(user.$id)),
          ]
        );
        // Increment View Count
        await _updateVideoCount(videoId, 'view_count', currentViews + 1);
      } 
    } catch (e) {
      print("History Log Error: $e");
    }
  }

  Future<void> _updateVideoCount(String videoId, String field, int value) async {
    try {
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: { field: value },
      );
    } catch (e) {
      print("Failed to update count: $e");
    }
  }
}