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
  // StatefulWidget: we keep the saved values and only write to Firestore on "Post Story".
  final _overlayController = TextEditingController();
  final _overlayScrollController = ScrollController();
  final _picker = ImagePicker();
  final _repo = CommunityRepository();

  // This keeps the single story photo that the user selected.
  XFile? _image;
  Uint8List? _imageBytes;

  // These notifiers update only the preview, so the screen does not flash.
  final ValueNotifier<String> _previewText = ValueNotifier<String>('');
  final ValueNotifier<int> _textColorValue = ValueNotifier<int>(0xFFFFFFFF);
  final ValueNotifier<double> _textSize = ValueNotifier<double>(20);
  final ValueNotifier<Offset> _textPos = ValueNotifier<Offset>(const Offset(0.5, 0.75));

  bool _submitting = false;

  bool get _canSubmit =>
      _imageBytes != null &&
      _imageBytes!.isNotEmpty &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    // This keeps the preview text in sync without rebuilding the whole page.
    _previewText.value = _overlayController.text;
    _overlayController.addListener(() {
      _previewText.value = _overlayController.text;
    });
  }

  @override
  void dispose() {
    _previewText.dispose();
    _textColorValue.dispose();
    _textSize.dispose();
    _textPos.dispose();
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
      // This picks one photo for the story.
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _image = file;
        _imageBytes = bytes;
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
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _image = file;
        _imageBytes = bytes;
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
    final img = _image;
    final bytes = _imageBytes;
    if (img == null || bytes == null || bytes.isEmpty) return;

    setState(() => _submitting = true);
    try {
      // This creates the story and saves the chosen text style values.
      await _repo.createStoryWithStyle(
        image: img,
        textOverlay: _overlayController.text,
        textColorValue: _textColorValue.value,
        textSize: _textSize.value,
        textPosX: _textPos.value.dx,
        textPosY: _textPos.value.dy,
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
                if (_imageBytes != null && _imageBytes!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size =
                              Size(constraints.maxWidth, constraints.maxHeight);
                          return _StoryTextPreview(
                            size: size,
                            imageBytes: _imageBytes!,
                            text: _previewText,
                            textColorValue: _textColorValue,
                            textSize: _textSize,
                            textPos: _textPos,
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

                // This lets the user change the font size without flashing the whole page.
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
                        value: _textSize.value.clamp(12.0, 44.0),
                        min: 12,
                        max: 44,
                        activeColor: AppColors.primaryDeep,
                        onChanged: _submitting ? null : (v) => _textSize.value = v,
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
                              onTap: _submitting ? null : () => _textColorValue.value = c,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 34,
                                width: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(c),
                                  border: Border.all(
                                    color: _textColorValue.value == c
                                        ? AppColors.primaryDeep
                                        : borderColor,
                                    width: _textColorValue.value == c ? 3 : 1,
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

// This widget draws the image and the draggable story text using small rebuilds.
class _StoryTextPreview extends StatelessWidget {
  const _StoryTextPreview({
    required this.size,
    required this.imageBytes,
    required this.text,
    required this.textColorValue,
    required this.textSize,
    required this.textPos,
  });

  // This is the preview area size, so we can convert 0..1 position to pixels.
  final Size size;

  // This is the selected story image.
  final Uint8List imageBytes;

  // These notifiers control the text and style without rebuilding the whole page.
  final ValueNotifier<String> text;
  final ValueNotifier<int> textColorValue;
  final ValueNotifier<double> textSize;
  final ValueNotifier<Offset> textPos;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      // This prevents the preview from repainting the whole screen when it changes.
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(imageBytes, fit: BoxFit.cover),
          ValueListenableBuilder<String>(
            valueListenable: text,
            builder: (context, t, _) {
              final trimmed = t.trim();
              if (trimmed.isEmpty) return const SizedBox.shrink();
              return ValueListenableBuilder<Offset>(
                valueListenable: textPos,
                builder: (context, pos, __) {
                  return ValueListenableBuilder<int>(
                    valueListenable: textColorValue,
                    builder: (context, colorValue, ___) {
                      return ValueListenableBuilder<double>(
                        valueListenable: textSize,
                        builder: (context, fs, ____) {
                          return Positioned(
                            left: pos.dx.clamp(0.0, 1.0) * size.width,
                            top: pos.dy.clamp(0.0, 1.0) * size.height,
                            child: GestureDetector(
                              // This allows dragging the text without calling setState on the page.
                              onPanUpdate: (d) {
                                final dx = d.delta.dx / size.width;
                                final dy = d.delta.dy / size.height;
                                final next = Offset(
                                  (pos.dx + dx).clamp(0.0, 1.0),
                                  (pos.dy + dy).clamp(0.0, 1.0),
                                );
                                textPos.value = next;
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
                                  trimmed,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(colorValue),
                                    fontSize: fs,
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
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

