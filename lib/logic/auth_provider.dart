// lib/logic/auth_provider.dart
import 'dart:io'; // Add this import
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
<<<<<<< HEAD
// CORRECTION: Package name must match pubspec.yaml (ofgconnects)
=======
>>>>>>> ae3527dc080370e17b52e3164c73699c33084bda
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:path/path.dart' as p; // Add this for file extensions

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

  // --- NEW: Upload Profile Picture ---
  Future<void> uploadProfileImage(File imageFile) async {
    try {
      // 1. Upload to Appwrite Storage (Using Thumbnails Bucket)
      final fileId = ID.unique();
      final fileName = 'avatar_$fileId${p.extension(imageFile.path)}';

      await _storage.createFile(
        bucketId: AppwriteClient.bucketIdThumbnails,
        fileId: fileId,
        file: InputFile.fromPath(path: imageFile.path, filename: fileName),
        permissions: [Permission.read(Role.any())], // Publicly visible
      );

      // 2. Get View URL
      final avatarUrl = _storage.getFileView(
        bucketId: AppwriteClient.bucketIdThumbnails,
        fileId: fileId,
      ).toString();

      // 3. Update User Prefs with new URL
      final currentPrefs = state.user?.prefs.data ?? {};
      currentPrefs['avatar'] = avatarUrl;

      await _account.updatePrefs(prefs: currentPrefs);

      // 4. Refresh Local State
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