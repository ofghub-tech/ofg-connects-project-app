// lib/logic/subscription_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

// --- THIS IS THE FIX ---
// Import the *existing* databasesProvider from video_provider.dart
import 'package:ofgconnects_mobile/logic/video_provider.dart' show databasesProvider;
// ---

// This provider will check if the current user is following a specific creator
final isFollowingProvider = FutureProvider.family<bool, String>((ref, creatorId) async {
  final databases = ref.watch(databasesProvider); // This now works
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

    final databases = ref.read(databasesProvider); // This now works
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
    // Refresh the provider to update the UI
    ref.invalidate(isFollowingProvider(video.creatorId));
  }

  Future<void> unfollowUser(String creatorId) async {
    state = const AsyncLoading();
    final currentUserId = ref.read(authProvider).user?.$id;
    if (currentUserId == null) {
      state = AsyncError('User not logged in', StackTrace.current);
      return;
    }

    final databases = ref.read(databasesProvider); // This now works
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
    // Refresh the provider to update the UI
    ref.invalidate(isFollowingProvider(creatorId));
  }
}

// The provider for our notifier
final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
  return SubscriptionNotifier(ref);
});