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
    final preview = overrideImageBytes;
    if (preview != null && preview.isNotEmpty) {
      return _memoryImage(preview);
    }

    final primaryB64 = tryDecodeProfileImageBase64(profileImageBase64);
    if (primaryB64 != null) {
      return _memoryImage(primaryB64);
    }

    final fallbackB64 = tryDecodeProfileImageBase64(fallbackImageBase64);
    if (fallbackB64 != null) {
      return _memoryImage(fallbackB64);
    }

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

    final url = _firstNonEmpty([profileImageUrl, fallbackImageUrl]);
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, _) => _defaultAvatar(),
        errorWidget: (_, _, _) => _defaultAvatar(),
      );
    }

    return _defaultAvatar();
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

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
