// This screen lets the post owner edit the full post content.
// The user can change the caption and manage the post photos, then save to Firestore.

import 'dart:convert';
import 'dart:typed_data';

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/models/community_post.dart';
import 'package:culinary_coach_app/features/community/data/services/community_post_image_encoding.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// This is a small helper object for showing existing Base64 images in the editor.
class _ExistingBase64Image {
  _ExistingBase64Image({required this.base64, required this.bytes});

  // This is the exact Base64 string stored in Firestore.
  final String base64;

  // This is a decoded preview so we can render it with Image.memory.
  final Uint8List bytes;
}

// This screen edits an existing post (caption + photos).
class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  // This is the post we are editing (it already includes caption and image lists).
  final CommunityPost post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _repo = CommunityRepository();
  final _captionController = TextEditingController();
  final _captionScrollController = ScrollController();
  final _picker = ImagePicker();

  // This holds the existing Base64 photos (the user can remove some of them).
  final List<_ExistingBase64Image> _existingBase64 = [];

  // This holds new photos the user adds while editing.
  final List<XFile> _newImages = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // This starts the editor with the current post caption.
    _captionController.text = widget.post.caption;

    // This decodes current Base64 images so the user can preview/remove them.
    for (final raw in widget.post.imageBase64List) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      try {
        final bytes = base64Decode(trimmed);
        if (bytes.isEmpty) continue;
        _existingBase64.add(_ExistingBase64Image(base64: trimmed, bytes: bytes));
      } catch (_) {
        // If one image is corrupted, we just skip it to avoid crashing the editor.
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionScrollController.dispose();
    super.dispose();
  }

  // This checks/requests permission so we can pick images from the gallery.
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
      // If permission check fails, we still try to open the picker (some devices allow it).
      return true;
    }
    return true;
  }

  // This adds new images to the post (they will be encoded and saved to Firestore).
  Future<void> _pickMoreImages() async {
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
      final files = await _picker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (files.isEmpty) return;
      if (!mounted) return;
      setState(() => _newImages.addAll(files));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  // This lets the user replace one existing Base64 photo with a new gallery photo.
  Future<void> _replaceExistingAt(int index) async {
    final ok = await _ensureGalleryPermission();
    if (!ok || !mounted) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final encoded = base64Encode(bytes);
      setState(() {
        _existingBase64[index] =
            _ExistingBase64Image(base64: encoded, bytes: bytes);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not replace this photo.')),
      );
    }
  }

  // This removes one existing Base64 photo from the "kept" list.
  void _removeExistingAt(int index) {
    setState(() => _existingBase64.removeAt(index));
  }

  // This removes one newly added photo before saving.
  void _removeNewAt(int index) {
    setState(() => _newImages.removeAt(index));
  }

  // This sends the edited caption and photo lists to Firestore.
  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      // This keeps the original Base64 images that the user did not delete.
      final keptBase64 = _existingBase64.map((e) => e.base64).toList();

      // This encodes any new photos the user picked into Base64.
      final newBase64 = _newImages.isEmpty
          ? <String>[]
          : await encodeCommunityPostImagesForFirestore(_newImages);

      // This saves the merged list of photos and the new caption into the post document.
      await _repo.updatePostFull(
        postId: widget.post.id,
        caption: _captionController.text,
        imageUrls: widget.post.imageUrls,
        imageBase64List: [...keptBase64, ...newBase64],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save changes: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // This matches the Community dark mode look, but keeps light mode unchanged.
    final pageBg = isDarkMode ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF444444) : AppColors.outline;
    final titleColor = isDarkMode ? const Color(0xFFF2F2F2) : AppColors.textPrimary;
    final mutedColor = isDarkMode ? const Color(0xFF9A9A9A) : AppColors.textMuted;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: pageBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // This is the caption editor card.
            Container(
              constraints: const BoxConstraints(minHeight: 220),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _captionController,
                scrollController: _captionScrollController,
                minLines: 7,
                maxLines: 14,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_saving,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                decoration: InputDecoration(
                  hintText: 'Update your post...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // This button lets the user add more photos to the post.
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickMoreImages,
                icon: const Icon(Icons.photo_library_rounded, color: AppColors.primaryDeep),
                label: Text(
                  'Add Photos',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  backgroundColor: cardColor,
                ),
              ),
            ),

            if (_existingBase64.isNotEmpty || _newImages.isNotEmpty) ...[
              const SizedBox(height: 14),
              // This shows a combined preview of existing and new photos.
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingBase64.length + _newImages.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final isExisting = index < _existingBase64.length;

                    // This reads the correct preview image based on whether it is old or new.
                    Widget preview;
                    VoidCallback onRemove;
                    if (isExisting) {
                      final img = _existingBase64[index];
                      preview = Image.memory(img.bytes, width: 112, height: 112, fit: BoxFit.cover);
                      onRemove = () => _removeExistingAt(index);
                    } else {
                      final ni = index - _existingBase64.length;
                      final file = _newImages[ni];
                      preview = FutureBuilder<Uint8List>(
                        future: file.readAsBytes(),
                        builder: (context, snap) {
                          final bytes = snap.data;
                          if (bytes == null || bytes.isEmpty) {
                            return Container(
                              width: 112,
                              height: 112,
                              color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.surfaceMuted,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return Image.memory(bytes, width: 112, height: 112, fit: BoxFit.cover);
                        },
                      );
                      onRemove = () => _removeNewAt(ni);
                    }

                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: preview,
                        ),
                      // This opens a small menu so the user can replace an existing photo quickly.
                      if (isExisting)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Material(
                            color: (isDarkMode
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white)
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: _saving ? null : () => _replaceExistingAt(index),
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                      color: AppColors.primaryDeep,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Replace',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: isDarkMode
                                                ? const Color(0xFFF2F2F2)
                                                : AppColors.textPrimary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white)
                                .withValues(alpha: 0.95),
                            shape: const CircleBorder(),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Remove',
                              onPressed: _saving ? null : onRemove,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDarkMode ? const Color(0xFFF2F2F2) : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 18),

            // This saves the updated post back to Firestore.
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

