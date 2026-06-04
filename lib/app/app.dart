import 'package:culinary_coach_app/app/router/app_router.dart';
import 'package:culinary_coach_app/app/theme/app_theme.dart';
import 'package:culinary_coach_app/features/auth/data/services/auth_service.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:culinary_coach_app/app/shell/presentation/screens/main_shell_screen.dart';
import 'package:culinary_coach_app/features/admin/presentation/screens/admin_shell_screen.dart';
import 'package:culinary_coach_app/features/settings/data/services/app_settings_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CulinaryCoachApp extends ConsumerWidget {
  const CulinaryCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'CulinaryCoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthDecisionScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

// Separate screen to handle auth decision
class AuthDecisionScreen extends StatefulWidget {
  const AuthDecisionScreen({super.key});

  @override
  State<AuthDecisionScreen> createState() => _AuthDecisionScreenState();
}

class _AuthDecisionScreenState extends State<AuthDecisionScreen> {
  final AuthService _authService = AuthService();
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = _authService.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const OnboardingScreen();
        }

        // User is logged in, check admin status
        return FutureBuilder<bool>(
          future: _authService.isAdminUser(user),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isAdmin = adminSnapshot.data ?? false;
            print('=== AUTH DECISION ===');
            print('User: ${user.email}');
            print('Is Admin: $isAdmin');
            print('=====================');

            if (isAdmin) {
              return const AdminShellScreen();
            } else {
              // Ensure user record exists for regular users
              _authService.ensureUserRecordForCurrentSession();
              return const MainShellScreen();
            }
          },
        );
      },
    );
  }
}