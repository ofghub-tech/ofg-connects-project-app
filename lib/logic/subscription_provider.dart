// lib/logic/subscription_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// Import the *existing* databasesProvider
import 'package:ofgconnects_mobile/logic/video_provider.dart' show databasesProvider;

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

  // --- CHANGED: Now accepts ID and Name directly (No Video object needed) ---
  Future<void> followUser({required String creatorId, required String creatorName}) async {
    state = const AsyncLoading();
    final currentUserId = ref.read(authProvider).user?.$id;
    if (currentUserId == null) {
      state = AsyncError('User not logged in', StackTrace.current);
      return;
    }

    final databases = ref.read(databasesProvider);
    try {
      await databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdSubscriptions,
        documentId: ID.unique(),
        data: {
          'followerId': currentUserId,
          'followingId': creatorId,
          'followingUsername': creatorName,
        },
      );
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
    
    // Refresh UI
    ref.invalidate(isFollowingProvider(creatorId));
    ref.invalidate(followerCountProvider);
    ref.invalidate(followingCountProvider);
  }

  Future<void> unfollowUser(String creatorId) async {
    state = const AsyncLoading();
    final currentUserId = ref.read(authProvider).user?.$id;
    if (currentUserId == null) {
      state = AsyncError('User not logged in', StackTrace.current);
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

      if (response.documents.isNotEmpty) {
        final documentId = response.documents.first.$id;
        await databases.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdSubscriptions,
          documentId: documentId,
        );
      }
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
    
    // Refresh UI
    ref.invalidate(isFollowingProvider(creatorId));
    ref.invalidate(followerCountProvider);
    ref.invalidate(followingCountProvider);
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
  return SubscriptionNotifier(ref);
});

// --- STATS PROVIDERS ---

final followerCountProvider = FutureProvider<int>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;

  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [
      Query.equal('followingId', user.$id), 
      Query.limit(0), 
    ],
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
    queries: [
      Query.equal('followerId', user.$id),
      Query.limit(0),
    ],
  );
  return response.total;
});