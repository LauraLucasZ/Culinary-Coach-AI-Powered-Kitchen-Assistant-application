// lib/features/my_recipes/presentation/screens/my_recipes_screen.dart
// My Recipes Screen - Displays user's cooking history and favorite recipes with tab navigation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/favorite_recipes_service.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/recipe_details_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// ==================== BACKEND: Firestore Data Models ====================

// Extension to add Firestore conversion methods to RecipeMatch
// Converts RecipeMatch objects to Firestore-compatible maps for storage
extension RecipeMatchFirestore on RecipeMatch {
  // Converts recipe to Firestore document format for started_recipes collection
  // Stores recipe data when user starts cooking a recipe
  Map<String, dynamic> toFirestoreStarted() {
    return {
      'calories': calories,
      'difficulty': difficulty,
      'image': image,
      'instructions': instructions,
      'missedIngredientCount': missedIngredientCount,
      'missedIngredients': missedIngredients,
      'preparationMinutes': preparationMinutes,
      'rating': rating,
      'readyInMinutes': readyInMinutes,
      'recipeId': id,
      'servings': servings,
      'startedAt': FieldValue.serverTimestamp(), // Auto-generated timestamp
      'summary': summary,
      'title': title,
      'unusedIngredients': unusedIngredients,
      'usedIngredientCount': usedIngredientCount,
      'usedIngredients': usedIngredients,
    };
  }

  // Converts recipe to Firestore document format for favorite_recipes collection
  // Stores recipe data when user favorites a recipe
  Map<String, dynamic> toFirestoreFavorite() {
    return {
      'calories': calories,
      'image': image,
      'instructions': instructions,
      'missedIngredientCount': missedIngredientCount,
      'missedIngredients': missedIngredients,
      'rating': rating,
      'readyInMinutes': readyInMinutes,
      'recipeId': id,
      'savedAt': FieldValue.serverTimestamp(), // Auto-generated timestamp
      'servings': servings,
      'summary': summary,
      'title': title,
      'unusedIngredients': unusedIngredients,
      'usedIngredientCount': usedIngredientCount,
      'usedIngredients': usedIngredients,
    };
  }
}

// BACKEND: Helper function to convert Firestore data back to RecipeMatch model
// Reconstructs RecipeMatch object from Firestore document data
RecipeMatch _recipeMatchFromFirestore(Map<String, dynamic> data, String docId) {
  return RecipeMatch(
    id: data['recipeId'] as int? ?? int.tryParse(docId) ?? 0,
    title: data['title'] as String? ?? '',
    image: data['image'] as String? ?? '',
    usedIngredientCount: data['usedIngredientCount'] as int? ?? 0,
    missedIngredientCount: data['missedIngredientCount'] as int? ?? 0,
    rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
    readyInMinutes: data['readyInMinutes'] as int? ?? 0,
    servings: data['servings'] as int? ?? 0,
    calories: data['calories'] as int? ?? 0,
    difficulty: data['difficulty'] as String?,
    preparationMinutes: data['preparationMinutes'] as int?,
    ingredientDetails: const [],
    summary: data['summary'] as String? ?? '',
    usedIngredients: List<String>.from(data['usedIngredients'] ?? []),
    missedIngredients: List<String>.from(data['missedIngredients'] ?? []),
    unusedIngredients: List<String>.from(data['unusedIngredients'] ?? []),
    instructions: List<String>.from(data['instructions'] ?? []),
  );
}

