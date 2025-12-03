import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ofgconnects_mobile/logic/upload_provider.dart';
// REMOVED: import 'package:video_compress/video_compress.dart'; (Not needed anymore)

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

  // For displaying file size to user
  String _fileSizeString = "";

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

  // Helper to format file size
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) / 3; // Log10 approximation
    int index = i.floor();
    if (index >= suffixes.length) index = suffixes.length - 1;
    double size = bytes / (1 << (10 * index)).toDouble(); // Binary division
    // Fix for 1024 math vs clean display
    if (bytes < 1024) return "$bytes B";
    
    // Simple loop approach is safer for dart
    int div = 1;
    int suffixIndex = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }
    return "${value.toStringAsFixed(decimals)} ${suffixes[suffixIndex]}";
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      // --- NEW CHECK: Validate Extension ---
      final String extension = video.path.split('.').last.toLowerCase();
      
      // Allow only MP4 and MOV (iOS default)
      if (extension != 'mp4' && extension != 'mov') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format not supported. Please choose an MP4 or MOV video.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      // -------------------------------------

      final file = File(video.path);
      final size = await file.length();
      
      setState(() {
        _videoFile = file;
        _fileSizeString = _formatBytes(size, 2);
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

    // No compression logic here anymore. Direct upload.
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

    // Listener for Success/Error/Cancel
    ref.listen<UploadState>(uploadProvider, (previous, next) {
      if (next.error != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!), 
            backgroundColor: next.error!.contains("Cancelled") ? Colors.orange : Colors.red
          ),
        );
      }
      if (next.successMessage != null && !next.isLoading && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload Successful!"), backgroundColor: Colors.green),
        );
        context.go('/home');
      }
    });

    return Stack(
      children: [
        // --- MAIN FORM CONTENT ---
        Scaffold(
          backgroundColor: const Color(0xFF121212), // Darker background
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Upload Video', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Picker
                  GestureDetector(
                    onTap: uploadState.isLoading ? null : _pickVideo,
                    child: Container(
                      height: 200,
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
                                Icon(Icons.cloud_upload_outlined, size: 60, color: Colors.blueAccent),
                                SizedBox(height: 16),
                                Text('Tap to Select Video', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('MP4, MOV (Max 5GB)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 50, color: Colors.greenAccent),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    _videoFile!.path.split('/').last,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(_fileSizeString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                                  child: const Text("Change Video", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                                )
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Inputs
                  _buildLabel('Title'),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    decoration: _inputDecor('Video Title'),
                    enabled: !uploadState.isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildLabel('Description'),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: _inputDecor('Tell viewers about your video'),
                    enabled: !uploadState.isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Category'),
                            DropdownButtonFormField<String>(
                              value: _selectedCategoryLabel,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecor('Select'),
                              items: _categoryMap.keys.map((label) {
                                return DropdownMenuItem(value: label, child: Text(label));
                              }).toList(),
                              onChanged: uploadState.isLoading ? null : (val) => setState(() => _selectedCategoryLabel = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Tags'),
                            TextFormField(
                              controller: _tagsController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecor('e.g. #worship'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              enabled: !uploadState.isLoading,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  _buildLabel('Thumbnail (Optional)'),
                  GestureDetector(
                    onTap: uploadState.isLoading ? null : _pickThumbnail,
                    child: Container(
                      height: 140,
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
                                  Icon(Icons.image, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Upload Cover Image', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  top: 8, right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                  ),
                                )
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: uploadState.isLoading ? null : _handleUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                      ),
                      child: const Text('Publish Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),

        // --- LOADING OVERLAY ---
        if (uploadState.isLoading)
          Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading Circle
                    const SizedBox(
                      height: 50, width: 50,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 24),
                    
                    // Status Text
                    Text(
                      uploadState.successMessage ?? 'Processing...',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please keep the app open.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    
                    // Linear Progress Bar
                    LinearProgressIndicator(
                      value: uploadState.progress / 100, // Normalized 0.0 to 1.0
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Colors.grey[800],
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 8),
                    
                    // Percentage Text
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${uploadState.progress.toInt()}%',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    
                    // --- CANCEL BUTTON ---
                    TextButton.icon(
                      onPressed: uploadState.isCancelling 
                        ? null 
                        : () {
                           // Call Cancel Logic
                           ref.read(uploadProvider.notifier).cancelUpload();
                        },
                      icon: uploadState.isCancelling 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.close, color: Colors.redAccent),
                      label: Text(
                        uploadState.isCancelling ? "Cancelling..." : "Cancel Upload",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
      ],
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}