// lib/presentation/pages/upload_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ofgconnects_mobile/logic/upload_provider.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController(); // Comma separated tags
  
  // Default category
  String _selectedCategory = 'General';
  final List<String> _categories = ['General', 'Music', 'Gaming', 'Education', 'Tech', 'Shorts'];

  File? _videoFile;
  File? _thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // Helper to pick video
  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  // Helper to pick thumbnail
  Future<void> _pickThumbnail() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _thumbnailFile = File(image.path);
      });
    }
  }

  // Helper to handle the submit action
  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file')),
      );
      return;
    }

    // Trigger the upload via provider
    await ref.read(uploadProvider.notifier).uploadVideo(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile,
      title: _titleController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      tags: _tagsController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to upload state for feedback
    final uploadState = ref.watch(uploadProvider);

    // Listen specifically for success/error to show snackbars/navigate
    ref.listen<UploadState>(uploadProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}'), backgroundColor: Colors.red),
        );
      }
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green),
        );
        // Go back home after success
        context.go('/home');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: uploadState.isLoading
          ? _buildLoadingView(uploadState)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Video Picker
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _videoFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tap to select video', style: TextStyle(color: Colors.grey)),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, size: 40, color: Colors.green),
                                  const SizedBox(height: 8),
                                  Text('Video selected: ${_videoFile!.path.split('/').last}'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Thumbnail Picker
                    GestureDetector(
                      onTap: _pickThumbnail,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          image: _thumbnailFile != null
                              ? DecorationImage(
                                  image: FileImage(_thumbnailFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _thumbnailFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tap to select thumbnail (Optional)', style: TextStyle(color: Colors.grey)),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Text Fields
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // 4. Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    
                    // 5. Tags
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        hintText: 'e.g. funny, vlog, travel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6. Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleUpload,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Upload Video'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingView(UploadState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: state.progress),
          const SizedBox(height: 16),
          Text(
            'Uploading... ${(state.progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text('Please do not close the app'),
        ],
      ),
    );
  }
}