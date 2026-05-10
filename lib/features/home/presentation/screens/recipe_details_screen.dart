// lib/features/home/presentation/screens/recipe_details_screen.dart

import 'dart:convert';
import 'dart:math' as math;

import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/favorite_recipes_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({super.key, required this.recipe});

  final RecipeMatch recipe;

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  static const String _spoonacularKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
  );
  final FavoriteRecipesService _favoriteRecipesService =
      FavoriteRecipesService();

  late RecipeMatch _recipe;
  bool _isLoading = false;
  final Map<int, bool> _favoriteOverrides = <int, bool>{};

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_spoonacularKey.isEmpty || _recipe.id == 0) return;
    setState(() => _isLoading = true);

    try {
      final uri = Uri.https(
        'api.spoonacular.com',
        '/recipes/${_recipe.id}/information',
        {'includeNutrition': 'false', 'apiKey': _spoonacularKey},
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _recipe = _recipe.copyWithDetails(decoded));
    } catch (_) {
      // Keep the basic card data if details fail.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavoriteRecipe({
    required String userId,
    required bool isFavorite,
  }) async {
    if (_recipe.id <= 0) return;
    final nextValue = !isFavorite;
    setState(() => _favoriteOverrides[_recipe.id] = nextValue);

    try {
      if (nextValue) {
        await _favoriteRecipesService.saveFavoriteRecipe(
          userId: userId,
          recipe: _recipe,
        );
      } else {
        await _favoriteRecipesService.removeFavoriteRecipe(
          userId: userId,
          recipeId: _recipe.id,
        );
      }
      if (!mounted) return;
      setState(() => _favoriteOverrides.remove(_recipe.id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _favoriteOverrides.remove(_recipe.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update favorites right now. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1DE),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Food Details',
                        style: TextStyle(
                          color: Color(0xFF3A2214),
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  StreamBuilder<Set<int>>(
                    stream: currentUserId == null
                        ? null
                        : _favoriteRecipesService.streamFavoriteRecipeIds(
                            currentUserId,
                          ),
                    initialData: const <int>{},
                    builder: (context, snapshot) {
                      final favoriteIds = Set<int>.from(
                        snapshot.data ?? const <int>{},
                      );
                      final effectiveFavoriteIds = <int>{...favoriteIds};
                      _favoriteOverrides.forEach((recipeId, value) {
                        if (value) {
                          effectiveFavoriteIds.add(recipeId);
                        } else {
                          effectiveFavoriteIds.remove(recipeId);
                        }
                      });
                      final isFavorite = effectiveFavoriteIds.contains(
                        _recipe.id,
                      );

                      return GestureDetector(
                        onTap: () {
                          if (currentUserId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please sign in to save favorite recipes.',
                                ),
                              ),
                            );
                            return;
                          }
                          _toggleFavoriteRecipe(
                            userId: currentUserId,
                            isFavorite: isFavorite,
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _DetailsFavoriteHeartButton(
                            isFavorite: isFavorite,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recipe.title,
                      style: const TextStyle(
                        color: Color(0xFF3A2214),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB31A),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _recipe.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF8B7355),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _InfoText(
                          icon: Icons.schedule_rounded,
                          text: '${_recipe.readyInMinutes} mins',
                        ),
                        const SizedBox(width: 12),
                        _InfoText(
                          icon: Icons.restaurant_menu_rounded,
                          text: '${_recipe.servings} servings',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: _recipe.image.isEmpty
                          ? Container(
                              height: 250,
                              color: const Color(0xFFFCF7E8),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.restaurant,
                                color: Color(0xFFB87313),
                                size: 60,
                              ),
                            )
                          : Image.network(
                              _recipe.image,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Color(0xFF3A2214),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recipe.summary.isNotEmpty
                          ? _recipe.summary
                          : 'A delicious recipe selected for you. Check the ingredients and follow the directions below.',
                      style: const TextStyle(
                        color: Color(0xFF8B7355),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _StatBox(
                          title: 'Servings',
                          value: '${_recipe.servings}',
                        ),
                        const SizedBox(width: 12),
                        _StatBox(
                          title: 'Cook',
                          value: '${_recipe.readyInMinutes} min',
                        ),
                        const SizedBox(width: 12),
                        const _StatBox(title: 'Preparation', value: '4 min'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _ExpandableInfo(
                      title: 'Ingredients',
                      children: _ingredientList().isEmpty
                          ? [
                              const Text(
                                'No ingredients available.',
                                style: TextStyle(color: Color(0xFF8B7355)),
                              ),
                            ]
                          : _ingredientList()
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Text(
                                      '• $e',
                                      style: const TextStyle(
                                        color: Color(0xFF3A2214),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                    const SizedBox(height: 12),
                    _ExpandableInfo(
                      title: 'Direction',
                      initiallyExpanded: true,
                      children: _recipe.instructions.isEmpty
                          ? [
                              const Text(
                                'Detailed directions are not available for this recipe.',
                                style: TextStyle(color: Color(0xFF8B7355)),
                              ),
                            ]
                          : _recipe.instructions.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  '${entry.key + 1}. ${entry.value}',
                                  style: const TextStyle(
                                    color: Color(0xFF3A2214),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 18),
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFB87313),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _ingredientList() {
    final items = <String>{
      ..._recipe.usedIngredients,
      ..._recipe.missedIngredients,
      ..._recipe.unusedIngredients,
    };
    return items.toList();
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF3A2214), size: 19),
      ),
    );
  }
}

class _DetailsFavoriteHeartButton extends StatefulWidget {
  const _DetailsFavoriteHeartButton({required this.isFavorite});

  final bool isFavorite;

  @override
  State<_DetailsFavoriteHeartButton> createState() =>
      _DetailsFavoriteHeartButtonState();
}

class _DetailsFavoriteHeartButtonState
    extends State<_DetailsFavoriteHeartButton>
    with TickerProviderStateMixin {
  late final AnimationController _fillController;
  late final AnimationController _waveController;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
      reverseDuration: const Duration(milliseconds: 820),
      value: widget.isFavorite ? 1 : 0,
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _DetailsFavoriteHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite == widget.isFavorite) return;
    if (widget.isFavorite) {
      _fillController.forward();
    } else {
      _fillController.reverse();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Color.lerp(
      const Color(0xFF3A2214).withValues(alpha: 0.7),
      const Color(0xFFE43D4E),
      _fillAnimation.value,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_fillAnimation, _waveController]),
      builder: (context, _) {
        final double value = _fillAnimation.value.clamp(0.0, 1.0).toDouble();
        final phase = _waveController.value * math.pi * 2;

        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (value > 0)
                    Icon(
                      Icons.favorite,
                      color: const Color(0xFFE43D4E).withValues(alpha: 0.12),
                      size: 18,
                    ),
                  ClipPath(
                    clipper: _DetailsWaveFillClipper(
                      fillLevel: value,
                      phase: phase,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFFE43D4E),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.favorite_border_rounded, color: borderColor, size: 19),
          ],
        );
      },
    );
  }
}

class _DetailsWaveFillClipper extends CustomClipper<Path> {
  const _DetailsWaveFillClipper({required this.fillLevel, required this.phase});

  final double fillLevel;
  final double phase;

  @override
  Path getClip(Size size) {
    final clampedLevel = fillLevel.clamp(0.0, 1.0).toDouble();
    final waterTop = size.height * (1 - clampedLevel);
    final amplitude = 0.9 + (1.1 * (1 - clampedLevel));

    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, waterTop);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          waterTop +
          math.sin((x / size.width * math.pi * 2) + phase) * amplitude;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _DetailsWaveFillClipper oldClipper) {
    return oldClipper.fillLevel != fillLevel || oldClipper.phase != phase;
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B7355), size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8B7355),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF7E8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF3A2214),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableInfo extends StatelessWidget {
  const _ExpandableInfo({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF7E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3A2214),
              fontWeight: FontWeight.w900,
            ),
          ),
          iconColor: const Color(0xFFB87313),
          collapsedIconColor: const Color(0xFFB87313),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: children,
        ),
      ),
    );
  }
}
