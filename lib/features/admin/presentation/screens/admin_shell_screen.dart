// lib/features/admin/presentation/screens/admin_shell_screen.dart
// Admin Shell Screen - Main container screen that wraps the admin dashboard with hero header and navigation controls

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:culinary_coach_app/features/auth/data/services/auth_service.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AdminShellScreen extends StatefulWidget {
  // Admin shell screen with optional initial tab index
  const AdminShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  // Dark mode state management for the entire admin panel
  bool _isDarkMode = false;

  // Toggle between light and dark theme modes
  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  // Handle admin logout with confirmation dialog
  Future<void> _logout() async {
    // Show confirmation dialog before logging out
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFCF7E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF3A2214),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout from Admin Panel?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : const Color(0xFF8B7355),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _isDarkMode ? Colors.white60 : const Color(0xFF8B7355))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    // If user confirmed logout, sign out and navigate to login screen
    if (confirm == true && mounted) {
      final authService = AuthService();
      await authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dynamic background color based on theme mode
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF3E8DF),
      body: Column(
        children: [
          // Admin hero header with user info and action buttons
          _AdminHero(
            isDarkMode: _isDarkMode,
            onProfileTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            onSettingsTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            onDarkModeToggle: _toggleDarkMode,
            onLogout: _logout,
          ),
          // Main dashboard content area (expands to fill remaining space)
          Expanded(
            child: AdminDashboardScreen(isDarkMode: _isDarkMode),
          ),
        ],
      ),
    );
  }
}

// Admin Hero Header Widget - Displays admin info, avatar, and action buttons with decorative background
class _AdminHero extends StatelessWidget {
  const _AdminHero({
    required this.isDarkMode,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onDarkModeToggle,
    required this.onLogout,
  });

  final bool isDarkMode;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onDarkModeToggle;
  final VoidCallback onLogout;

  // Extract first name from full display name for greeting
  String? _extractFirstName(String? displayName) {
    final value = (displayName ?? '').trim();
    if (value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final topInset = MediaQuery.of(context).padding.top;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompact = isLandscape;

    String displayName = 'Admin';
    String? profileImageUrl;
    String? profileImageLocalPath;

    // Fetch user data from Firestore if user is logged in
    if (currentUser != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasData && userSnapshot.data != null) {
            final data = userSnapshot.data!.data() as Map<String, dynamic>?;
            // Priority: Firestore firstName > Firebase display name > default 'Admin'
            final firstName = (data?['firstName'] as String?)?.trim();
            final fallbackName = _extractFirstName(currentUser.displayName) ?? 'Admin';
            displayName = (firstName != null && firstName.isNotEmpty) ? firstName : fallbackName;
            profileImageUrl = (data?['profileImageUrl'] as String?)?.trim();
            profileImageLocalPath = (data?['profileImageLocalPath'] as String?)?.trim();
          }

          return _buildHeroContent(
            context,
            displayName,
            profileImageUrl,
            profileImageLocalPath,
            topInset,
            isCompact,
          );
        },
      );
    }

    // Fallback for when no user is logged in (should not happen in admin panel)
    return _buildHeroContent(
      context,
      displayName,
      profileImageUrl,
      profileImageLocalPath,
      topInset,
      isCompact,
    );
  }

  // Build the hero section UI with gradient background and decorative patterns
  Widget _buildHeroContent(
      BuildContext context,
      String displayName,
      String? profileImageUrl,
      String? profileImageLocalPath,
      double topInset,
      bool isCompact,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        topInset + (isCompact ? 4 : 10),
        18,
        isCompact ? 8 : 18,
      ),
      decoration: BoxDecoration(
        // Dynamic gradient based on theme mode (dark uses grays, light uses brand orange)
        gradient: isDarkMode
            ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D), Color(0xFF3D3D3D)],
          stops: [0.0, 0.35, 1.0],
        )
            : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCC7705), Color(0xFFDD8E1E), Color(0xFFF0A73A)],
          stops: [0.0, 0.35, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Decorative background patterns (arcs and rings)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AdminHeroBackgroundPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // User avatar with profile tap functionality
                  GestureDetector(
                    onTap: onProfileTap,
                    child: CurrentUserAvatar(
                      size: 40,
                      onTap: onProfileTap,
                      overrideImageUrl: profileImageUrl,
                      overrideLocalPath: profileImageLocalPath,
                      backgroundColor: isDarkMode ? const Color(0xFF444444) : const Color(0xFFD28E18),
                      borderColor: Colors.white.withOpacity(0.65),
                      borderWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // User greeting text section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Admin Panel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons: Theme toggle, Settings, Logout
                  _CircleActionButton(
                    icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    onTap: onDarkModeToggle,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _CircleActionButton(
                    icon: Icons.settings_outlined,
                    onTap: onSettingsTap,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _CircleActionButton(
                    icon: Icons.logout_rounded,
                    onTap: onLogout,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              // Dynamic spacing based on screen orientation
              SizedBox(height: isCompact ? 6 : 26),
              SizedBox(height: isCompact ? 8 : 25),
            ],
          ),
        ],
      ),
    );
  }
}

// Circular Action Button Widget - Reusable rounded button for header actions
class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          // Dynamic background color based on theme
          color: isDarkMode ? const Color(0xFF444444) : Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDarkMode ? Colors.white70 : const Color(0xFF6C6C6C),
          size: 21,
        ),
      ),
    );
  }
}

// Custom Background Painter - Creates decorative arc patterns in the hero section background
class _AdminHeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paint configuration for decorative rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // First ring (larger, more transparent)
    ringPaint
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 34;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.92, size.height * 0.20),
        radius: size.height * 1.02,
      ),
      math.pi * 0.58,
      math.pi * 0.58,
      false,
      ringPaint,
    );

    // Second ring (smaller, less transparent)
    ringPaint
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 20;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 1.02, size.height * 0.06),
        radius: size.height * 0.86,
      ),
      math.pi * 0.52,
      math.pi * 0.52,
      false,
      ringPaint,
    );
  }

  // CustomPainter optimization - never repaint as background is static
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}