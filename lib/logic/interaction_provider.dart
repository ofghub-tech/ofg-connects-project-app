// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
// --- ADD THIS IMPORT ---
import 'package:ofgconnects_mobile/logic/video_provider.dart';
// ---

// Provider just for logic functions, no complex state needed here
final interactionProvider = Provider((ref) => InteractionLogic(ref));

// --- ADD THIS NEW PROVIDER ---
// This provider checks if the current video is liked by the user
final isLikedProvider = FutureProvider.family<bool, String>((ref, videoId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;

  final logic = ref.watch(interactionProvider);
  return logic.isVideoLiked(videoId);
});
// ---

class InteractionLogic {
  final Ref ref;
  InteractionLogic(this.ref);

  final Databases _db = AppwriteClient.databases;

  // --- REPLICATES: logVideoView function from WatchPage.js ---
  Future<void> logVideoView(String videoId, int currentViewCount) async {
    final user = ref.read(authProvider).user;
    
    // 1. If no user, we can't track history
    if (user == null) return;

    try {
      // 2. Check if user has already seen this video
      final historyCheck = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ],
      );

      // 3. If history exists, STOP.
      if (historyCheck.total > 0) {
        return;
      }

      // 4. If NEW view: Create History Record
      await _db.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        documentId: ID.unique(),
        data: {
          'userId': user.$id,
          'videoId': videoId,
          // --- THIS IS THE FIX ---
          'createdAt': DateTime.now().toIso8601String(),
          // ---
        },
        permissions: [
          Permission.read(Role.user(user.$id)), 
          Permission.write(Role.user(user.$id))
        ]
      );

      // B. Increment View Count on Video Document
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: {
          'view_count': currentViewCount + 1,
        },
      );
      
    } catch (e) {
      print("Error logging view: $e");
    }
  }

  // --- REPLICATES: handleToggleSave function from WatchPage.js ---
  Future<bool> toggleWatchLater(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception("User must be logged in");

    try {
      // 1. Check if already saved
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
        // 2. EXISTS -> DELETE (Unsave)
        final docId = check.documents.first.$id;
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: docId,
        );
        return false; // Not saved anymore
      } else {
        // 3. DOES NOT EXIST -> CREATE (Save)
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            // --- THIS IS THE FIX ---
            'createdAt': DateTime.now().toIso8601String(),
            // ---
          },
          permissions: [
             Permission.read(Role.user(user.$id)), 
             Permission.write(Role.user(user.$id))
          ]
        );
        return true; // Now saved
      }
    } catch (e) {
      print("Error toggling watch later: $e");
      rethrow;
    }
  }
  
  // --- Helper to check initial save state ---
  Future<bool> isVideoSaved(String videoId) async {
     final user = ref.read(authProvider).user;
     if (user == null) return false;
     
     final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ],
      );
      return check.total > 0;
  }

  // --- 
  // --- NEW FUNCTIONS FOR LIKING ---
  // ---

  // Helper to check initial like state
  Future<bool> isVideoLiked(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return false;

    final check = await _db.listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdLikes, // Use likes collection
      queries: [
        Query.equal('userId', user.$id),
        Query.equal('videoId', videoId),
        Query.limit(1),
      ],
    );
    return check.total > 0;
  }

  // Main function to toggle a like
  Future<void> toggleLike(String videoId, int currentLikeCount) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception("User must be logged in");

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

      if (check.total > 0) {
        // --- VIDEO IS LIKED: UNLIKE IT ---
        final docId = check.documents.first.$id;

        // 1. Delete the like document
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: docId,
        );

        // 2. Decrement the likeCount in the videos collection
        await _db.updateDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdVideos,
          documentId: videoId,
          data: {
            'likeCount': currentLikeCount - 1, // Decrement
          },
        );
      } else {
        // --- VIDEO IS NOT LIKED: LIKE IT ---
        
        // 1. Create the like document
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'videoId': videoId,
            'type': 'video', // Based on your 'likes' table schema
          },
           permissions: [
             Permission.read(Role.user(user.$id)), 
             Permission.write(Role.user(user.$id))
          ]
        );

        // 2. Increment the likeCount in the videos collection
         await _db.updateDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdVideos,
          documentId: videoId,
          data: {
            'likeCount': currentLikeCount + 1, // Increment
          },
        );
      }

      // --- REFRESH PROVIDERS ---
      // Refresh the button state
      ref.invalidate(isLikedProvider(videoId));
      // Refresh the video details (to show new like count)
      ref.invalidate(videoDetailsProvider(videoId));
      // Refresh the liked videos page in case it's open
      ref.invalidate(likedVideosProvider);

    } catch (e) {
      print("Error toggling like: $e");
      rethrow;
    }
  }
}