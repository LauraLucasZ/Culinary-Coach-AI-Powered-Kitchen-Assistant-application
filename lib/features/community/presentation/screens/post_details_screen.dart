// This screen shows a single post when we open it from a notification.
// It listens to Firestore so the UI updates after edits, likes, or comments.

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_post_card.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/comments_sheet.dart';
import 'package:flutter/material.dart';

// This is a simple "post details" page that renders one post card.
class PostDetailsScreen extends StatefulWidget {
  const PostDetailsScreen({
    super.key,
    required this.postId,
    this.openCommentsOnLoad = false,
  });

  // This is the Firestore document id in the `posts` collection.
  final String postId;

  final bool openCommentsOnLoad;

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  bool _openedComments = false;

  Future<void> _maybeOpenComments() async {
    if (_openedComments) return;
    if (!widget.openCommentsOnLoad) return;
    _openedComments = true;
    if (!mounted) return;
    await CommentsSheet.show(context, postId: widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // This matches the dark page background used in the Community tab.
    final pageBg =
        isDarkMode ? const Color(0xFF121212) : AppColors.background;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        // This keeps the existing app bar style and only changes readable colors in dark mode.
        title: const Text('Post'),
        backgroundColor: pageBg,
      ),
      body: StreamBuilder(
        // This watches the post document, so changes appear without refreshing.
        stream: repo.watchPostById(widget.postId),
        builder: (context, snap) {
          final post = snap.data;

          // This shows a friendly message if the post was deleted or is missing.
          if (post == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This content is no longer available.',
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

          // This opens the comments sheet for comment/reply notifications after the post is loaded.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeOpenComments();
          });

          // This keeps the current community post UI by reusing the same post card widget.
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              CommunityPostCard(post: post),
            ],
          );
        },
      ),
    );
  }
}