// ==================== FRONTEND: Main Screen Widget ====================

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged; // Callback for theme changes

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Manages History/Favorites tabs

  // INITIALIZATION LOGIC
  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 2 tabs (History, Favorites)
    _tabController = TabController(length: 2, vsync: this);
    // Add listener to rebuild UI when tab changes
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // CLEANUP LOGIC
  @override
  void dispose() {
    _tabController.dispose(); // Prevent memory leaks
    super.dispose();
  }

  // THEME LOGIC: Toggle dark mode through parent callback
  void _toggleDarkMode() {
    widget.onDarkModeChanged(!widget.isDarkMode);
  }

  // FRONTEND: Main UI Builder
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;

    // AUTHENTICATION CHECK: Redirect if user not logged in
    if (userId == null) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF3E8DF),
        body: const Center(
          child: Text('Please sign in to view your recipes.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF3E8DF),
      // FIXED SCROLLING: Using CustomScrollView with proper sliver configuration
      // This ensures all content scrolls properly including the hero header
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(), // Smooth scrolling physics
        slivers: [
          // SLIVER 1: Hero Header Section (User info and actions)
          SliverToBoxAdapter(
            child: _MyRecipesHero(
              isDarkMode: widget.isDarkMode,
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
            ),
          ),

          // SLIVER 2: Custom Tab Bar (Animated selection indicator)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF2C2C2C).withOpacity(0.88)
                      : Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: widget.isDarkMode ? const Color(0xFF444444) : const Color(0xFFE7E5FF)),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isDarkMode ? const Color(0xFF000000) : const Color(0xFFCB6B2E)).withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // History Tab Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _tabController.animateTo(0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tabController.index == 0
                                ? const Color(0xFFCB6B2E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : (widget.isDarkMode ? const Color(0xFFA0A0A0) : const Color(0xFF8D87A6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Favorites Tab Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _tabController.animateTo(1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tabController.index == 1
                                ? const Color(0xFFCB6B2E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Favorites',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: _tabController.index == 1
                                  ? Colors.white
                                  : (widget.isDarkMode ? const Color(0xFFA0A0A0) : const Color(0xFF8D87A6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // SLIVER 3: Tab Content (History & Favorites lists)
          // FIXED SCROLLING: Using SliverFillRemaining with TabBarView
          // This ensures the content expands to fill remaining space and scrolls properly
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _HistoryTab(userId: userId, isDarkMode: widget.isDarkMode),
                _FavoritesTab(userId: userId, isDarkMode: widget.isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== BACKEND + FRONTEND: History Tab ====================
// Displays user's cooking history from Firestore started_recipes collection

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.userId, required this.isDarkMode});

  final String userId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    // BACKEND: Real-time Firestore stream for started recipes
    // Orders by startedAt timestamp descending (newest first)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('started_recipes')
          .orderBy('startedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // ERROR HANDLING: Display error message if stream fails
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFCB6B2E)),
                const SizedBox(height: 12),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // LOADING STATE: Show spinner while fetching data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCB6B2E)),
          );
        }

        final recipes = snapshot.data?.docs ?? [];

        // EMPTY STATE: Show message when no history exists
        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: const Color(0xFFCB6B2E).withOpacity(0.7)),
                const SizedBox(height: 16),
                Text(
                  'No recipes in history yet',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : const Color(0xFF3A2214),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start cooking to see your history',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white38 : const Color(0xFF8B7355),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // FRONTEND: Render scrollable list of recipe cards
        // FIXED SCROLLING: ListView with proper padding and scroll physics, plus bottom padding to clear navbar
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            140, // extra bottom space so last recipe is above navbar
          ), // Extra bottom padding for navbar
          physics: const AlwaysScrollableScrollPhysics(), // Enables smooth scrolling
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final doc = recipes[index];
            final data = doc.data() as Map<String, dynamic>;
            final recipe = _recipeMatchFromFirestore(data, doc.id);
            final startedAt = data['startedAt'] as Timestamp?;

            return _RecipeCard(
              recipe: recipe,
              recipeId: doc.id,
              userId: userId,
              isHistory: true,
              timestamp: startedAt,
              isDarkMode: isDarkMode,
            );
          },
        );
      },
    );
  }
}

// ==================== BACKEND + FRONTEND: Favorites Tab ====================
// Displays user's favorite recipes from Firestore favorite_recipes collection

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.userId, required this.isDarkMode});

  final String userId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    // BACKEND: Real-time Firestore stream for favorite recipes
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorite_recipes')
          .snapshots(),
      builder: (context, snapshot) {
        // ERROR HANDLING
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFCB6B2E)),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ),
          );
        }

        // LOADING STATE
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCB6B2E)),
          );
        }

        // BACKEND: Sort favorites by savedAt timestamp (newest first)
        final recipes = List<QueryDocumentSnapshot>.from(
          snapshot.data?.docs ?? const [],
        )..sort((a, b) {
          final aSaved = (a.data() as Map<String, dynamic>)['savedAt'];
          final bSaved = (b.data() as Map<String, dynamic>)['savedAt'];
          if (aSaved is Timestamp && bSaved is Timestamp) {
            return bSaved.compareTo(aSaved);
          }
          return 0;
        });

        // EMPTY STATE
        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: const Color(0xFFCB6B2E).withOpacity(0.7)),
                const SizedBox(height: 16),
                Text(
                  'No favorite recipes yet',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : const Color(0xFF3A2214),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the ❤️ on recipes to add them here',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white38 : const Color(0xFF8B7355),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // FRONTEND: Render scrollable list of favorite recipe cards
        // FIXED SCROLLING: ListView with proper padding and scroll physics, plus bottom padding to clear navbar
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            140, // extra bottom space so last recipe is above navbar
          ), // Extra bottom padding for navbar
          physics: const AlwaysScrollableScrollPhysics(), // Enables smooth scrolling
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final doc = recipes[index];
            final data = doc.data() as Map<String, dynamic>;
            final recipe = _recipeMatchFromFirestore(data, doc.id);
            final savedAt = data['savedAt'] as Timestamp?;
            return _RecipeCard(
              recipe: recipe,
              recipeId: doc.id,
              userId: userId,
              isHistory: false,
              timestamp: savedAt,
              isDarkMode: isDarkMode,
            );
          },
        );
      },
    );
  }
}

