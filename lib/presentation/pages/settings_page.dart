// lib/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Controllers
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // Form Keys
  final _passwordFormKey = GlobalKey<FormState>();

  bool _isPasswordLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Handle updating the password
  Future<void> _handleUpdatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_isPasswordLoading) return;

    setState(() => _isPasswordLoading = true);
    try {
      await ref.read(authProvider.notifier).updateUserPassword(
            _newPasswordController.text,
            _oldPasswordController.text,
          );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
        );
        _oldPasswordController.clear();
        _newPasswordController.clear();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if the user is a guest (no email)
    final user = ref.watch(authProvider).user;
    final isGuest = user == null || user.email.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- "Update Profile" Section REMOVED ---

          // --- Change Password Section (Hidden for guests) ---
          Visibility(
            visible: !isGuest,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Change Password', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Old Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your old password' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value?.length ?? 0) < 8 ? 'Password must be 8+ characters' : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPasswordLoading ? null : _handleUpdatePassword,
                          child: _isPasswordLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Change Password'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // --- Guest Message ---
          Visibility(
            visible: isGuest,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Account Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You are currently signed in as a guest. Sign up with Google to secure your account and change your password.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}