// lib/logic/auth_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated // This state now represents a critical error
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

  Future<void> checkUserStatus() async {
    try {
      final currentUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: currentUser);
    } catch (e) {
      // Failed to get user, log in as guest
      await loginAsGuest();
    }
  }

  Future<void> loginAsGuest() async {
    try {
      await _account.createAnonymousSession();
      final guestUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: guestUser);
    } catch (e) {
      // If guest login also fails, this is a critical error
      print('CRITICAL: Failed to create anonymous session: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    }
  }

  Future<void> googleLogin() async {
    try {
      // mark loading
      state = state.copyWith(status: AuthStatus.loading);

      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {
        // ignore if no session exists
      }

      // Start OAuth flow (opens browser)
      await _account.createOAuth2Session(provider: OAuthProvider.google);

      // checkUserStatus() will be called by main.dart's app lifecycle handler
    } catch (e, st) {
      print('googleLogin error: $e\n$st');
      // If Google login fails, revert to guest
      await loginAsGuest();
      rethrow;
    }
  }

  Future<void> logoutUser() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      // After logging out, immediately log back in as guest
      await loginAsGuest();
    } catch (e, st) {
      print('logoutUser error: $e\n$st');
      // Try to log in as guest even if logout fails
      await loginAsGuest();
    }
  }

  // --- UPDATED: Combined function for profile updates ---
  Future<void> updateUserProfile({required String name, required String bio}) async {
    try {
      // Get current prefs, update bio, then send all prefs
      final currentPrefs = state.user?.prefs.data ?? {};
      currentPrefs['bio'] = bio;

      // Update name and prefs
      await _account.updateName(name: name);
      await _account.updatePrefs(prefs: currentPrefs);
      
      // Refresh user state once
      await checkUserStatus();
    } catch (e, st) {
      print('updateUserProfile error: $e\n$st');
      rethrow;
    }
  }
  // --- REMOVED: updateUserName (now part of updateUserProfile) ---

  Future<void> updateUserPassword(String newPassword, String oldPassword) async {
    try {
      await _account.updatePassword(password: newPassword, oldPassword: oldPassword);
    } catch (e, st) {
      print('updateUserPassword error: $e\n$st');
      rethrow;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});