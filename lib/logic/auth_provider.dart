// lib/logic/auth_provider.dart
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:path/path.dart' as p;

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final models.User? user;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    models.User? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
      await _refreshAuthenticatedState();
    } catch (_) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage: null,
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      await _account.createEmailPasswordSession(
          email: email.trim(), password: password);
      await _refreshAuthenticatedState();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage:
            _readAuthError(e, fallback: 'Email or password is incorrect.'),
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      await _account.create(
        userId: ID.unique(),
        email: email.trim(),
        password: password,
        name: name.trim().isEmpty ? 'OFG User' : name.trim(),
      );
      await _account.createEmailPasswordSession(
          email: email.trim(), password: password);
      await _refreshAuthenticatedState();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage: _readAuthError(
          e,
          fallback: 'Sign up failed. Email may already be in use.',
        ),
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> logoutUser() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      clearError: true,
    );
  }

  Future<void> deleteAccount() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        clearError: true,
      );
    } catch (e) {
      print("Delete Account Error: $e");
      rethrow;
    }
  }

  Future<void> updateUserProfile(
      {required String name, required String bio}) async {
    try {
      final Map<String, dynamic> currentPrefs =
          Map<String, dynamic>.from(state.user?.prefs.data ?? {});
      currentPrefs['bio'] = bio;

      await _account.updateName(name: name);
      await _account.updatePrefs(prefs: currentPrefs);

      if (state.user != null) {
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
      final Map<String, dynamic> currentPrefs =
          Map<String, dynamic>.from(state.user!.prefs.data);

      if (videoId != null) {
        final List<dynamic> ignoredVideos =
            List<dynamic>.from(currentPrefs['ignoredVideos'] ?? []);
        if (!ignoredVideos.contains(videoId)) {
          ignoredVideos.add(videoId);
          currentPrefs['ignoredVideos'] = ignoredVideos;
        }
      }

      if (creatorId != null) {
        final List<dynamic> blockedCreators =
            List<dynamic>.from(currentPrefs['blockedCreators'] ?? []);
        if (!blockedCreators.contains(creatorId)) {
          blockedCreators.add(creatorId);
          currentPrefs['blockedCreators'] = blockedCreators;
        }
      }

      await _account.updatePrefs(prefs: currentPrefs);
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

      final avatarUrl = _storage
          .getFileView(
            bucketId: AppwriteClient.bucketIdThumbnails,
            fileId: fileId,
          )
          .toString();

      final Map<String, dynamic> currentPrefs =
          Map<String, dynamic>.from(state.user?.prefs.data ?? {});
      currentPrefs['avatar'] = avatarUrl;

      await _account.updatePrefs(prefs: currentPrefs);
      await checkUserStatus();
    } catch (e) {
      print("Error uploading profile image: $e");
      rethrow;
    }
  }

  Future<void> _refreshAuthenticatedState() async {
    final currentUser = await _account.get();
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: currentUser,
      clearError: true,
    );
  }

  String _readAuthError(Object error, {required String fallback}) {
    if (error is AppwriteException) {
      final msg = (error.message ?? '').trim();
      if (msg.isNotEmpty) return msg;
    }
    return fallback;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});