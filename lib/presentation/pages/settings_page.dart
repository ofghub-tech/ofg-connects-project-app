// lib/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isGuest = user == null || user.email.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (isGuest)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Guest Account',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You are currently browsing as a guest. Sign in with Google to upload videos, like content, and comment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(authProvider.notifier).googleLogin();
                      },
                      icon: const Icon(Icons.login),
                      label: const Text("Sign In with Google"),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Info',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () {
                          ref.read(authProvider.notifier).logoutUser();
                          Navigator.pop(context); // Close settings after logout
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // --- NEW: Danger Zone ---
            Text(
              "Danger Zone",
              style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.red[50]!.withOpacity(0.05),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Request Account Deletion", style: TextStyle(color: Colors.red)),
                subtitle: const Text("Send a request to permanently delete your account"),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Account?"),
                      content: const Text(
                        "This will open your email client to request account deletion. "
                        "Your account and data will be permanently deleted within 30 days."
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close Dialog
                            
                            // Construct the email
                            final String subject = Uri.encodeComponent("Account Deletion Request: ${user.name}");
                            final String body = Uri.encodeComponent(
                              "To OFG Tech Hub,\n\n"
                              "I request the permanent deletion of my account and all associated data.\n\n"
                              "Account Details:\n"
                              "User ID: ${user.$id}\n"
                              "Email: ${user.email}\n"
                              "Name: ${user.name}\n\n"
                              "Thank you."
                            );
                            
                            final Uri mailUri = Uri.parse("mailto:ofgtechhub@gmail.com?subject=$subject&body=$body");

                            try {
                              if (await canLaunchUrl(mailUri)) {
                                await launchUrl(mailUri);
                              } else {
                                // Fallback if mailto fails (rare, but good practice)
                                await launchUrl(mailUri, mode: LaunchMode.externalApplication);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Could not open email client: $e")),
                                );
                              }
                            }
                          },
                          child: const Text("Send Request", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}