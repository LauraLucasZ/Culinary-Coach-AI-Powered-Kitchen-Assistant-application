import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/core/utils/profile_image_base64.dart';
import 'package:culinary_coach_app/core/widgets/profile_avatar_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class CurrentUserAvatar extends StatelessWidget {
  const CurrentUserAvatar({
    super.key,
    this.size = 40,
    this.onTap,
    this.borderColor,
    this.borderWidth = 2,
    this.backgroundColor = const Color(0xFFD28E18),
    this.overrideImageUrl,
    this.overrideLocalPath,
    this.overrideImageBytes,
    this.overrideProfileImageBase64,
    this.isLoadingOverlay = false,
  });

  final double size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final Color backgroundColor;

  /// Use these when you need instant preview (e.g. right after picking image).
  final String? overrideImageUrl;
  final String? overrideLocalPath;
  final Uint8List? overrideImageBytes;
  final String? overrideProfileImageBase64;
  final bool isLoadingOverlay;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final effectiveBorder =
        borderColor ?? Colors.white.withValues(alpha: 0.65);

    Widget buildShell({required Widget child}) {
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

      final withOverlay = Stack(
        alignment: Alignment.center,
        children: [
          content,
          if (isLoadingOverlay)
            Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.25),
              ),
              child: const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      );

      if (onTap == null) return withOverlay;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: withOverlay,
      );
    }

    Widget avatarContent({
      required String? profileImageBase64,
      required String? localPath,
      required String? imageUrl,
    }) {
      final effectiveB64 = () {
        final o = overrideProfileImageBase64?.trim();
        if (o != null && o.isNotEmpty) return o;
        final live = profileImageBase64?.trim();
        if (live != null && live.isNotEmpty) return live;
        return null;
      }();

      return ProfileAvatarImage(
        profileImageBase64: effectiveB64,
        profileImageLocalPath: (overrideLocalPath ?? localPath),
        profileImageUrl: (overrideImageUrl ?? imageUrl),
        overrideImageBytes: overrideImageBytes,
        allowLocalFile: true,
        size: size,
        iconColor: Colors.white,
      );
    }

    if (user == null) {
      return buildShell(
        child: avatarContent(
          profileImageBase64: overrideProfileImageBase64,
          localPath: overrideLocalPath,
          imageUrl: overrideImageUrl,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final b64 = readProfileImageBase64(data);
        final local = (data?['profileImageLocalPath'] as String?)?.trim();
        final url = (data?['profileImageUrl'] as String?)?.trim();
        final authUrl = (user.photoURL ?? '').trim();

        return buildShell(
          child: avatarContent(
            profileImageBase64: b64,
            localPath: local,
            imageUrl: (url != null && url.isNotEmpty) ? url : authUrl,
          ),
        );
      },
    );
  }
}
