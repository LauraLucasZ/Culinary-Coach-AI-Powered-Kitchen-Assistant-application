// All your past stories (including expired) — opened from Profile → Stories Archive.
// StreamBuilder loads from Firestore; thumbnails decode Base64 to show preview images.

import 'dart:convert';
import 'dart:typed_data';

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/models/community_story.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/story_viewer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Profile screen: grid of your past stories (opened from profile actions).
class StoriesArchiveScreen extends StatelessWidget {
  const StoriesArchiveScreen({super.key});

  // Decode story thumbnail Base64 from Firestore for the list preview image.
  Uint8List? _thumb(String raw) {
    try {
      final b = base64Decode(raw.trim());
      if (b.isEmpty) return null;
      return b;
    } catch (_) {
      return null;
    }
  }

  String _preview(String text) {
    final t = text.trim();
    if (t.isEmpty) return '—';
    if (t.length <= 80) return t;
    return '${t.substring(0, 80)}…';
  }

  String _dateLabel(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
        appBar: AppBar(title: const Text('Stories Archive')),
        body: const Center(
          child: Text(
            'Sign in to view your archive.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final repo = CommunityRepository();

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Stories Archive'),
        backgroundColor: pageBg,
      ),
      body: StreamBuilder<List<CommunityStory>>(
        // Archived/expired stories for the signed-in user from Firestore.
        stream: repo.watchMyStoriesArchive(user.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load stories.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }
          final items = snap.data ?? const <CommunityStory>[];
          if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDeep),
            );
          }
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No stories yet. Create one from the Community tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            );
          }

          // ListView of archived stories; thumb uses Base64 decode → MemoryImage in Row.
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final s = items[i];
              final thumb = _thumb(s.archiveThumbBase64);
              return Material(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    // Navigator opens full-screen StoryViewerScreen for this story.
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryViewerScreen(
                          stories: [s],
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: thumb != null
                                ? Image.memory(thumb, fit: BoxFit.cover)
                                : Container(
                                    color: isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : AppColors.surfaceMuted,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.image_not_supported_outlined),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dateLabel(s.createdAt),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: mutedColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _preview(s.textOverlay),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: titleColor,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    size: 16,
                                    color: AppColors.primaryDeep,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${s.likeCount}',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: secondaryColor,
                                        ),
                                  ),
                                  if (!s.isActiveAt(DateTime.now())) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? const Color(0xFF1E1E1E)
                                            : AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isDarkMode
                                            ? Border.all(color: borderColor)
                                            : null,
                                      ),
                                      child: Text(
                                        'Expired',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: mutedColor,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
