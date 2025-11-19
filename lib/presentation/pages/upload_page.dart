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
  final _tagsController = TextEditingController(); 
  
  // --- FIX: Updated Categories to match Web Code ---
  // Key = UI Label, Value = Backend ID
  final Map<String, String> _categoryMap = {
    'General Video': 'general',
    'Short Video': 'shorts',
    'Song': 'songs',
    'Kids Video': 'kids',
  };
  
  late String _selectedCategoryLabel; // Holds the Key (UI Label)

  File? _videoFile;
  File? _thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedCategoryLabel = _categoryMap.keys.first; // Default to 'General Video'
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _thumbnailFile = File(image.path);
      });
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file'), backgroundColor: Colors.red),
      );
      return;
    }

    // Trigger upload with correct backend value
    await ref.read(uploadProvider.notifier).uploadVideo(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryMap[_selectedCategoryLabel]!, // Send 'songs', 'shorts', etc.
      tags: _tagsController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    ref.listen<UploadState>(uploadProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}'), backgroundColor: Colors.red),
        );
      }
      if (next.successMessage != null && !next.isLoading && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green),
        );
        context.go('/home');
      }
    });

    if (uploadState.isLoading) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  uploadState.successMessage ?? 'Processing...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: uploadState.progress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                Text('${(uploadState.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                const Text(
                  'Compressing and uploading your video.\nPlease do not close the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Video Selection
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _videoFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.blueAccent),
                            SizedBox(height: 8),
                            Text('Tap to select video', style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 48, color: Colors.green),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                _videoFile!.path.split('/').last,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _pickVideo, 
                              child: const Text("Change Video")
                            )
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Fields
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategoryLabel,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _categoryMap.keys.map((label) {
                  return DropdownMenuItem(
                    value: label, 
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryLabel = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'e.g. music, vlog, funny',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Tags are required' : null,
              ),
              const SizedBox(height: 24),

              // 3. Thumbnail
              const Text("Thumbnail (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickThumbnail,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                    image: _thumbnailFile != null
                        ? DecorationImage(
                            image: FileImage(_thumbnailFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _thumbnailFile == null
                      ? const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Select Image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            Positioned(
                              right: 4,
                              top: 4,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => setState(() => _thumbnailFile = null),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // 4. Upload Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Publish Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}