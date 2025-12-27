import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';       // <--- CHANGED
import 'package:media_kit_video/media_kit_video.dart'; // <--- CHANGED

import 'package:ofgconnects_mobile/logic/upload_provider.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  // Replace VideoPlayerController with MediaKit Player
  Player? _player;
  VideoController? _controller;
  
  File? _selectedVideo;
  File? _selectedThumbnail;
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();
  
  String _selectedCategory = 'Sermons';
  final List<String> _categories = ['Sermons', 'Music', 'Testimonies', 'Bible Study', 'Vlogs'];

  @override
  void dispose() {
    _player?.dispose(); // IMPORTANT
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // Initialize MediaKit Player for Preview
      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(file.path));
      
      setState(() {
        _selectedVideo = file;
        _player = player;
        _controller = controller;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedThumbnail = File(pickedFile.path);
      });
    }
  }

  void _handleUpload() async {
    if (_selectedVideo == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video and enter a title.")),
      );
      return;
    }

    // Call the provider
    await ref.read(uploadProvider.notifier).uploadVideo(
      videoFile: _selectedVideo!,
      thumbnailFile: _selectedThumbnail,
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory,
      tags: _tagsController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    // Listen for Success/Error
    ref.listen(uploadProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      }
      if (next.successMessage != null && next.progress == 100 && !next.isLoading) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
         context.pop(); // Go back home on success
      }
    });

    if (uploadState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: uploadState.progress / 100),
              const SizedBox(height: 20),
              Text(uploadState.successMessage ?? "Uploading...", style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              Text("${uploadState.progress.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => ref.read(uploadProvider.notifier).cancelUpload(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Cancel Upload"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Upload Video")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Preview Area
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: _selectedVideo != null && _controller != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Video(controller: _controller!), // MediaKit Widget
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library, size: 50, color: Colors.white54),
                          SizedBox(height: 10),
                          Text("Tap to select video", style: TextStyle(color: Colors.white54)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Thumbnail Picker
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickThumbnail,
                  icon: const Icon(Icons.image),
                  label: const Text("Custom Thumbnail"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                ),
                const SizedBox(width: 12),
                if (_selectedThumbnail != null)
                  const Text("Thumbnail Selected ✅", style: TextStyle(color: Colors.green)),
              ],
            ),
            const SizedBox(height: 20),

            // Fields
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title", prefixIcon: Icon(Icons.title)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Description", prefixIcon: Icon(Icons.description)),
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF2C2C2C),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: const InputDecoration(labelText: "Category", prefixIcon: Icon(Icons.category)),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(labelText: "Tags (comma separated)", prefixIcon: Icon(Icons.tag)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleUpload,
                child: const Text("UPLOAD VIDEO"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}