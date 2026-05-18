// Another user's avatar by uid — StreamBuilder listens to their users/{uid} document.
// Shows updated profileImageBase64 when they change their photo without restarting the app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/core/utils/profile_image_base64.dart';
import 'package:culinary_coach_app/core/widgets/profile_avatar_image.dart';
import 'package:flutter/material.dart';

/// Avatar that follows the latest profile image from the `users/{userId}` doc.
class UserAvatarByUid extends StatelessWidget {
  const UserAvatarByUid({
    super.key,
    required this.userId,
    this.fallbackImageUrl,
    this.fallbackImageBase64,
    this.size = 40,
    this.onTap,
    this.borderColor,
    this.borderWidth = 2,
    this.backgroundColor = const Color(0xFFD28E18),
    this.iconColor = Colors.white,
    this.heroTag,
  });

  final String userId;
  final String? fallbackImageUrl;
  final String? fallbackImageBase64;
  final double size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final Color backgroundColor;
  final Color iconColor;

  /// When set, wraps the avatar so hero flights are unique per user (e.g. `profile-avatar-$userId`).
  final String? heroTag;

  static String? _readUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    String? rs(String k) {
      final v = data[k];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return rs('profileImageUrl') ??
        rs('photoUrl') ??
        rs('photoURL') ??
        rs('avatarUrl');
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId.trim();
    final effectiveBorder =
        borderColor ?? Colors.white.withValues(alpha: 0.65);
    final fbUrl = (fallbackImageUrl ?? '').trim();
    final fbB64 = (fallbackImageBase64 ?? '').trim();

    // --- Optional Hero animation when navigating to profile ---
    Widget wrapHero(Widget child) {
      final tag = heroTag?.trim();
      if (tag == null || tag.isEmpty) return child;
      return Hero(
        tag: tag,
        child: Material(type: MaterialType.transparency, child: child),
      );
    }

    // --- Circular avatar shell (same pattern as CurrentUserAvatar) ---
    Widget shell(Widget child) {
      final content = Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(color: effectiveBorder, width: borderWidth),
        ),
        child: ClipOval(child: child),
      );
      if (onTap == null) return content;
      // InkWell handles tap — often Navigator.push to ProfileScreen.
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      );
    }

    if (uid.isEmpty) {
      return wrapHero(
        shell(
          ProfileAvatarImage(
            fallbackImageBase64: fbB64.isEmpty ? null : fbB64,
            fallbackImageUrl: fbUrl.isEmpty ? null : fbUrl,
            size: size,
            iconColor: iconColor,
          ),
        ),
      );
    }

    return wrapHero(
      // StreamBuilder reads another user's profile fields (including profileImageBase64).
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          return shell(
            ProfileAvatarImage(
              profileImageBase64: readProfileImageBase64(data),
              fallbackImageBase64: fbB64.isEmpty ? null : fbB64,
              profileImageUrl: _readUrl(data),
              fallbackImageUrl: fbUrl.isEmpty ? null : fbUrl,
              allowLocalFile: false,
              size: size,
              iconColor: iconColor,
            ),
          );
        },
      ),
    );
  }
}
