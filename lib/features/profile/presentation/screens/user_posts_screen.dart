// All community posts by one user — opened from Profile "View more posts".
// StreamBuilder on posts where authorId matches; ListView of CommunityPostCard widgets.

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_post_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Full list of community posts for a profile user (self or others).
class UserPostsScreen extends StatelessWidget {
  const UserPostsScreen({
    super.key,
    required this.targetUid,
    required this.posterDisplayName,
  });

  final String targetUid;
  /// Used for the app bar when viewing someone else's posts (first name or short name).
  final String posterDisplayName;

  String get _title {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me != null && me == targetUid) return 'My Posts';
    final hint = posterDisplayName.trim();
    if (hint.isEmpty) return 'Posts';
    return "$hint's Posts";
  }

  // StatelessWidget: this screen has no local state; StreamBuilder drives rebuilds.
  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();

    // Scaffold = page shell (AppBar + body widget tree).
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Navigator.maybePop returns to ProfileScreen without crashing if stack is empty.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        centerTitle: true,
      ),
      // --- Real-time Firestore posts stream ---
      // StreamBuilder rebuilds whenever posts in Firestore change for this authorId.
      body: StreamBuilder(
        stream: repo.watchPostsForUser(targetUid),
        builder: (context, snap) {
          final posts = snap.data ?? const [];
          // Waiting state: show spinner until first snapshot arrives.
          if (snap.connectionState == ConnectionState.waiting && posts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDeep),
            );
          }
          // Empty state: Column centers icon + message vertically.
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.post_add_rounded,
                      size: 48,
                      color: AppColors.primaryDeep.withValues(alpha: 0.75),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No posts yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }
          // ListView builds scrollable post cards (reuses CommunityPostCard widget).
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => CommunityPostCard(post: posts[i]),
          );
        },
      ),
    );
  }
}
