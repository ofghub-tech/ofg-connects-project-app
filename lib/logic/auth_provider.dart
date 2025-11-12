// lib/logic/auth_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart'; // --- THIS IS THE NEW LINE ---
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart'; 

// 1. Define the states our auth can be in
enum AuthStatus {
  loading,
  authenticated,
  unauthenticated
}

// 2. Create the State class
// This holds the data for our provider
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

// 3. Create the Notifier (This is the "AuthContext" itself)
// It contains all the functions from your JS file
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    // Run checkUserStatus when the provider is first created
    checkUserStatus();
  }

  final Account _account = AppwriteClient.account;

  // This is your 'checkUserStatus' function
  Future<void> checkUserStatus() async {
    try {
      final currentUser = await _account.get();
      state = state.copyWith(status: AuthStatus.authenticated, user: currentUser);
    } catch (e) {
      // --- THIS IS THE FIX ---
      // Print the error to the console to see what's wrong
      print('Error in checkUserStatus: $e'); 
      // --- END OF FIX ---
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  // This is your 'loginUser' function
  Future<void> loginUser({required String email, required String password}) async {
    try {
      await _account.createEmailPasswordSession(email: email, password: password);
      await checkUserStatus(); // Refresh user data
    } catch (e) {
      print(e);
      rethrow; // Re-throw the error to be caught by the UI
    }
  }

  // This is your 'registerUser' function
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
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  // This is your 'googleLogin' function
  Future<void> googleLogin() async {
    try {
      await _account.createOAuth2Session(provider: OAuthProvider.google);
      // NOTE: For this to work on native mobile, you must configure
      // custom URL schemes in your AndroidManifest.xml and Info.plist.
      // e.g., 'appwrite-callback-[PROJECT_ID]://'
      await checkUserStatus();
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  // This is your 'logoutUser' function
  Future<void> logoutUser() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    } catch (e) {
      print(e);
    }
  }
  
  // --- Functions from your 'NEW FUNCTIONS' block ---
  
  // This is your 'updateUserName' function
  Future<void> updateUserName(String newName) async {
    try {
        await _account.updateName(name: newName);
        await checkUserStatus(); // Refresh user state
    } catch (e) {
        print(e);
        rethrow;
    }
  }

  // This is your 'updateUserPassword' function
  Future<void> updateUserPassword(String newPassword, String oldPassword) async {
    try {
        await _account.updatePassword(password: newPassword, oldPassword: oldPassword);
    } catch (e) {
        print(e);
        rethrow;
    }
  }
}

// 4. Finally, create the global provider
// This is what our UI will "watch" to get the auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});