// ==================== FRONTEND: Recipe Card Widget ====================
// Displays individual recipe information with favorite and remove actions

class _RecipeCard extends StatefulWidget {
  const _RecipeCard({
    required this.recipe,
    required this.recipeId,
    required this.userId,
    required this.isHistory,
    required this.isDarkMode,
    this.timestamp,
  });

  final RecipeMatch recipe;
  final String recipeId;
  final String userId;
  final bool isHistory;
  final Timestamp? timestamp;
  final bool isDarkMode;

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  final FavoriteRecipesService _favoriteRecipesService = FavoriteRecipesService();
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  // INITIALIZATION: Check if recipe is already favorited
  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  // BACKEND: Check favorite status from Firestore
  Future<void> _checkIfFavorite() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('favorite_recipes')
        .doc(widget.recipeId)
        .get();

    if (mounted) {
      setState(() {
        _isFavorite = doc.exists;
      });
    }
  }

  // BACKEND: Toggle favorite status (add/remove from favorites)
  Future<void> _toggleFavorite() async {
    if (_isLoadingFavorite) return;
    setState(() => _isLoadingFavorite = true);

    try {
      if (_isFavorite) {
        // Remove from favorites
        await _favoriteRecipesService.removeFavoriteRecipe(
          userId: widget.userId,
          recipeId: widget.recipe.id,
        );
        setState(() => _isFavorite = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Removed from favorites'),
              backgroundColor: widget.isDarkMode ? Colors.grey[800] : const Color(0xFF8B7355),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Add to favorites
        await _favoriteRecipesService.saveFavoriteRecipe(
          userId: widget.userId,
          recipe: widget.recipe,
        );
        setState(() => _isFavorite = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to favorites'), backgroundColor: Color(0xFFCB6B2E), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      // ERROR HANDLING
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorites'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  // BACKEND: Remove recipe from history
  Future<void> _removeFromHistory() async {
    // Confirmation dialog before deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFCF7E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove from history?',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : const Color(0xFF3A2214),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This recipe will be removed from your history.',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF8B7355),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: widget.isDarkMode ? Colors.white60 : const Color(0xFF8B7355))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFCB6B2E))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('started_recipes')
          .doc(widget.recipeId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from history'),
            backgroundColor: widget.isDarkMode ? Colors.grey[800] : const Color(0xFF8B7355),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove from history'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // FRONTEND LOGIC: Format timestamp for display
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  // FRONTEND: Recipe Card UI
  @override
  Widget build(BuildContext context) {
    final canMakeNow = widget.recipe.missedIngredientCount == 0;

    return GestureDetector(
      // Navigate to recipe details on tap
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: widget.recipe)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          // Highlight border for recipes that can be made immediately
          border: canMakeNow
              ? Border.all(color: const Color(0xFF9BEA7A), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: (widget.isDarkMode ? Colors.black : Colors.black).withOpacity(
                widget.isDarkMode ? 0.4 : 0.08,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Recipe Image (left side)
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              child: widget.recipe.image.isNotEmpty
                  ? Image.network(
                widget.recipe.image,
                width: 100,
                height: 117,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 100,
                    color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF3E8DF),
                    child: Icon(Icons.restaurant, size: 40, color: const Color(0xFFCB6B2E).withOpacity(0.4)),
                  );
                },
              )
                  : Container(
                width: 100,
                height: 100,
                color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF3E8DF),
                child: Icon(Icons.restaurant, size: 40, color: const Color(0xFFCB6B2E).withOpacity(0.4)),
              ),
            ),
            // Recipe Details (center)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipe Title
                    Text(
                      widget.recipe.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF3A2214),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Recipe Metadata (time, missing ingredients)
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: const Color(0xFFCB6B2E).withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.recipe.readyInMinutes} min',
                          style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white60 : const Color(0xFF8B7355)),
                        ),
                        const SizedBox(width: 12),
                        if (widget.recipe.usedIngredientCount > 0 || widget.recipe.missedIngredientCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: canMakeNow
                                  ? const Color(0xFF9BEA7A).withOpacity(0.3)
                                  : const Color(0xFFFFCF7A).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              canMakeNow ? 'Ready to cook!' : '${widget.recipe.missedIngredientCount} missing',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: canMakeNow ? const Color(0xFF2D6A1F) : const Color(0xFFB87313),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Timestamp (when added to history/favorites)
                    if (widget.timestamp != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(widget.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: (widget.isDarkMode ? Colors.white38 : const Color(0xFF8B7355)).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Action Buttons (Favorite & Remove)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Favorite Toggle Button
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isFavorite
                            ? const Color(0xFFCB6B2E).withOpacity(0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoadingFavorite
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCB6B2E)),
                      )
                          : Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? const Color(0xFFCB6B2E) : (widget.isDarkMode ? Colors.white54 : const Color(0xFF8B7355)),
                        size: 22,
                      ),
                    ),
                  ),
                  // Remove from History Button (only visible in History tab)
                  if (widget.isHistory)
                    GestureDetector(
                      onTap: _removeFromHistory,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: widget.isDarkMode ? Colors.white54 : const Color(0xFF8B7355),
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FRONTEND: Hero Header Widget ====================
// Displays user avatar, greeting, and action buttons

class _MyRecipesHero extends StatelessWidget {
  const _MyRecipesHero({
    required this.isDarkMode,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onDarkModeToggle,
  });

  final bool isDarkMode;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onDarkModeToggle;

  // Helper: Extract first name from full name
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
    final heroTitleSize = isCompact ? 16.0 : 23.0;
    final searchBg = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final searchHintColor = isDarkMode ? const Color(0xFF9A9A9A) : const Color(0xFF888888);

    // BACKEND: Stream user data from Firestore
    return StreamBuilder<DocumentSnapshot>(
      stream: currentUser == null ? null : FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, userSnapshot) {
        String displayName = 'Chef';
        String? profileImageUrl;
        String? profileImageLocalPath;

        // Parse user data if available
        if (currentUser != null) {
          final data = userSnapshot.data?.data() as Map<String, dynamic>?;
          final firstName = (data?['firstName'] as String?)?.trim();
          final fallbackName = _extractFirstName(currentUser.displayName) ?? 'Chef';
          displayName = (firstName != null && firstName.isNotEmpty) ? firstName : fallbackName;
          profileImageUrl = (data?['profileImageUrl'] as String?)?.trim();
          profileImageLocalPath = (data?['profileImageLocalPath'] as String?)?.trim();
        }

        // FRONTEND: Hero UI with gradient background and decorative patterns
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            18,
            topInset + (isCompact ? 4 : 10),
            18,
            isCompact ? 8 : 18,
          ),
          decoration: BoxDecoration(
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
              // Decorative background patterns
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _MyRecipesHeroBackgroundPainter()),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Avatar + User Info + Action Buttons
                  Row(
                    children: [
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
                              'Your recipe collection',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Theme Toggle Button
                      _CircleActionButton(
                        icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        onTap: onDarkModeToggle,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      // Settings Button
                      _CircleActionButton(
                        icon: Icons.settings_outlined,
                        onTap: onSettingsTap,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 6 : 26),
                  // Hero Title
                  Text(
                    'My Recipes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: heroTitleSize,
                      height: 1.12,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 4),
                    Text(
                      'History & favorites at a glance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: heroTitleSize,
                        height: 1.20,
                      ),
                    ),
                  ],
                  SizedBox(height: isCompact ? 8 : 25),
                  // Search Bar (UI only - placeholder for future functionality)
                  Container(
                    height: isCompact ? 40 : 50,
                    padding: const EdgeInsets.only(left: 16, right: 6),
                    decoration: BoxDecoration(
                      color: searchBg,
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: searchHintColor,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search saved recipes',
                            style: TextStyle(
                              color: searchHintColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.14),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.primaryDeep,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 2 : 10),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== FRONTEND: Circular Action Button Widget ====================
// Reusable circular button for header actions

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

// ==================== FRONTEND: Custom Background Painter ====================
// Draws decorative arc patterns in the hero header background

class _MyRecipesHeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw first decorative ring (larger, more transparent)
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

    // Draw second decorative ring (smaller, less transparent)
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}