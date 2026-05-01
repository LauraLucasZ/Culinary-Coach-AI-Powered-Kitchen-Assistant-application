import 'package:cached_network_image/cached_network_image.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/models/community_post.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/comments_sheet.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({required this.post, super.key});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(
            authorName: post.authorName,
            authorProfileImageUrl: post.authorProfileImageUrl,
            createdAt: post.createdAt,
            onAuthorTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(userId: post.authorId),
                ),
              );
            },
          ),
          if (post.isRepost) ...[
            const SizedBox(height: 10),
            _RepostPill(),
          ],
          if (post.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.caption,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ],
          if ((post.recipeTitle ?? '').trim().isNotEmpty ||
              (post.cookingTime ?? '').trim().isNotEmpty ||
              post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((post.recipeTitle ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.receipt_long_rounded,
                    label: post.recipeTitle!.trim(),
                  ),
                if ((post.cookingTime ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: post.cookingTime!.trim(),
                  ),
                for (final tag in post.tags.take(4))
                  _MetaChip(icon: Icons.sell_rounded, label: tag),
              ],
            ),
          ],
          if ((post.imageUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => Container(
                    color: AppColors.surfaceMuted,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceMuted,
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: currentUid == null
                    ? _ActionPill(
                        icon: Icons.favorite_border_rounded,
                        label: _formatCount(post.likeCount),
                        onTap: null,
                      )
                    : StreamBuilder<bool>(
                        stream:
                            repo.watchHasLiked(postId: post.id, uid: currentUid),
                        builder: (context, snap) {
                          final hasLiked = snap.data ?? false;
                          return _ActionPill(
                            icon: hasLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor:
                                hasLiked ? const Color(0xFFB3261E) : null,
                            label: _formatCount(post.likeCount),
                            onTap: () => repo.toggleLike(postId: post.id),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: Icons.mode_comment_outlined,
                  label: _formatCount(post.commentCount),
                  onTap: () => CommentsSheet.show(
                    context,
                    postId: post.id,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: Icons.repeat_rounded,
                  label: _formatCount(post.repostCount),
                  onTap: currentUid == null
                      ? null
                      : () => repo.repost(original: post),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatCount(int v) => v.toString();
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.authorName,
    required this.authorProfileImageUrl,
    required this.createdAt,
    required this.onAuthorTap,
  });

  final String authorName;
  final String? authorProfileImageUrl;
  final DateTime createdAt;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onAuthorTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outline),
              color: AppColors.surfaceMuted,
              image: (authorProfileImageUrl ?? '').trim().isEmpty
                  ? null
                  : DecorationImage(
                      image: CachedNetworkImageProvider(authorProfileImageUrl!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: (authorProfileImageUrl ?? '').trim().isEmpty
                ? const Icon(Icons.person_rounded, color: AppColors.textMuted)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeAgo(createdAt),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDeep),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor ?? AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepostPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded, size: 16, color: AppColors.primaryDeep),
          const SizedBox(width: 6),
          Text(
            'Repost',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

