// List of follow/like/comment notifications for the current user.
// StreamBuilder on Firestore notifications subcollection; tap row opens profile.

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/models/community_notification.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/post_details_screen.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/story_viewer_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';

// Lists follow/like/comment alerts; tapping opens the sender’s profile.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

// StatefulWidget: runs mark-all-read once when screen opens (didChangeDependencies).
class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _marked = false;

  // This checks if the notification is related to a post (like/comment/repost).
  bool _isPostNotificationType(String type) {
    final t = type.trim();
    return t == 'post_like' || t == 'comment' || t == 'reply' || t == 'post_repost';
  }

  // This checks if the notification is related to a story (like on a story).
  bool _isStoryNotificationType(String type) {
    return type.trim() == 'story_like';
  }

  // This opens the right screen based on the notification type and ids.
  Future<void> _openNotificationTarget(
    BuildContext context,
    CommunityRepository repo, {
    required CommunityNotification n,
  }) async {
    // This keeps the behavior safe if the widget gets disposed during async work.
    if (!context.mounted) return;

    final type = n.type.trim();

    // This opens the profile of the user who followed me.
    if (type == 'follow') {
      final uid = (n.senderUserId ?? '').trim().isNotEmpty
          ? n.senderUserId!.trim()
          : n.fromUid.trim();
      if (uid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user is not available anymore.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProfileScreen(userId: uid)),
      );
      return;
    }

    // This opens the exact post for like/comment/repost notifications.
    if (_isPostNotificationType(type)) {
      final postId = (n.postId ?? '').trim();
      if (postId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This post is not available anymore.')),
        );
        return;
      }

      // This checks if the post still exists before navigating.
      final post = await repo.getPostById(postId);
      if (!context.mounted) return;
      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This post was deleted.')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PostDetailsScreen(postId: postId)),
      );
      return;
    }

    // This opens the exact story for story-like notifications.
    if (_isStoryNotificationType(type)) {
      final storyId = (n.storyId ?? '').trim();
      if (storyId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This story is not available anymore.')),
        );
        return;
      }

      // This checks if the story still exists before navigating.
      final story = await repo.getStoryById(storyId);
      if (!context.mounted) return;
      if (story == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This story was deleted or expired.')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StoryViewerScreen(stories: [story], initialIndex: 0),
        ),
      );
      return;
    }

    // This shows a simple message if the notification type is unknown.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This notification cannot be opened.')),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_marked) return;
    _marked = true;
    // One-time when screen opens — marks notifications read in Firestore.
    CommunityRepository().markAllNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
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
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder(
        // Live notifications for the signed-in user from Firestore.
        stream: repo.watchNotifications(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (snapshot.connectionState == ConnectionState.waiting &&
              items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDeep),
            );
          }
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No notifications yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }
          // ListView builds one row per notification document from Firestore.
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = items[i];
              // InkWell: tap row → opens the post/story/profile based on notification type.
              return InkWell(
                onTap: () async {
                  await _openNotificationTarget(context, repo, n: n);
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AppDefaultUserAvatarByUid(
                        userId: n.fromUid.trim(),
                        fallbackImageUrl: n.fromProfileImageUrl,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.message.isEmpty ? 'Notification' : n.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _timeAgo(n.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

