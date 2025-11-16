import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Space'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // User Profile Header (Static for now)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 35),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, User!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Manage your library', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Divider(),
          ),

          // The Menu Options
          _buildMenuTile(context, 'History', Icons.history, '/history'),
          _buildMenuTile(context, 'Liked Videos', Icons.thumb_up_outlined, '/liked-videos'),
          _buildMenuTile(context, 'Watch Later', Icons.watch_later_outlined, '/watch-later'),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push(route),
    );
  }
}