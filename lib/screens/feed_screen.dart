import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'upload_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isScreenActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final shouldBeActive = state == AppLifecycleState.resumed;
    if (_isScreenActive != shouldBeActive) {
      setState(() => _isScreenActive = shouldBeActive);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openUploadScreen() async {
    setState(() => _isScreenActive = false);

    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const UploadScreen()),
    );

    if (!mounted) return;
    setState(() => _isScreenActive = true);

    if (uploaded == true && _pageController.hasClients) {
      _pageController.jumpToPage(0);
      setState(() => _currentPage = 0);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B4A),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosStream = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: videosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Color(0xFFFF4D6D),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Videolar yüklenirken bir hata oluştu.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: const Color(0x26FF6B4A),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.pets_rounded,
                            size: 42,
                            color: Color(0xFFFF6B4A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Henüz hiç kedi videosu yok',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'İlk 40 saniyelik kedi videosunu paylaşarak akışı başlat!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA0A0B2)),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _openUploadScreen,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Video Paylaş'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: docs.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _VideoFeedItem(
                    key: ValueKey(doc.id),
                    videoId: doc.id,
                    data: doc.data(),
                    isActive: index == _currentPage && _isScreenActive,
                  );
                },
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x880A0A0E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          size: 18,
                          color: Color(0xFFFF6B4A),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'KediReels',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: const Color(0xFFFF6B4A),
                    borderRadius: BorderRadius.circular(22),
                    elevation: 4,
                    child: InkWell(
                      onTap: _openUploadScreen,
                      borderRadius: BorderRadius.circular(22),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Yükle',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0x880A0A0E),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _confirmSignOut,
                      tooltip: 'Çıkış Yap',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoFeedItem extends StatefulWidget {
  const _VideoFeedItem({
    super.key,
    required this.videoId,
    required this.data,
    required this.isActive,
  });

  final String videoId;
  final Map<String, dynamic> data;
  final bool isActive;

  @override
  State<_VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<_VideoFeedItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasVideoError = false;
  bool _isPausedByUser = false;

  // Anti-Spam Kalp Kilidi + Optimistic UI durumları
  bool _isLiking = false;
  bool? _optimisticIsLiked;
  int? _optimisticLikesCount;

  @override
  void initState() {
    super.initState();
    _initVideoController();
  }

  Future<void> _initVideoController() async {
    final videoUrl = (widget.data['videoUrl'] ?? '').toString().trim();
    if (videoUrl.isEmpty) {
      if (mounted) setState(() => _hasVideoError = true);
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _isInitialized = true);

      if (widget.isActive && !_isPausedByUser) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasVideoError = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      final controller = _controller;
      if (controller != null && _isInitialized) {
        if (widget.isActive) {
          _isPausedByUser = false;
          controller.play();
        } else {
          controller.pause();
          controller.seekTo(Duration.zero);
        }
      }
    }

    if (!_isLiking) {
      _optimisticIsLiked = null;
      _optimisticLikesCount = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _isPausedByUser = true;
      } else {
        controller.play();
        _isPausedByUser = false;
      }
    });
  }

  bool _serverIsLiked(String uid) {
    final raw = widget.data['likedBy'];
    if (raw is List) {
      return raw.map((e) => e.toString()).contains(uid);
    }
    return false;
  }

  int _serverLikesCount() {
    final raw = widget.data['likesCount'];
    if (raw is int) return math.max(0, raw);
    if (raw is num) return math.max(0, raw.toInt());
    return 0;
  }

  Future<void> _handleLikeToggle({bool onlyLikeOnDoubleTap = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 600ms Anti-Spam kilidi aktifse tıklamaları yoksay
    if (_isLiking) return;

    final uid = currentUser.uid;
    final currentLiked = _optimisticIsLiked ?? _serverIsLiked(uid);
    final currentCount = _optimisticLikesCount ?? _serverLikesCount();

    if (onlyLikeOnDoubleTap && currentLiked) {
      return;
    }

    final nextLiked = !currentLiked;
    final nextCount = math.max(0, currentCount + (nextLiked ? 1 : -1));

    setState(() {
      _isLiking = true;
      _optimisticIsLiked = nextLiked;
      _optimisticLikesCount = nextCount;
    });

    final docRef =
        FirebaseFirestore.instance.collection('videos').doc(widget.videoId);

    try {
      await Future.wait([
        docRef.update({
          'likedBy': nextLiked
              ? FieldValue.arrayUnion([uid])
              : FieldValue.arrayRemove([uid]),
          'likesCount': FieldValue.increment(nextLiked ? 1 : -1),
        }),
        Future<void>.delayed(const Duration(milliseconds: 600)),
      ]);
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimisticIsLiked = currentLiked;
          _optimisticLikesCount = currentCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beğeni güncellenemedi. Bağlantınızı kontrol edin.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
          _optimisticIsLiked = null;
          _optimisticLikesCount = null;
        });
      }
    }
  }

  void _openCommentsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CommentsBottomSheet(videoId: widget.videoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLiked = _optimisticIsLiked ?? _serverIsLiked(uid);
    final likesCount = _optimisticLikesCount ?? _serverLikesCount();
    final ownerUsername =
        (widget.data['ownerUsername'] ?? 'kedi_sever').toString();
    final description = (widget.data['description'] ?? '').toString().trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      onDoubleTap: () => _handleLikeToggle(onlyLikeOnDoubleTap: true),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasVideoError)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 52,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Video oynatılamadı',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else if (!_isInitialized || _controller == null)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B4A),
              ),
            )
          else
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width > 0
                      ? _controller!.value.size.width
                      : MediaQuery.of(context).size.width,
                  height: _controller!.value.size.height > 0
                      ? _controller!.value.size.height
                      : MediaQuery.of(context).size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),

          if (_isInitialized &&
              _controller != null &&
              !_controller!.value.isPlaying &&
              _isPausedByUser)
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0x88000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
            ),

          // Alt yazıların her videoda okunabilmesi için yumuşak koyu geçiş
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 240,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sol alt köşe: @kullanici_adi ve açıklama
          Positioned(
            left: 16,
            right: 92,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0x33FF6B4A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pets_rounded,
                          size: 18,
                          color: Color(0xFFFF6B4A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '@$ownerUsername',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Sağ alt köşe: Kalp beğenisi ve Yorumlar butonu
          Positioned(
            right: 12,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _handleLikeToggle(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isLiked ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 160),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Color(0x66000000),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 30,
                              color: isLiked
                                  ? const Color(0xFFFF4D6D)
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$likesCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _openCommentsSheet,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0x66000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mode_comment_rounded,
                            size: 27,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Yorum',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsBottomSheet extends StatefulWidget {
  const _CommentsBottomSheet({required this.videoId});

  final String videoId;

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
    } catch (_) {
      // Firestore okuma başarısız olursa Auth displayName kullanılır.
    }

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

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      final username = await _resolveCurrentUsername(user);

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final commentsStream = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A4C),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Yorumlar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF262634)),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: commentsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz yorum yok. İlk yorumu sen yaz!',
                        style: TextStyle(color: Color(0xFFA0A0B2)),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final username =
                          (data['username'] ?? 'kedi_sever').toString();
                      final text = (data['text'] ?? '').toString();

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0x26FF6B4A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pets_rounded,
                              size: 17,
                              color: Color(0xFFFF6B4A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    color: Color(0xFFFF937A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFF262634)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      enabled: !_isSending,
                      maxLength: 300,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: const InputDecoration(
                        hintText: 'Kedi hakkında yorum yaz...',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      onPressed: _isSending ? null : _sendComment,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFFFF6B4A),
                        shape: const CircleBorder(),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
