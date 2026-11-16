import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    this.isTabActive = true,
    this.onUploadSuccess,
  });

  final bool isTabActive;
  final VoidCallback? onUploadSuccess;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const String _cloudinaryCloudName = 'yluzbcka';
  static const String _cloudinaryUploadPreset = 'watchcat_preset';
  static const Duration _maxVideoDuration = Duration(seconds: 40);

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  File? _selectedVideoFile;
  VideoPlayerController? _previewController;
  Duration? _videoDuration;

  bool _isCheckingVideo = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void didUpdateWidget(covariant UploadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive != widget.isTabActive) {
      final controller = _previewController;
      if (controller != null && controller.value.isInitialized) {
        if (widget.isTabActive && !_isUploading) {
          controller.play();
        } else {
          controller.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? const Color(0xFFB3261E) : const Color(0xFF232332),
        ),
      );
  }

  Future<void> _pickVideoFromGallery() async {
    if (_isCheckingVideo || _isUploading) return;

    final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isCheckingVideo = true);

    final file = File(picked.path);
    VideoPlayerController? tempController;

    try {
      tempController = VideoPlayerController.file(file);
      await tempController.initialize();
      final duration = tempController.value.duration;

      if (duration <= Duration.zero) {
        await tempController.dispose();
        _showSnackBar(
          'Video süresi okunamadı. Lütfen başka bir kedi videosu seçin.',
          isError: true,
        );
        return;
      }

      if (duration > _maxVideoDuration) {
        await tempController.dispose();
        await _previewController?.dispose();
        if (mounted) {
          setState(() {
            _selectedVideoFile = null;
            _previewController = null;
            _videoDuration = null;
          });
        }
        _showSnackBar(
          'Seçtiğiniz video ${duration.inSeconds} saniye! En fazla 40 saniyelik kedi videoları yükleyebilirsiniz.',
          isError: true,
        );
        return;
      }

      await tempController.setLooping(true);
      if (widget.isTabActive) {
        await tempController.play();
      }

      final oldController = _previewController;
      if (mounted) {
        setState(() {
          _selectedVideoFile = file;
          _previewController = tempController;
          _videoDuration = duration;
        });
      }
      await oldController?.dispose();
    } catch (e) {
      await tempController?.dispose();
      _showSnackBar('Video hazırlanırken hata oluştu: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCheckingVideo = false);
      }
    }
  }

  String _ensureMp4Url(String secureUrl) {
    final uri = Uri.parse(secureUrl);
    final path = uri.path;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1) {
      final ext = path.substring(dotIndex).toLowerCase();
      if (ext != '.mp4') {
        final updatedPath = '${path.substring(0, dotIndex)}.mp4';
        return uri.replace(path: updatedPath).toString();
      }
    }
    return secureUrl;
  }

  Future<String> _resolveCurrentUsername(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final firestoreName = userDoc.data()?['username']?.toString().trim();
      if (firestoreName != null && firestoreName.isNotEmpty) {
        return firestoreName;
      }
    } catch (_) {}

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final emailPrefix = user.email?.split('@').first.trim();
    if (emailPrefix != null && emailPrefix.isNotEmpty) {
      return emailPrefix;
    }

    return 'kedi_sever';
  }

  Future<String> _uploadToCloudinary(File videoFile) async {
    final uploadUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/video/upload',
    );

    final request = _ProgressMultipartRequest(
      'POST',
      uploadUri,
      onProgress: (bytesSent, totalBytes) {
        if (!mounted || totalBytes <= 0) return;
        final progress = (bytesSent / totalBytes).clamp(0.0, 1.0);
        setState(() => _uploadProgress = progress);
      },
    );

    request.fields['upload_preset'] = _cloudinaryUploadPreset;
    request.files.add(
      await http.MultipartFile.fromPath('file', videoFile.path),
    );

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
          'Cloudinary yükleme hatası (${streamedResponse.statusCode}): $responseBody',
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final secureUrl = decoded['secure_url']?.toString();
      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary geçerli bir video URL adresi döndürmedi.');
      }

      return _ensureMp4Url(secureUrl);
    } finally {
      client.close();
    }
  }

  Future<void> _resetUploadForm() async {
    final oldController = _previewController;
    _descriptionController.clear();
    if (mounted) {
      setState(() {
        _selectedVideoFile = null;
        _previewController = null;
        _videoDuration = null;
        _uploadProgress = 0.0;
      });
    }
    await oldController?.dispose();
  }

  Future<void> _uploadAndSaveVideo() async {
    FocusScope.of(context).unfocus();

    final videoFile = _selectedVideoFile;
    if (videoFile == null) {
      _showSnackBar('Lütfen önce galeriden bir kedi videosu seçin.', isError: true);
      return;
    }

    final duration = _videoDuration;
    if (duration == null || duration > _maxVideoDuration) {
      _showSnackBar(
        'Video süresi maksimum 40 saniye olabilir.',
        isError: true,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Oturum bulunamadı. Lütfen tekrar giriş yapın.', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    await _previewController?.pause();

    try {
      final mp4Url = await _uploadToCloudinary(videoFile);
      final username = await _resolveCurrentUsername(user);

      await FirebaseFirestore.instance.collection('videos').add({
        'videoUrl': mp4Url,
        'ownerId': user.uid,
        'ownerUsername': username,
        'description': _descriptionController.text.trim(),
        'likesCount': 0,
        'likedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar('Kedi videon başarıyla paylaşıldı!');

      if (widget.onUploadSuccess != null) {
        await _resetUploadForm();
        widget.onUploadSuccess!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showSnackBar('Yükleme başarısız: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_uploadProgress * 100).round();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onUploadSuccess == null,
        title: const Text(
          'Kedi Videosu Yükle',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _isUploading ? null : _pickVideoFromGallery,
                child: Container(
                  height: 340,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2E2E3E),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isCheckingVideo
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Video süresi kontrol ediliyor...',
                                style: TextStyle(color: Color(0xFFA0A0B2)),
                              ),
                            ],
                          ),
                        )
                      : _previewController != null &&
                              _previewController!.value.isInitialized
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _previewController!.value.size.width,
                                    height:
                                        _previewController!.value.size.height,
                                    child: VideoPlayer(_previewController!),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xAA000000),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_videoDuration?.inSeconds ?? 0} sn / 40 sn',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _isUploading
                                        ? null
                                        : _pickVideoFromGallery,
                                    icon: const Icon(Icons.swap_horiz_rounded),
                                    label: const Text('Değiştir'),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: const Color(0x26FF6B4A),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.video_library_rounded,
                                    size: 34,
                                    color: Color(0xFFFF6B4A),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Galeriden Kedi Videosu Seç',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Maksimum süre: 40 saniye',
                                  style: TextStyle(
                                    color: Color(0xFFA0A0B2),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descriptionController,
                enabled: !_isUploading,
                maxLines: 3,
                maxLength: 180,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Kedinin bu tatlı anını kısaca anlat...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              if (_isUploading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E2E3E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Video buluta yükleniyor...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '%$progressPercent',
                            style: const TextStyle(
                              color: Color(0xFFFF6B4A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          minHeight: 8,
                          backgroundColor: const Color(0xFF262634),
                          color: const Color(0xFFFF6B4A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: (_isUploading ||
                          _isCheckingVideo ||
                          _selectedVideoFile == null)
                      ? null
                      : _uploadAndSaveVideo,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    _isUploading
                        ? 'Yükleniyor (%$progressPercent)'
                        : 'Videoyu Paylaş',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(
    super.method,
    super.url, {
    required this.onProgress,
  });

  final void Function(int bytesSent, int totalBytes) onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    var bytes = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytes += data.length;
        onProgress(bytes, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
