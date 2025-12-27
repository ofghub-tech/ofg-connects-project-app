// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// -----------------------------------------------------------------------------
// 1. HELPER: Get Database Instance Safely
// -----------------------------------------------------------------------------
final databasesProvider = Provider<Databases>((ref) {
  return Databases(AppwriteClient.client); 
});

// -----------------------------------------------------------------------------
// 2. VIEW LOGIC (History & View Counts)
// -----------------------------------------------------------------------------
final interactionProvider = Provider((ref) => InteractionLogic(ref));

class InteractionLogic {
  final Ref ref;
  InteractionLogic(this.ref);

  Databases get _db => ref.read(databasesProvider);

  Future<void> logVideoView(String videoId) async {
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

      if (check.total == 0) {
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: ID.unique(),
          data: {
            'userId': user.$id, 
            'videoId': videoId,
            // System handles $createdAt automatically
          },
        );
        await _incrementViewCount(videoId);
      }
    } catch (e) {
      print("View Log Error: $e");
    }
  }

  Future<void> _incrementViewCount(String videoId) async {
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId
      );
      
      final current = doc.data['viewCount'] ?? 0; 
      
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: {'viewCount': current + 1},
      );
    } catch (e) {
      print("Increment View Error: $e");
    }
  }
}

// -----------------------------------------------------------------------------
// 3. LIKE NOTIFIER (CRASH PROOF VERSION)
// -----------------------------------------------------------------------------
final isLikedProvider = StateNotifierProvider.family<LikeNotifier, AsyncValue<bool>, String>((ref, videoId) {
  return LikeNotifier(ref, videoId);
});

class LikeNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final String videoId;
  
  // Lock to prevent simple spam clicks
  bool _isProcessing = false;

  LikeNotifier(this.ref, this.videoId) : super(const AsyncLoading()) {
    _init();
  }

  Databases get _db => ref.read(databasesProvider);

  Future<void> _init() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = const AsyncData(false);
      return;
    }

    try {
      final res = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1)
        ]
      );
      if (mounted) state = AsyncData(res.total > 0);
    } catch (e) {
      if (mounted) state = const AsyncData(false);
    }
  }

  // UPDATED: Handles Race Conditions (409 Error)
  Future<void> toggle({String type = 'video'}) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      print("❌ Like Failed: User is not logged in");
      return;
    }

    // 1. STOP SPAM CLICKS
    if (_isProcessing) return; 
    _isProcessing = true;

    // 2. OPTIMISTIC UPDATE (Flip the heart instantly)
    final bool startState = state.value ?? false;
    state = AsyncData(!startState);

    try {
      // 3. FORCE CHECK SERVER STATE
      // Ask the DB: "Does a like ALREADY exist?"
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1)
        ],
      );

      if (check.total > 0) {
        // --- CASE A: ALREADY LIKED -> DELETE IT ---
        print("💔 Found existing like. Deleting...");
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: check.documents.first.$id,
        );
        _updateVideoStat(videoId, -1);
        // Sync state to false just in case
        if (mounted) state = const AsyncData(false);

      } else {
        // --- CASE B: NOT LIKED -> CREATE IT ---
        print("❤️ No like found. Creating...");
        try {
          await _db.createDocument(
            databaseId: AppwriteClient.databaseId,
            collectionId: AppwriteClient.collectionIdLikes,
            documentId: ID.unique(),
            data: {
              'userId': user.$id, 
              'videoId': videoId, 
              'type': type, 
            },
          );
          _updateVideoStat(videoId, 1);
          // Sync state to true
          if (mounted) state = const AsyncData(true);
          
        } on AppwriteException catch (e) {
          // --- CASE C: RACE CONDITION (The 409 Error Fix) ---
          // If Appwrite says "Already Exists" (409), it means we clicked too fast.
          // Switch to DELETE mode immediately to fix it.
          if (e.code == 409) {
            print("⚠️ Race condition detected (409). Switching to DELETE mode.");
            
            // We must find the hidden document ID again
            final retryCheck = await _db.listDocuments(
              databaseId: AppwriteClient.databaseId,
              collectionId: AppwriteClient.collectionIdLikes,
              queries: [
                Query.equal('userId', user.$id),
                Query.equal('videoId', videoId),
                Query.limit(1)
              ],
            );
            
            if (retryCheck.total > 0) {
              await _db.deleteDocument(
                databaseId: AppwriteClient.databaseId,
                collectionId: AppwriteClient.collectionIdLikes,
                documentId: retryCheck.documents.first.$id,
              );
              _updateVideoStat(videoId, -1);
              if (mounted) state = const AsyncData(false);
              print("✅ Auto-corrected 409 error.");
            }
          } else {
            // Real error (Permission, Network, etc)
            rethrow; 
          }
        }
      }
    } catch (e) {
      print("❌ ACTION FAILED: $e");
      // Revert UI on critical failure
      if (mounted) state = AsyncData(startState);
    } finally {
      // Release lock
      _isProcessing = false;
    }
  }

  Future<void> _updateVideoStat(String videoId, int change) async {
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: videoId
      );
      
      final current = doc.data['likeCount'] ?? 0;
      final int safeCurrent = current is int ? current : int.tryParse(current.toString()) ?? 0;
      
      int newCount = safeCurrent + change;
      if (newCount < 0) newCount = 0;

      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: videoId, 
        data: {'likeCount': newCount}
      );
    } catch (e) {
      print("Stat Update Error: $e");
    }
  }
}

// -----------------------------------------------------------------------------
// 4. SAVE NOTIFIER
// -----------------------------------------------------------------------------
final isSavedProvider = StateNotifierProvider.family<SaveNotifier, AsyncValue<bool>, String>((ref, videoId) {
  return SaveNotifier(ref, videoId);
});

class SaveNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final String videoId;

  SaveNotifier(this.ref, this.videoId) : super(const AsyncLoading()) {
    _init();
  }

  Databases get _db => ref.read(databasesProvider);

  Future<void> _init() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = const AsyncData(false);
      return;
    }
    try {
      final res = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1)
        ]
      );
      if (mounted) state = AsyncData(res.total > 0);
    } catch (e) {
      if (mounted) state = const AsyncData(false);
    }
  }

  Future<void> toggle() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final currentStatus = state.value ?? false;
    state = AsyncData(!currentStatus);

    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', videoId),
          Query.limit(1)
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
        );
      }
    } catch (e) {
      print("Save Failed: $e");
      if (mounted) state = AsyncData(currentStatus);
    }
  }
}