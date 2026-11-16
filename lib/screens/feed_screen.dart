import 'dart:async';

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

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openCommentsSheet(BuildContext context, String videoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CommentsBottomSheet(videoId: videoId),
    );
  }

  Future<void> _openUploadScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UploadScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Videolar yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pets_rounded,
                          size: 64,
                          color: Color(0xFFFF6B35),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz kedi videosu yok 🐱',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'İlk videoyu sen paylaş!',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _openUploadScreen,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Video Yükle'),
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
                    currentUid: currentUser.uid,
                    isActive: index == _currentPage,
                    onOpenComments: () => _openCommentsSheet(context, doc.id),
                  );
                },
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.pets_rounded,
                        color: Color(0xFFFF6B35),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'MiyavReels',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Material(
                        color: const Color(0xFFFF6B35),
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: IconButton(
                          onPressed: _openUploadScreen,
                          tooltip: 'Video Yükle',
                          icon: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          tooltip: 'Çıkış Yap',
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
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
  final String videoId;
  final Map<String, dynamic> data;
  final String currentUid;
  final bool isActive;
  final VoidCallback onOpenComments;

  const _VideoFeedItem({
    super.key,
    required this.videoId,
    required this.data,
    required this.currentUid,
    required this.isActive,
    required this.onOpenComments,
  });

  @override
  State<_VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<_VideoFeedItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showPauseIcon = false;

  bool _isLiking = false;
  late bool _optimisticLiked;
  late int _optimisticLikesCount;

  @override
  void initState() {
    super.initState();
    _syncLikeStateFromData();
    _initVideo();
  }

  void _syncLikeStateFromData() {
    final likedBy = List<String>.from(widget.data['likedBy'] ?? const []);
    _optimisticLiked = likedBy.contains(widget.currentUid);
    _optimisticLikesCount = (widget.data['likesCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> _initVideo() async {
    final videoUrl = (widget.data['videoUrl'] ?? '').toString();
    if (videoUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;

      setState(() => _isInitialized = true);
      if (widget.isActive) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isLiking) {
      _syncLikeStateFromData();
    }

    if (oldWidget.isActive != widget.isActive && _isInitialized) {
      if (widget.isActive) {
        _controller?.play();
        if (_showPauseIcon) {
          setState(() => _showPauseIcon = false);
        }
      } else {
        _controller?.pause();
      }
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

    if (controller.value.isPlaying) {
      controller.pause();
      setState(() => _showPauseIcon = true);
    } else {
      controller.play();
      setState(() => _showPauseIcon = false);
    }
  }

  Future<void> _handleLikeToggle() async {
    if (_isLiking) return;

    final previousLiked = _optimisticLiked;
    final previousCount = _optimisticLikesCount;
    final willLike = !previousLiked;

    setState(() {
      _isLiking = true;
      _optimisticLiked = willLike;
      _optimisticLikesCount =
          (previousCount + (willLike ? 1 : -1)).clamp(0, 999999999);
    });

    final stopwatch = Stopwatch()..start();

    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({
        'likedBy': willLike
            ? FieldValue.arrayUnion([widget.currentUid])
            : FieldValue.arrayRemove([widget.currentUid]),
        'likesCount': FieldValue.increment(willLike ? 1 : -1),
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimisticLiked = previousLiked;
          _optimisticLikesCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beğeni güncellenemedi.')),
        );
      }
    } finally {
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 600) {
        await Future<void>.delayed(Duration(milliseconds: 600 - elapsed));
      }
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerUsername =
        (widget.data['ownerUsername'] ?? 'kedi_sever').toString();
    final description = (widget.data['description'] ?? '').toString();

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (_hasError)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.white54, size: 44),
                  SizedBox(height: 8),
                  Text(
                    'Video oynatılamadı',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            )
          else
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          if (_showPauseIcon && _isInitialized)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 36,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _handleLikeToggle,
                    iconSize: 36,
                    icon: Icon(
                      _optimisticLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _optimisticLiked
                          ? const Color(0xFFFF4D6D)
                          : Colors.white,
                    ),
                  ),
                  Text(
                    '$_optimisticLikesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 18),
                  IconButton(
                    onPressed: widget.onOpenComments,
                    iconSize: 34,
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Yorumlar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 36,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@$ownerUsername',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                    ),
                  ],
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
  final String videoId;

  const _CommentsBottomSheet({required this.videoId});

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

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      String username = user.displayName ?? '';
      if (username.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        username = (userDoc.data()?['username'] ?? 'kedi_sever').toString();
      }

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum gönderilemedi.')),
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Yorumlar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2B2B38)),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .doc(widget.videoId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF6B35)),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz yorum yok. İlk yorumu sen yaz! 🐾',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final comment = docs[index].data();
                      final username =
                          (comment['username'] ?? 'kedi_sever').toString();
                      final text = (comment['text'] ?? '').toString();

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFFF6B35),
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : 'K',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
            const Divider(height: 1, color: Color(0xFF2B2B38)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: const InputDecoration(
                        hintText: 'Yorum ekle...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendComment,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
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
