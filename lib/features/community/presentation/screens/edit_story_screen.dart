// This screen lets the story owner edit the full story content.
// The user can change the text, change text style, and manage story photos.

import 'dart:convert';
import 'dart:typed_data';

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/models/community_story.dart';
import 'package:culinary_coach_app/features/community/data/services/community_post_image_encoding.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// This stores one existing story photo (Base64) with a decoded preview.
class _ExistingStoryImage {
  _ExistingStoryImage({required this.base64, required this.bytes});

  // This is the Base64 string saved in the story document.
  final String base64;

  // This is a decoded preview so the user can see the photo immediately.
  final Uint8List bytes;
}

// This is the editor screen for a single story document.
class EditStoryScreen extends StatefulWidget {
  const EditStoryScreen({super.key, required this.story});

  // This is the story we are editing.
  final CommunityStory story;

  @override
  State<EditStoryScreen> createState() => _EditStoryScreenState();
}

class _EditStoryScreenState extends State<EditStoryScreen> {
  final _repo = CommunityRepository();
  final _picker = ImagePicker();
  final _textController = TextEditingController();
  final _textScrollController = ScrollController();

  // This list holds story photos that already exist in Firestore.
  final List<_ExistingStoryImage> _existing = [];

  // This list holds new photos the user adds while editing.
  final List<XFile> _newImages = [];

  // This index tells us which photo we are previewing behind the text editor.
  int _activePhotoIndex = 0;

  // These values control the story text style and position.
  int _textColorValue = 0xFFFFFFFF;
  double _textSize = 20;
  double _textPosX = 0.5;
  double _textPosY = 0.75;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // This starts the editor with the current story text and style values.
    _textController.text = widget.story.textOverlay;
    _textColorValue = widget.story.textColorValue;
    _textSize = widget.story.textSize;
    _textPosX = widget.story.textPosX;
    _textPosY = widget.story.textPosY;

    // This decodes current story photos so we can preview and edit them.
    for (final raw in widget.story.imageBase64List) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      try {
        final bytes = base64Decode(trimmed);
        if (bytes.isEmpty) continue;
        _existing.add(_ExistingStoryImage(base64: trimmed, bytes: bytes));
      } catch (_) {
        // If one photo is corrupted, we skip it to keep the editor stable.
      }
    }

    // This keeps the selected photo index within the available range.
    if (_existing.isEmpty) {
      _activePhotoIndex = 0;
    } else {
      _activePhotoIndex = _activePhotoIndex.clamp(0, _existing.length - 1);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textScrollController.dispose();
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
      // If permission check fails, we still try to open the picker.
      return true;
    }
    return true;
  }

  // This adds more photos to the story (they will be encoded and saved to Firestore).
  Future<void> _addPhotos() async {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open gallery.')),
      );
    }
  }

  // This removes one existing photo from the story.
  void _removeExistingAt(int index) {
    setState(() {
      _existing.removeAt(index);
      _activePhotoIndex =
          _existing.isEmpty ? 0 : _activePhotoIndex.clamp(0, _existing.length - 1);
    });
  }

  // This removes one newly added photo before saving.
  void _removeNewAt(int index) {
    setState(() => _newImages.removeAt(index));
  }

  // This replaces one existing story photo with a new photo picked from the gallery.
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
        _existing[index] = _ExistingStoryImage(base64: encoded, bytes: bytes);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not replace this photo.')),
      );
    }
  }

  // This updates the relative text position when the user drags the text.
  void _applyDragDelta(Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // This converts pixels to 0..1 values so the position works on any screen size.
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    setState(() {
      _textPosX = (_textPosX + dx).clamp(0.0, 1.0);
      _textPosY = (_textPosY + dy).clamp(0.0, 1.0);
    });
  }

  // This saves the edited story photos and text style back to Firestore.
  Future<void> _save() async {
    if (_saving) return;
    if (_existing.isEmpty && _newImages.isEmpty) {
      // This prevents saving a story with no photos.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please keep at least one photo.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // This keeps the Base64 photos the user did not delete.
      final keptBase64 = _existing.map((e) => e.base64).toList();

      // This encodes new photos to Base64 so we can store them in Firestore.
      final newBase64 = _newImages.isEmpty
          ? <String>[]
          : await encodeCommunityPostImagesForFirestore(_newImages);

      // This saves all edited fields into the same story document.
      await _repo.updateStoryFull(
        storyId: widget.story.id,
        textOverlay: _textController.text,
        imageBase64List: [...keptBase64, ...newBase64],
        textColorValue: _textColorValue,
        textSize: _textSize,
        textPosX: _textPosX,
        textPosY: _textPosY,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story updated.')),
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

    // This rebuilds a Color object from the saved ARGB int.
    final overlayColor = Color(_textColorValue);

    // This chooses which photo to show behind the draggable text.
    final previewBytes = (_activePhotoIndex >= 0 && _activePhotoIndex < _existing.length)
        ? _existing[_activePhotoIndex].bytes
        : null;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Edit Story'),
        backgroundColor: pageBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // This is the story preview area where the user can drag the text.
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (previewBytes != null)
                          Image.memory(previewBytes, fit: BoxFit.cover)
                        else
                          Container(color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.surfaceMuted),

                        // This shows the story text at the saved position and style.
                        if (_textController.text.trim().isNotEmpty)
                          Positioned(
                            left: _textPosX * size.width,
                            top: _textPosY * size.height,
                            child: GestureDetector(
                              // This allows the user to drag the text anywhere on the photo.
                              onPanUpdate: (d) => _applyDragDelta(d.delta, size),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _textController.text,
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
                ),
              ),
            ),
            const SizedBox(height: 14),

            // This is the text input card for the story caption.
            Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _textController,
                scrollController: _textScrollController,
                minLines: 2,
                maxLines: 5,
                enabled: !_saving,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                decoration: InputDecoration(
                  hintText: 'Write on your story...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // This lets the user change the font size with a simple slider.
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
                    onChanged: _saving ? null : (v) => setState(() => _textSize = v),
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
                          onTap: _saving ? null : () => setState(() => _textColorValue = c),
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

            // This button adds more photos to the story.
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _addPhotos,
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

            if (_existing.isNotEmpty || _newImages.isNotEmpty) ...[
              const SizedBox(height: 14),
              // This shows existing and new photos so the user can remove or replace them.
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existing.length + _newImages.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final isExisting = index < _existing.length;

                    // This renders the correct thumbnail type (existing vs new).
                    Widget thumb;
                    VoidCallback onRemove;
                    VoidCallback? onReplace;
                    if (isExisting) {
                      final img = _existing[index];
                      thumb = Image.memory(img.bytes, width: 112, height: 112, fit: BoxFit.cover);
                      onRemove = () => _removeExistingAt(index);
                      onReplace = () => _replaceExistingAt(index);
                    } else {
                      final ni = index - _existing.length;
                      final file = _newImages[ni];
                      thumb = FutureBuilder<Uint8List>(
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
                      onReplace = null;
                    }

                    // This highlights the photo that is currently used in the preview.
                    final isActive = isExisting && index == _activePhotoIndex;

                    return InkWell(
                      onTap: isExisting
                          ? () => setState(() => _activePhotoIndex = index)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive ? AppColors.primaryDeep : borderColor,
                                width: isActive ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: thumb,
                            ),
                          ),
                          if (onReplace != null)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Material(
                                color: (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white)
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                                child: InkWell(
                                  onTap: _saving ? null : onReplace,
                                  borderRadius: BorderRadius.circular(999),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primaryDeep),
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
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 18),

            // This saves the updated story back to Firestore.
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

