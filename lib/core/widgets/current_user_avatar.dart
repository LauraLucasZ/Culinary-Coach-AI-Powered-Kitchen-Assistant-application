import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/core/utils/platform_file.dart';
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

    Widget resolveFromFields({
      required String? imageUrl,
      required String? localPath,
    }) {
      final url = (imageUrl ?? '').trim();
      final local = (localPath ?? '').trim();

      if (overrideImageBytes != null && overrideImageBytes!.isNotEmpty) {
        return buildShell(
          child: Image.memory(overrideImageBytes!, fit: BoxFit.cover),
        );
      }

      final effectiveUrl = (overrideImageUrl ?? url).trim();
      final effectiveLocal = (overrideLocalPath ?? local).trim();
      final file = effectiveLocal.isNotEmpty
          ? platformFileFromPath(effectiveLocal)
          : null;

      if (file != null) {
        return buildShell(child: Image.file(file, fit: BoxFit.cover));
      }
      if (effectiveUrl.isNotEmpty) {
        return buildShell(child: Image.network(effectiveUrl, fit: BoxFit.cover));
      }
      return buildShell(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: size * 0.55,
        ),
      );
    }

    if (user == null) {
      return resolveFromFields(imageUrl: null, localPath: null);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final url = (data?['profileImageUrl'] as String?)?.trim();
        final local = (data?['profileImageLocalPath'] as String?)?.trim();
        final authUrl = (user.photoURL ?? '').trim();

        return resolveFromFields(
          imageUrl: (url != null && url.isNotEmpty) ? url : authUrl,
          localPath: local,
        );
      },
    );
  }
}

