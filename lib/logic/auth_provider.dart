// lib/logic/auth_provider.dart
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:path/path.dart' as p;

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated 
}

class AuthState {
  final AuthStatus status;
  final models.User? user;

  AuthState({this.status = AuthStatus.loading, this.user});

  AuthState copyWith({AuthStatus? status, models.User? user}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    checkUserStatus();
  }

  final Account _account = AppwriteClient.account;
  final Storage _storage = AppwriteClient.storage;
  final Functions _functions = AppwriteClient.functions; // Access Functions

  Future<void> checkUserStatus() async {
    try {
      final currentUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: currentUser);
    } catch (e) {
      await loginAsGuest();
    }
  }

  Future<void> loginAsGuest() async {
    try {
      try {
         await _account.get();
      } catch (_) {
         await _account.createAnonymousSession();
      }
      final guestUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: guestUser);
    } catch (e) {
      print('CRITICAL: Failed to create guest session: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    }
  }

  Future<void> googleLogin() async {
    try {
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      await _account.createOAuth2Session(provider: OAuthProvider.google);
    } catch (e, st) {
      print('googleLogin error: $e\n$st');
      await loginAsGuest();
    }
  }

  Future<void> logoutUser() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await loginAsGuest();
  }

  // --- NEW: Account Deletion ---
  Future<void> deleteAccount() async {
    try {
      // Option 1: Trigger an Appwrite Function to delete the user server-side (Recommended)
      // await _functions.createExecution(
      //   functionId: 'delete_user_function', // Requires a server-side function
      // );
      
      // Option 2: For now, we will clear the session and client-side state.
      // Note: Client SDK cannot delete the user directly for security reasons.
      // You must implement an Appwrite Function to perform 'users.delete(userId)'.
      
      await _account.deleteSession(sessionId: 'current');
      await loginAsGuest();
    } catch (e) {
      print("Delete Account Error: $e");
      rethrow;
    }
  }

  Future<void> updateUserProfile({required String name, required String bio}) async {
    try {
      final currentPrefs = state.user?.prefs.data ?? {};
      currentPrefs['bio'] = bio;

      await _account.updateName(name: name);
      await _account.updatePrefs(prefs: currentPrefs);
      
      await checkUserStatus();
    } catch (e, st) {
      print('updateUserProfile error: $e\n$st');
      rethrow;
    }
  }

  // --- NEW: Not Interested / Block Logic ---
  Future<void> addToIgnoredList({String? videoId, String? creatorId}) async {
    if (state.user == null) return;
    try {
      final currentPrefs = state.user!.prefs.data;
      
      if (videoId != null) {
        final List<dynamic> ignoredVideos = currentPrefs['ignoredVideos'] ?? [];
        if (!ignoredVideos.contains(videoId)) {
          ignoredVideos.add(videoId);
          currentPrefs['ignoredVideos'] = ignoredVideos;
        }
      }

      if (creatorId != null) {
        final List<dynamic> blockedCreators = currentPrefs['blockedCreators'] ?? [];
        if (!blockedCreators.contains(creatorId)) {
          blockedCreators.add(creatorId);
          currentPrefs['blockedCreators'] = blockedCreators;
        }
      }

      await _account.updatePrefs(prefs: currentPrefs);
      await checkUserStatus(); // Refresh state to trigger filters
    } catch (e) {
      print("Error updating ignored list: $e");
    }
  }

  Future<void> uploadProfileImage(File imageFile) async {
    try {
      final fileId = ID.unique();
      final fileName = 'avatar_$fileId${p.extension(imageFile.path)}';

      await _storage.createFile(
        bucketId: AppwriteClient.bucketIdThumbnails,
        fileId: fileId,
        file: InputFile.fromPath(path: imageFile.path, filename: fileName),
        permissions: [Permission.read(Role.any())], 
      );

      final avatarUrl = _storage.getFileView(
        bucketId: AppwriteClient.bucketIdThumbnails,
        fileId: fileId,
      ).toString();

      final currentPrefs = state.user?.prefs.data ?? {};
      currentPrefs['avatar'] = avatarUrl;

      await _account.updatePrefs(prefs: currentPrefs);
      await checkUserStatus();
    } catch (e) {
      print("Error uploading profile image: $e");
      rethrow;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});