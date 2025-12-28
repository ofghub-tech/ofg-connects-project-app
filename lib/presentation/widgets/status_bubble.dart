import 'package:flutter/material.dart';
<<<<<<< HEAD
// CORRECTION: Package name must match pubspec.yaml (ofgconnects)
=======
>>>>>>> ae3527dc080370e17b52e3164c73699c33084bda
import 'package:ofgconnects/models/status.dart';

class StatusBubble extends StatelessWidget {
  final List<Status> statuses;
  final VoidCallback onTap;
  final bool isMe;

  const StatusBubble({
    super.key,
    required this.statuses,
    required this.onTap,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final userAvatar = statuses.isNotEmpty ? statuses.first.userAvatar : null;
    final username = isMe ? 'My Status' : (statuses.isNotEmpty ? statuses.first.username : 'User');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: statuses.isNotEmpty 
                  ? const LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFFFF2C55), Color(0xFFFF9800)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: statuses.isEmpty ? Colors.grey[800] : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                      ? NetworkImage(userAvatar)
                      : null,
                  child: (userAvatar == null || userAvatar.isEmpty)
                      ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white))
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              username,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}