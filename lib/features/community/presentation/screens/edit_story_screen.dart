// This screen lets the story owner edit the full story content.
// The user can change the text, change text style, and manage story photos.

import 'dart:convert';
import 'dart:typed_data';

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/models/community_story.dart';
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

  // This keeps the single story photo (it can be replaced or deleted).
  _ExistingStoryImage? _photo;

  // These notifiers update only the preview, so the screen does not flash.
  final ValueNotifier<String> _previewText = ValueNotifier<String>('');
  final ValueNotifier<int> _textColorValue = ValueNotifier<int>(0xFFFFFFFF);
  final ValueNotifier<double> _textSize = ValueNotifier<double>(20);
  final ValueNotifier<Offset> _textPos =
      ValueNotifier<Offset>(const Offset(0.5, 0.75));

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // This starts the editor with the current story text and style values.
    _textController.text = widget.story.textOverlay;
    _textColorValue.value = widget.story.textColorValue;
    _textSize.value = widget.story.textSize;
    _textPos.value = Offset(widget.story.textPosX, widget.story.textPosY);

    // This keeps the preview text in sync without rebuilding the whole page.
    _previewText.value = _textController.text;
    _textController.addListener(() {
      _previewText.value = _textController.text;
    });

    // This decodes the saved story photo (we keep only one photo per story).
    final raw = widget.story.imageBase64.trim().isNotEmpty
        ? widget.story.imageBase64
        : (widget.story.imageBase64List.isNotEmpty
            ? widget.story.imageBase64List.first
            : '');
    if (raw.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(raw.trim());
        if (bytes.isNotEmpty) {
          _photo = _ExistingStoryImage(base64: raw.trim(), bytes: bytes);
        }
      } catch (_) {
        // If the photo is corrupted, we keep it empty so the user can add a new one.
      }
    }
  }

  @override
  void dispose() {
    _previewText.dispose();
    _textColorValue.dispose();
    _textSize.dispose();
    _textPos.dispose();
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

  // This picks a story photo if none exists yet.
  Future<void> _addPhoto() async {
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
        _photo = _ExistingStoryImage(base64: base64Encode(bytes), bytes: bytes);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open gallery.')),
      );
    }
  }

  // This removes the photo that the user no longer wants in the story.
  void _removePhoto() {
    setState(() => _photo = null);
  }

  // This replaces the current story photo with a new one.
  Future<void> _replacePhoto() async {
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
        _photo = _ExistingStoryImage(base64: encoded, bytes: bytes);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not replace this photo.')),
      );
    }
  }

  // This saves the edited story photos and text style back to Firestore.
  Future<void> _save() async {
    if (_saving) return;
    final base64 = _photo?.base64 ?? '';

    setState(() => _saving = true);
    try {
      // This saves all edited fields into the same story document.
      await _repo.updateStoryFull(
        storyId: widget.story.id,
        textOverlay: _textController.text,
        imageBase64: base64,
        textColorValue: _textColorValue.value,
        textSize: _textSize.value,
        textPosX: _textPos.value.dx,
        textPosY: _textPos.value.dy,
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

    // This chooses which photo to show behind the draggable text.
    final previewBytes = _photo?.bytes;

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
                    if (previewBytes == null) {
                      return Container(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.surfaceMuted,
                        alignment: Alignment.center,
                        child: Text(
                          'No photo selected',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      );
                    }
                    return _StoryTextPreview(
                      size: size,
                      imageBytes: previewBytes,
                      text: _previewText,
                      textColorValue: _textColorValue,
                      textSize: _textSize,
                      textPos: _textPos,
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
                    value: _textSize.value.clamp(12.0, 44.0),
                    min: 12,
                    max: 44,
                    activeColor: AppColors.primaryDeep,
                    onChanged: _saving ? null : (v) => _textSize.value = v,
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
                          onTap: _saving ? null : () => _textColorValue.value = c,
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

            // This button lets the user add a photo if none exists.
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _addPhoto,
                icon: const Icon(Icons.photo_library_rounded, color: AppColors.primaryDeep),
                label: Text(
                  'Add Photo',
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

            // This shows quick actions for the single story photo.
            if (_photo != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _replacePhoto,
                      icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryDeep),
                      label: Text(
                        'Replace photo',
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E)),
                      label: Text(
                        'Delete photo',
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
                ],
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

// This widget draws the story preview using small rebuilds.
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


