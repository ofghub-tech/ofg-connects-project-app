// lib/presentation/pages/my_space_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- THIS IS THE FIX ---
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
// ---

class MySpacePage extends ConsumerWidget {
  const MySpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the user's data
    final user = ref.watch(authProvider).user;
    
    // This line will now work
    final userVideosAsync = ref.watch(userVideosProvider);

    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }

    return userVideosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading videos: $err')),
      data: (videos) {
        return ListView.builder(
          itemCount: videos.length + 1,
          itemBuilder: (context, index) {
            
            // --- BUILD THE HEADER (item 0) ---
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // User Avatar
                    CircleAvatar(
                      radius: 50,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Name
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    // User Email
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    
                    // "My Videos" Title
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'My Videos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    
                    // Show this message if the user has no videos
                    if (videos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('You have not uploaded any videos yet.'),
                      ),
                  ],
                ),
              );
            }

            // --- BUILD THE VIDEO LIST (item 1 and beyond) ---
            final video = videos[index - 1];
            return VideoCard(video: video);
          },
        );
      },
    );
  }
}