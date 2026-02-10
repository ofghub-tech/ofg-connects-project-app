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

  // RACE CONDITION FIX: Prevent overlapping auth calls
  bool _isAuthenticating = false;

  Future<void> checkUserStatus() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final currentUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: currentUser);
    } catch (e) {
      await _performGuestLogin(); // Refactored to private helper
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> loginAsGuest() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    
    await _performGuestLogin();
    _isAuthenticating = false;
  }

  // Private helper to avoid code duplication and managing lock in one place
  Future<void> _performGuestLogin() async {
    try {
      try {
        // Double check: do we actually have a session?
         await _account.get();
      } catch (_) {
         // Only create if we really don't have one
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
    // Google Login handles its own flow, but we reset state safely
    try {
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      await _account.createOAuth2Session(provider: OAuthProvider.google);
    } catch (e, st) {
      print('googleLogin error: $e\n$st');
      // If OAuth fails, fallback to guest securely
      loginAsGuest();
    }
  }

  Future<void> logoutUser() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    
    // Explicitly call guest login after logout
    await loginAsGuest();
  }

  Future<void> deleteAccount() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      await loginAsGuest();
    } catch (e) {
      print("Delete Account Error: $e");
      rethrow;
    }
  }

  Future<void> updateUserProfile({required String name, required String bio}) async {
    try {
      // Defensive Copy
      final Map<String, dynamic> currentPrefs = Map<String, dynamic>.from(state.user?.prefs.data ?? {});
      currentPrefs['bio'] = bio;

      await _account.updateName(name: name);
      await _account.updatePrefs(prefs: currentPrefs);
      
      // We manually update state here to avoid a full network refresh race
      if (state.user != null) {
          // Note: Ideally re-fetch user, but for speed we can sometimes patch locally. 
          // For now, let's just re-fetch safely.
          await checkUserStatus();
      }
    } catch (e, st) {
      print('updateUserProfile error: $e\n$st');
      rethrow;
    }
  }

  Future<void> addToIgnoredList({String? videoId, String? creatorId}) async {
    if (state.user == null) return;
    try {
      final Map<String, dynamic> currentPrefs = Map<String, dynamic>.from(state.user!.prefs.data);
      
      if (videoId != null) {
        final List<dynamic> ignoredVideos = List<dynamic>.from(currentPrefs['ignoredVideos'] ?? []);
        if (!ignoredVideos.contains(videoId)) {
          ignoredVideos.add(videoId);
          currentPrefs['ignoredVideos'] = ignoredVideos;
        }
      }

      if (creatorId != null) {
        final List<dynamic> blockedCreators = List<dynamic>.from(currentPrefs['blockedCreators'] ?? []);
        if (!blockedCreators.contains(creatorId)) {
          blockedCreators.add(creatorId);
          currentPrefs['blockedCreators'] = blockedCreators;
        }
      }

      await _account.updatePrefs(prefs: currentPrefs);
      // Don't await checkUserStatus here to keep UI snappy, just fire and forget or update local
      checkUserStatus(); 
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

      final Map<String, dynamic> currentPrefs = Map<String, dynamic>.from(state.user?.prefs.data ?? {});
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