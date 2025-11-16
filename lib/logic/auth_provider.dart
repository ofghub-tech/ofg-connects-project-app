// lib/logic/auth_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';

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

  Future<void> checkUserStatus() async {
    try {
      final currentUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: currentUser);
    } catch (e, st) {
      // useful debug info
      print('Error in checkUserStatus: $e\n$st');
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    }
  }

  Future<void> loginUser({required String email, required String password}) async {
    try {
      // mark loading so UI doesn't navigate away mid-flow
      state = state.copyWith(status: AuthStatus.loading);

      // Remove any existing session (best-effort)
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {
        // ignore
      }

      // Use the Appwrite method available in your SDK:
      // createEmailPasswordSession is expected in recent Appwrite Dart SDKs.
      await _account.createEmailPasswordSession(email: email, password: password);

      // Refresh state after successful login
      await checkUserStatus();
    } catch (e, st) {
      print('loginUser error: $e\n$st');
      rethrow;
    }
  }

  Future<void> registerUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      // Log in immediately after registering
      await loginUser(email: email, password: password);
    } catch (e, st) {
      print('registerUser error: $e\n$st');
      rethrow;
    }
  }

  Future<void> googleLogin() async {
    try {
      // mark loading so the app won't navigate to /login while the browser flow runs
      state = state.copyWith(status: AuthStatus.loading);

      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {
        // ignore
      }

      // Start OAuth flow (opens browser)
      await _account.createOAuth2Session(provider: OAuthProvider.google);

      // We DO NOT call checkUserStatus() here because user is redirected out to browser.
      // The app should call checkUserStatus() on resume (your main.dart lifecycle handler).
    } catch (e, st) {
      print('googleLogin error: $e\n$st');
      rethrow;
    }
  }

  Future<void> logoutUser() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    } catch (e, st) {
      print('logoutUser error: $e\n$st');
    }
  }

  Future<void> updateUserName(String newName) async {
    try {
      await _account.updateName(name: newName);
      await checkUserStatus();
    } catch (e, st) {
      print('updateUserName error: $e\n$st');
      rethrow;
    }
  }

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
