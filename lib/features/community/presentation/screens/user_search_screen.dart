// Search users by name, follow/unfollow, open their profile with Navigator.
// StatefulWidget filters a Firestore user list as you type in the search field.

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/app_primary_button.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Search users by name; follow/unfollow and open profiles from results.
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  // setState on each keystroke updates _query and rebuilds the filtered ListView.
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final viewerUid = FirebaseAuth.instance.currentUser?.uid;
    final q = _query.trim().toLowerCase();
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

    // Column: search TextField on top, Expanded StreamBuilder list below.
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Search Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: mutedColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      cursorColor: AppColors.primaryDeep,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                      decoration: InputDecoration(
                        hintText: 'Search users',
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w600,
                            ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      // setState rebuilds list with filtered users as you type.
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() {
                        _controller.clear();
                        _query = '';
                      }),
                      icon: Icon(Icons.close_rounded, color: mutedColor),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              // Load users from Firestore, then filter locally by search text.
              stream: repo.watchAllUsers(limit: 120),
              builder: (context, snapshot) {
                var users = snapshot.data ?? const [];
                debugPrint('Loaded users count: ${users.length}');
                debugPrint('Current uid: $viewerUid');
                if (snapshot.hasError) {
                  debugPrint('User query error: ${snapshot.error}');
                }
                if (viewerUid != null) {
                  users = users.where((u) => u.uid != viewerUid).toList();
                }
                if (q.isNotEmpty) {
                  users = users
                      .where(
                        (u) => u.displayName.toLowerCase().contains(q),
                      )
                      .toList();
                }
                debugPrint('Filtered users count: ${users.length}');

                if (snapshot.hasError) {
                  return const _HintEmpty(
                    title: 'Couldn’t load users',
                    subtitle: 'Please check your connection and try again.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    users.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDeep,
                    ),
                  );
                }
                if (users.isEmpty) {
                  if (q.isEmpty) {
                    return const _HintEmpty(
                      title: 'No other users yet',
                      subtitle: 'Invite friends to join SmartChef Community.',
                    );
                  }
                  return const _HintEmpty(
                    title: 'No users found',
                    subtitle: 'Try a different name.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(userId: u.uid),
                          ),
                        );
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
                              userId: u.uid,
                              fallbackImageUrl: u.profileImageUrl,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: titleColor,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    u.badge,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: secondaryColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (viewerUid == null)
                              const _SmallPill(
                                icon: Icons.person_rounded,
                                label: 'User',
                              )
                            else
                              StreamBuilder<bool>(
                                stream: repo.watchIsFollowing(
                                  viewerUid: viewerUid,
                                  targetUid: u.uid,
                                ),
                                builder: (context, snap) {
                                  final following = snap.data ?? false;
                                  return SizedBox(
                                    height: 40,
                                    width: 140,
                                    child: AppPrimaryButton(
                                      label: following ? 'Following' : 'Follow',
                                      isOutlined: following,
                                      icon: following
                                          ? Icons.check_rounded
                                          : Icons.person_add_alt_rounded,
                                      onPressed: () async {
                                        if (following) {
                                          await repo.unfollowUser(
                                            targetUid: u.uid,
                                          );
                                        } else {
                                          await repo.followUser(targetUid: u.uid);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDarkMode ? const Color(0xFF444444) : AppColors.outline;
    final pillBg =
        isDarkMode ? const Color(0xFF1E1E1E) : AppColors.surfaceMuted;
    final labelColor =
        isDarkMode ? const Color(0xFFBFBFBF) : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDeep),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _HintEmpty extends StatelessWidget {
  const _HintEmpty({
    this.title = 'Search users',
    this.subtitle = 'Type a name like “Sara” or “Ahmed”.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF444444) : AppColors.outline;
    final titleColor =
        isDarkMode ? const Color(0xFFF2F2F2) : AppColors.textPrimary;
    final subtitleColor =
        isDarkMode ? const Color(0xFFBFBFBF) : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

