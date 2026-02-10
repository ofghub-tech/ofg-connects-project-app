// lib/logic/subscription_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart' show databasesProvider;

// Check if following
final isFollowingProvider = FutureProvider.family<bool, String>((ref, creatorId) async {
  final databases = ref.watch(databasesProvider);
  final currentUserId = ref.watch(authProvider).user?.$id;

  if (currentUserId == null) return false;

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [
      Query.equal('followerId', currentUserId),
      Query.equal('followingId', creatorId),
    ],
  );

  return response.documents.isNotEmpty;
});

class SubscriptionNotifier extends StateNotifier<AsyncValue<void>> {
  SubscriptionNotifier(this.ref) : super(const AsyncData(null));

  final Ref ref;
  
  // RACE CONDITION FIX: Track which IDs are currently being processed
  // This prevents "double-tap" duplicates efficiently.
  final Set<String> _processingIds = {};

  Future<void> followUser({required String creatorId, required String creatorName}) async {
    // 1. Instant Lock: Return if already processing this specific user
    if (_processingIds.contains(creatorId)) return;
    _processingIds.add(creatorId);

    state = const AsyncLoading();
    final currentUserId = ref.read(authProvider).user?.$id;
    
    if (currentUserId == null) {
      _processingIds.remove(creatorId);
      state = AsyncError('User not logged in', StackTrace.current);
      return;
    }

    final databases = ref.read(databasesProvider);
    try {
      // 2. Server-side Safety Check
      final check = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdSubscriptions,
        queries: [
          Query.equal('followerId', currentUserId),
          Query.equal('followingId', creatorId),
        ],
      );

      if (check.total == 0) {
        await databases.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdSubscriptions,
          documentId: ID.unique(),
          data: {
            'followerId': currentUserId,
            'followingId': creatorId,
            'followingUsername': creatorName,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
      }
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    } final {
      // 3. Release Lock always
      _processingIds.remove(creatorId);
    }
    
    // Refresh UI
    ref.invalidate(isFollowingProvider(creatorId));
    ref.invalidate(followerCountProvider);
    ref.invalidate(followingCountProvider);
  }

  Future<void> unfollowUser(String creatorId) async {
    // 1. Instant Lock
    if (_processingIds.contains(creatorId)) return;
    _processingIds.add(creatorId);

    state = const AsyncLoading();
    final currentUserId = ref.read(authProvider).user?.$id;
    if (currentUserId == null) {
      _processingIds.remove(creatorId);
      return;
    }

    final databases = ref.read(databasesProvider);
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdSubscriptions,
        queries: [
          Query.equal('followerId', currentUserId),
          Query.equal('followingId', creatorId),
        ],
      );

      // Delete all matches (cleans up any previous duplicates too)
      await Future.wait(response.documents.map((doc) => 
        databases.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdSubscriptions,
          documentId: doc.$id,
        )
      ));
      
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    } finally {
      // 3. Release Lock
      _processingIds.remove(creatorId);
    }
    
    ref.invalidate(isFollowingProvider(creatorId));
    ref.invalidate(followerCountProvider);
    ref.invalidate(followingCountProvider);
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
  return SubscriptionNotifier(ref);
});

// ... [Stats Providers remain the same]
final followerCountProvider = FutureProvider<int>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [Query.equal('followingId', user.$id), Query.limit(0)],
  );
  return response.total;
});

final followingCountProvider = FutureProvider<int>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [Query.equal('followerId', user.$id), Query.limit(0)],
  );
  return response.total;
});