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
  
  final Map<String, String> _categoryMap = {
    'General Video': 'general',
    'Short Video': 'shorts',
    'Song': 'songs',
    'Kids Video': 'kids',
  };
  
  late String _selectedCategoryLabel; 

  File? _videoFile;
  File? _thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedCategoryLabel = _categoryMap.keys.first;
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
        const SnackBar(content: Text('Please select a video file'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    await ref.read(uploadProvider.notifier).uploadVideo(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryMap[_selectedCategoryLabel]!,
      tags: _tagsController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    ref.listen<UploadState>(uploadProvider, (previous, next) {
      if (next.error != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}'), backgroundColor: Colors.red),
        );
      }
      if (next.successMessage != null && !next.isLoading && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload Successful!"), backgroundColor: Colors.green),
        );
        context.go('/home');
      }
    });

    // Full Screen Loading Overlay
    if (uploadState.isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            const Opacity(opacity: 0.3, child: ModalBarrier(dismissible: false, color: Colors.black)),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.blueAccent),
                    const SizedBox(height: 24),
                    Text(
                      uploadState.successMessage ?? 'Processing...',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: uploadState.progress, 
                      minHeight: 6, 
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Colors.grey[800],
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 8),
                    Text('${(uploadState.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Text(
                      'Please do not close the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _videoFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_call_rounded, size: 50, color: Colors.blueAccent),
                            SizedBox(height: 12),
                            Text('Select Video', style: TextStyle(color: Colors.white70, fontSize: 16)),
                            Text('Max size 50MB', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 50, color: Colors.greenAccent),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                _videoFile!.path.split('/').last,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(onPressed: _pickVideo, child: const Text("Change"))
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Fields
              _buildLabel('Title'),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                decoration: _inputDecor('Video Title'),
              ),
              const SizedBox(height: 16),

              _buildLabel('Description'),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: _inputDecor('Tell viewers about your video'),
              ),
              const SizedBox(height: 16),

              _buildLabel('Category'),
              DropdownButtonFormField<String>(
                value: _selectedCategoryLabel,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecor('Select Category'),
                items: _categoryMap.keys.map((label) {
                  return DropdownMenuItem(value: label, child: Text(label));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryLabel = val!),
              ),
              const SizedBox(height: 16),

              _buildLabel('Tags'),
              TextFormField(
                controller: _tagsController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecor('e.g., funny, vlog, music'),
                validator: (v) => v!.isEmpty ? 'At least one tag required' : null,
              ),
              const SizedBox(height: 24),

              // 3. Thumbnail
              _buildLabel('Thumbnail (Optional)'),
              GestureDetector(
                onTap: _pickThumbnail,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                    image: _thumbnailFile != null
                        ? DecorationImage(image: FileImage(_thumbnailFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _thumbnailFile == null
                      ? const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Upload Cover', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 32),

              // 4. Upload Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleUpload,
                  child: const Text('Publish Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 50), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}