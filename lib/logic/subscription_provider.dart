// lib/logic/subscription_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

// Import the *existing* databasesProvider from video_provider.dart
import 'package:ofgconnects_mobile/logic/video_provider.dart' show databasesProvider;

// This provider will check if the current user is following a specific creator
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

// This Notifier handles the actions of following and unfollowing
class SubscriptionNotifier extends StateNotifier<AsyncValue<void>> {
  SubscriptionNotifier(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<void> followUser(Video video) async {
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
          'followingId': video.creatorId,
          'followingUsername': video.creatorName,
        },
      );
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
    // Refresh the providers to update the UI
    ref.invalidate(isFollowingProvider(video.creatorId));
    // --- REFRESH COUNTS ---
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
      // First, find the subscription document
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
    // Refresh the providers to update the UI
    ref.invalidate(isFollowingProvider(creatorId));
    // --- REFRESH COUNTS ---
    ref.invalidate(followerCountProvider);
    ref.invalidate(followingCountProvider);
  }
}

// The provider for our notifier
final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
  return SubscriptionNotifier(ref);
});

// --- ADDED BACK: PROVIDERS FOR STATS ---

// 1. Provider to get the user's FOLLOWER count
final followerCountProvider = FutureProvider<int>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;

  // This logic is based on your web app's subscriptions collection
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [
      Query.equal('followingId', user.$id), // Count where others are following YOU
      Query.limit(0), // We only need the 'total'
    ],
  );
  return response.total;
});

// 2. Provider to get the user's FOLLOWING count
final followingCountProvider = FutureProvider<int>((ref) async {
  final databases = ref.watch(databasesProvider);
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;

  // This logic is based on your web app's subscriptions collection
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdSubscriptions,
    queries: [
      Query.equal('followerId', user.$id), // Count where YOU are the follower
      Query.limit(0), // We only need the 'total'
    ],
  );
  return response.total;
});