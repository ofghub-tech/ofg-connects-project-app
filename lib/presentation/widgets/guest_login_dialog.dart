import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

/// A utility function to check if the user is a guest.
/// If they are, it shows a dialog and returns [true].
/// If they are logged in, it returns [false].
///
/// Usage:
/// if (await checkGuest(context, ref)) return;
/// // Proceed with action...
Future<bool> checkGuest(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider).user;
  final isGuest = user == null || user.email.isEmpty;

  if (!isGuest) return false; // User is logged in, proceed.

  // User is a guest, show the dialog
  await showDialog(
    context: context,
    builder: (context) => const GuestLoginDialog(),
  );
  
  return true; // Action should be blocked
}

class GuestLoginDialog extends ConsumerWidget {
  const GuestLoginDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.blueAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Sign In Required",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "You are currently browsing as a guest. Sign in to upload, like, comment, and follow.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    ref.read(authProvider.notifier).googleLogin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text("Continue with Google"),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}