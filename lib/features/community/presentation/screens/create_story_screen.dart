// Add a story (photo + optional text) that expires in about 24 hours.
// Image saved as Base64 in Firestore stories collection via createStory().

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_emoji_picker_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Pick an image and optional text overlay; uploads a 24h story to Firestore.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  // StatefulWidget: preview bytes in state; setState after ImagePicker returns.
  final _overlayController = TextEditingController();
  final _overlayScrollController = ScrollController();
  final _picker = ImagePicker();
  final _repo = CommunityRepository();

  // This keeps the photos the user selected for the story.
  final List<XFile> _images = [];

  // This controls which photo is shown in the big preview.
  int _activeIndex = 0;

  // These values control story text style and position on the photo.
  int _textColorValue = 0xFFFFFFFF;
  double _textSize = 20;
  double _textPosX = 0.5;
  double _textPosY = 0.75;

  bool _submitting = false;

  bool get _canSubmit =>
      _images.isNotEmpty &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _overlayController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _overlayScrollController.dispose();
    super.dispose();
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final photos = await Permission.photos.request();
        return photos.isGranted || photos.isLimited;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final photos = await Permission.photos.request();
        if (photos.isGranted || photos.isLimited) return true;
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        final cam = await Permission.camera.request();
        return cam.isGranted;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<void> _pickFromGallery() async {
    final ok = await _ensureGalleryPermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow photo access in Settings to pick images from your gallery.',
          ),
        ),
      );
      return;
    }
    try {
      // This allows picking multiple photos for one story.
      final files = await _picker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (files.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _images.addAll(files);
        _activeIndex = _activeIndex.clamp(0, _images.length - 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    final ok = await _ensureCameraPermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow camera access in Settings to take a photo.',
          ),
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        _images.add(file);
        _activeIndex = _images.length - 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use camera: $e')),
      );
    }
  }

  // Upload story image as Base64 to Firestore with 24h expiry via repo.createStory.
  Future<void> _submit() async {
    if (_submitting || !_canSubmit) return;
    if (_images.isEmpty) return;

    setState(() => _submitting = true);
    try {
      // This creates the story with photos and saved text style values.
      await _repo.createStoryFull(
        images: _images,
        textOverlay: _overlayController.text,
        textColorValue: _textColorValue,
        textSize: _textSize,
        textPosX: _textPosX,
        textPosY: _textPosY,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('createStory failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not post your story. ${e is Exception ? e.toString() : 'Please try again.'}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pageBg =
        isDarkMode ? const Color(0xFF121212) : AppColors.background;
    final cardColor =
        isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF444444) : AppColors.outline;
    final titleColor =
        isDarkMode ? const Color(0xFFF2F2F2) : AppColors.textPrimary;
    final secondaryColor =
        isDarkMode ? const Color(0xFFBFBFBF) : AppColors.textSecondary;
    final mutedColor =
        isDarkMode ? const Color(0xFF9A9A9A) : AppColors.textMuted;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Story')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sign in to create a story.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'New Story',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final firstName = (data?['firstName'] as String?)?.trim();
          final resolvedName = (firstName != null && firstName.isNotEmpty)
              ? firstName
              : (user.displayName?.split(' ').first ??
                  user.email?.split('@').first ??
                  'User');

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    gradient: isDarkMode
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFE8C4),
                              Color(0xFFFFF6E8),
                            ],
                          ),
                    color: isDarkMode ? cardColor : null,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CurrentUserAvatar(
                        size: 48,
                        backgroundColor:
                            isDarkMode ? const Color(0xFF444444) : const Color(0xFFD28E18),
                        borderColor: Colors.white.withValues(alpha: 0.65),
                        borderWidth: 2,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          resolvedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // This shows the story preview with draggable text.
                if (_images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size =
                              Size(constraints.maxWidth, constraints.maxHeight);
                          final overlayColor = Color(_textColorValue);
                          final file = _images[_activeIndex.clamp(0, _images.length - 1)];
                          return FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (context, snap) {
                              final bytes = snap.data;
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (bytes != null && bytes.isNotEmpty)
                                    Image.memory(bytes, fit: BoxFit.cover)
                                  else
                                    Container(
                                      color: isDarkMode
                                          ? const Color(0xFF1E1E1E)
                                          : AppColors.surfaceMuted,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(
                                        color: AppColors.primaryDeep,
                                      ),
                                    ),

                                  // This draws the story text using the current style values.
                                  if (_overlayController.text.trim().isNotEmpty)
                                    Positioned(
                                      left: _textPosX * size.width,
                                      top: _textPosY * size.height,
                                      child: GestureDetector(
                                        // This lets the user drag the text anywhere on the image.
                                        onPanUpdate: (d) {
                                          setState(() {
                                            _textPosX = (_textPosX + d.delta.dx / size.width)
                                                .clamp(0.0, 1.0);
                                            _textPosY = (_textPosY + d.delta.dy / size.height)
                                                .clamp(0.0, 1.0);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _overlayController.text,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: overlayColor,
                                              fontSize: _textSize,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                              shadows: const [
                                                Shadow(
                                                  offset: Offset(0, 1),
                                                  blurRadius: 6,
                                                  color: Colors.black54,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    height: 280,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'Add a photo to preview your story',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                const SizedBox(height: 14),

                // This lets the user change the font size.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Font size',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                      ),
                      Slider(
                        value: _textSize.clamp(12.0, 44.0),
                        min: 12,
                        max: 44,
                        activeColor: AppColors.primaryDeep,
                        onChanged: _submitting ? null : (v) => setState(() => _textSize = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // This lets the user pick a text color using simple preset buttons.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Text color',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in const [
                            0xFFFFFFFF,
                            0xFFFFC266,
                            0xFFE8A329,
                            0xFF00E5FF,
                            0xFFB3261E,
                            0xFF000000,
                          ])
                            InkWell(
                              onTap: _submitting ? null : () => setState(() => _textColorValue = c),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 34,
                                width: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(c),
                                  border: Border.all(
                                    color: _textColorValue == c
                                        ? AppColors.primaryDeep
                                        : borderColor,
                                    width: _textColorValue == c ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _overlayController,
                    scrollController: _overlayScrollController,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_submitting,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                    decoration: InputDecoration(
                      hintText: 'Write on your story (text & emojis)',
                      hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: mutedColor,
                            fontWeight: FontWeight.w600,
                          ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _StoryAttachmentChip(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: _submitting ? null : _pickFromGallery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StoryAttachmentChip(
                        icon: Icons.photo_camera_rounded,
                        label: 'Camera',
                        onTap: _submitting ? null : _pickFromCamera,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: CommunityEmojiIconButton(
                        onPressed: _submitting
                            ? null
                            : () => showCommunityEmojiPickerSheet(
                                  context,
                                  textController: _overlayController,
                                  scrollController: _overlayScrollController,
                                ),
                      ),
                    ),
                  ],
                ),

                // This shows selected photos so the user can remove them.
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final file = _images[index];
                        final isActive = index == _activeIndex;
                        return InkWell(
                          onTap: () => setState(() => _activeIndex = index),
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              FutureBuilder<Uint8List>(
                                future: file.readAsBytes(),
                                builder: (context, snap) {
                                  final bytes = snap.data;
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isActive
                                            ? AppColors.primaryDeep
                                            : borderColor,
                                        width: isActive ? 2.5 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: bytes != null && bytes.isNotEmpty
                                          ? Image.memory(
                                              bytes,
                                              width: 112,
                                              height: 112,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 112,
                                              height: 112,
                                              color: isDarkMode
                                                  ? const Color(0xFF1E1E1E)
                                                  : AppColors.surfaceMuted,
                                              alignment: Alignment.center,
                                              child: const CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: (isDarkMode
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.white)
                                      .withValues(alpha: 0.95),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    tooltip: 'Remove',
                                    onPressed: _submitting
                                        ? null
                                        : () {
                                            setState(() {
                                              _images.removeAt(index);
                                              if (_images.isEmpty) {
                                                _activeIndex = 0;
                                              } else {
                                                _activeIndex = _activeIndex.clamp(0, _images.length - 1);
                                              }
                                            });
                                          },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: isDarkMode ? const Color(0xFFF2F2F2) : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                Opacity(
                  opacity: (_submitting || _canSubmit) ? 1 : 0.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE08B14),
                          Color(0xFFF4A32D),
                          Color(0xFFFFC266),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE08B14).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canSubmit ? _submit : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Post Story',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryAttachmentChip extends StatelessWidget {
  const _StoryAttachmentChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF444444) : AppColors.outline;
    final titleColor =
        isDarkMode ? const Color(0xFFF2F2F2) : AppColors.textPrimary;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryDeep, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
