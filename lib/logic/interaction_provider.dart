// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// Provider just for logic functions, no complex state needed here
final interactionProvider = Provider((ref) => InteractionLogic(ref));

class InteractionLogic {
  final Ref ref;
  InteractionLogic(this.ref);

  final Databases _db = AppwriteClient.databases;

  // --- REPLICATES: logVideoView function from WatchPage.js ---
  Future<void> logVideoView(String videoId, int currentViewCount) async {
    final user = ref.read(authProvider).user;
    
    // 1. If no user, we can't track history (or you can implement IP tracking, but web app uses user ID)
    if (user == null) return;

    try {
      // 2. Check if user has already seen this video
      // Query: userId == current && videoId == current
      final historyCheck = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1),
        ],
      );

      // 3. If history exists, STOP. Do not increment view count.
      if (historyCheck.total > 0) {
        return;
      }

      // 4. If NEW view:
      // A. Create History Record
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
            'createdAt': DateTime.now().toIso8601String(),
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
  
  // --- Helper to check initial state ---
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
}