// lib/logic/auth_provider.dart
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:path/path.dart' as p;

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final models.User? user;
  final bool requiresPasswordSetup;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.requiresPasswordSetup = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    models.User? user,
    bool? requiresPasswordSetup,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      requiresPasswordSetup:
          requiresPasswordSetup ?? this.requiresPasswordSetup,
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
  final String _oauthCallbackScheme =
      'appwrite-callback-${AppwriteClient.projectId}';
  late final String _oauthCallbackUrl = '$_oauthCallbackScheme://auth';

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
        requiresPasswordSetup: false,
        errorMessage: null,
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> googleLogin() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      await _account.createOAuth2Session(
        provider: OAuthProvider.google,
        success: _oauthCallbackUrl,
        failure: _oauthCallbackUrl,
      );
      await _refreshAuthenticatedState();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        requiresPasswordSetup: false,
        errorMessage: _readAuthError(e,
            fallback: 'Google login failed. Please try again.'),
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
        requiresPasswordSetup: false,
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
      await _markPasswordAsSet();
      await _refreshAuthenticatedState();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        requiresPasswordSetup: false,
        errorMessage: _readAuthError(
          e,
          fallback: 'Sign up failed. Email may already be in use.',
        ),
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> completePasswordSetupForGoogle(String newPassword) async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      await _account.updatePassword(password: newPassword);
      await _markPasswordAsSet();
      await checkUserStatus();
    } catch (e) {
      state = state.copyWith(
        errorMessage: _readAuthError(e,
            fallback: 'Could not set password. Please try again.'),
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
      requiresPasswordSetup: false,
      clearError: true,
    );
  }

  Future<void> deleteAccount() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        requiresPasswordSetup: false,
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
      // Defensive Copy
      final Map<String, dynamic> currentPrefs =
          Map<String, dynamic>.from(state.user?.prefs.data ?? {});
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

  Future<bool> _checkNeedsPasswordSetup(models.User user) async {
    if (user.email.isEmpty) return false;
    final prefs = user.prefs.data;
    if (prefs['passwordSet'] == true) return false;
    try {
      final identities = await _account.listIdentities();
      final hasGoogleIdentity = identities.identities
          .any((identity) => identity.provider == 'google');
      return hasGoogleIdentity;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markPasswordAsSet() async {
    final current = await _account.get();
    final prefs = Map<String, dynamic>.from(current.prefs.data);
    prefs['passwordSet'] = true;
    await _account.updatePrefs(prefs: prefs);
  }

  Future<void> _refreshAuthenticatedState() async {
    final currentUser = await _account.get();
    final needsPasswordSetup = await _checkNeedsPasswordSetup(currentUser);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: currentUser,
      requiresPasswordSetup: needsPasswordSetup,
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
