// Renders a profile picture inside a circle — tries Base64, file, URL, then default icon.
// StatelessWidget: parent passes new data and Flutter rebuilds this widget's build().

import 'package:cached_network_image/cached_network_image.dart';
import 'package:culinary_coach_app/core/utils/platform_file.dart';
import 'package:culinary_coach_app/core/utils/profile_image_base64.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Shared profile picture renderer: Base64 first, optional local file (current user),
/// then legacy URL fallbacks, then default avatar (never a broken image).
class ProfileAvatarImage extends StatelessWidget {
  const ProfileAvatarImage({
    super.key,
    this.profileImageBase64,
    this.fallbackImageBase64,
    this.profileImageLocalPath,
    this.profileImageUrl,
    this.fallbackImageUrl,
    this.overrideImageBytes,
    this.allowLocalFile = false,
    required this.size,
    this.iconColor = Colors.white,
    this.fit = BoxFit.cover,
  });

  final String? profileImageBase64;
  final String? fallbackImageBase64;
  final String? profileImageLocalPath;
  final String? profileImageUrl;
  final String? fallbackImageUrl;
  final Uint8List? overrideImageBytes;
  final bool allowLocalFile;
  final double size;
  final Color iconColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // --- Profile image loading order (first match wins) ---
    // 1) override bytes  2) Firestore Base64  3) local file  4) network URL  5) default icon

    // Instant preview bytes (e.g. right after picking from gallery) — no Firestore wait.
    final preview = overrideImageBytes;
    if (preview != null && preview.isNotEmpty) {
      return _memoryImage(preview);
    }

    // Decode profileImageBase64 string from Firestore into raw image bytes.
    final primaryB64 = tryDecodeProfileImageBase64(profileImageBase64);
    if (primaryB64 != null) {
      return _memoryImage(primaryB64);
    }

    final fallbackB64 = tryDecodeProfileImageBase64(fallbackImageBase64);
    if (fallbackB64 != null) {
      return _memoryImage(fallbackB64);
    }

    // Local file path (current user only) — faster preview before Firestore sync.
    if (allowLocalFile) {
      final local = (profileImageLocalPath ?? '').trim();
      if (local.isNotEmpty) {
        final file = platformFileFromPath(local);
        if (file != null) {
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (_, _, _) => _defaultAvatar(),
          );
        }
      }
    }

    // Legacy/network URL (e.g. Google sign-in photoURL) if no Base64 on the user doc.
    final url = _firstNonEmpty([profileImageUrl, fallbackImageUrl]);
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, _) => _defaultAvatar(),
        errorWidget: (_, _, _) => _defaultAvatar(),
      );
    }

    // Fallback: person icon when no image source is available.
    return _defaultAvatar();
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  // MemoryImage (via Image.memory) displays an image stored in RAM after Base64 decode.
  Widget _memoryImage(Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: fit,
      errorBuilder: (_, _, _) => _defaultAvatar(),
    );
  }

  Widget _defaultAvatar() {
    return Icon(
      Icons.person,
      color: iconColor,
      size: size * 0.55,
    );
  }
}
