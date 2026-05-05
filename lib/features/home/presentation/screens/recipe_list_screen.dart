// lib/features/home/presentation/screens/recipe_list_screen.dart

import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/recipe_details_screen.dart';
import 'package:flutter/material.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({
    super.key,
    required this.title,
    required this.recipes,
  });

  final String title;
  final List<RecipeMatch> recipes;

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _maxMissingIngredients = 20;
  bool _onlyCanMakeNow = false;
  bool _onlyMissingOne = false;
  String _sortBy = 'Best match';
  String _selectedRecipeTime = 'Any';
  double _minRating = 0;
  String _selectedCalories = 'Any';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _searchTokens(String query) {
    return _normalizeText(query)
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length > 1)
        .toSet()
        .toList();
  }

  String _recipeSearchText(RecipeMatch recipe) {
    return _normalizeText([
      recipe.title,
      recipe.summary,
      ...recipe.usedIngredients,
      ...recipe.missedIngredients,
      ...recipe.unusedIngredients,
      ...recipe.instructions,
    ].join(' '));
  }

  bool _matchesSearch(RecipeMatch recipe, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final text = _recipeSearchText(recipe);
    return tokens.every(text.contains);
  }

  List<RecipeMatch> get _filteredRecipes {
    final tokens = _searchTokens(_searchController.text);
    final maxReadyTime = _maxReadyTimeFromFilter();
    final maxCalories = _maxCaloriesFromFilter();

    final filtered = widget.recipes.where((recipe) {
      if (!_matchesSearch(recipe, tokens)) return false;

      if (_onlyCanMakeNow && recipe.missedIngredientCount != 0) return false;

      if (_onlyMissingOne && recipe.missedIngredientCount != 1) return false;

      if (recipe.missedIngredientCount > _maxMissingIngredients) return false;

      if (maxReadyTime != null) {
        if (recipe.readyInMinutes <= 0) return false;
        if (recipe.readyInMinutes > maxReadyTime) return false;
      }

      if (_minRating > 0) {
        if (recipe.rating <= 0) return false;
        if (recipe.rating < _minRating) return false;
      }

      if (maxCalories != null) {
        if (recipe.calories <= 0) return false;
        if (recipe.calories > maxCalories) return false;
      }

      return true;
    }).toList();

    int compareBestMatch(RecipeMatch a, RecipeMatch b) {
      final missing = a.missedIngredientCount.compareTo(b.missedIngredientCount);
      if (missing != 0) return missing;
      final used = b.usedIngredientCount.compareTo(a.usedIngredientCount);
      if (used != 0) return used;
      final rating = b.rating.compareTo(a.rating);
      if (rating != 0) return rating;
      return a.readyInMinutes.compareTo(b.readyInMinutes);
    }

    if (_sortBy == 'Best match') {
      filtered.sort(compareBestMatch);
    } else if (_sortBy == 'Fewest missing') {
      filtered.sort((a, b) {
        final missing = a.missedIngredientCount.compareTo(b.missedIngredientCount);
        if (missing != 0) return missing;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Most used') {
      filtered.sort((a, b) {
        final used = b.usedIngredientCount.compareTo(a.usedIngredientCount);
        if (used != 0) return used;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Highest rating') {
      filtered.sort((a, b) {
        final rating = b.rating.compareTo(a.rating);
        if (rating != 0) return rating;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Fastest time') {
      filtered.sort((a, b) {
        final aTime = a.readyInMinutes <= 0 ? 99999 : a.readyInMinutes;
        final bTime = b.readyInMinutes <= 0 ? 99999 : b.readyInMinutes;
        final time = aTime.compareTo(bTime);
        if (time != 0) return time;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Lowest calories') {
      filtered.sort((a, b) {
        final aCalories = a.calories <= 0 ? 99999 : a.calories;
        final bCalories = b.calories <= 0 ? 99999 : b.calories;
        final calories = aCalories.compareTo(bCalories);
        if (calories != 0) return calories;
        return compareBestMatch(a, b);
      });
    }

    return filtered;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_onlyCanMakeNow) count++;
    if (_onlyMissingOne) count++;
    if (_maxMissingIngredients != 20) count++;
    if (_sortBy != 'Best match') count++;
    if (_selectedRecipeTime != 'Any') count++;
    if (_minRating > 0) count++;
    if (_selectedCalories != 'Any') count++;
    return count;
  }

  int? _maxReadyTimeFromFilter() {
    if (_selectedRecipeTime == 'Under 15 min') return 15;
    if (_selectedRecipeTime == 'Under 30 min') return 30;
    if (_selectedRecipeTime == 'Under 60 min') return 60;
    return null;
  }

  int? _maxCaloriesFromFilter() {
    if (_selectedCalories == 'Under 300 cal') return 300;
    if (_selectedCalories == 'Under 500 cal') return 500;
    if (_selectedCalories == 'Under 700 cal') return 700;
    return null;
  }

  String get _ratingLabel {
    if (_minRating >= 4.5) return '4.5+ Stars';
    if (_minRating >= 4.0) return '4+ Stars';
    if (_minRating >= 3.0) return '3+ Stars';
    return 'Any';
  }

  double _ratingValueFromLabel(String label) {
    if (label == '3+ Stars') return 3.0;
    if (label == '4+ Stars') return 4.0;
    if (label == '4.5+ Stars') return 4.5;
    return 0;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCF7E8),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refresh() {
              setSheetState(() {});
              setState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2C9A4)),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Color(0xFFB87313),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Filters',
                              style: TextStyle(
                                color: Color(0xFF3A2214),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _onlyCanMakeNow = false;
                              _onlyMissingOne = false;
                              _maxMissingIngredients = 20;
                              _sortBy = 'Best match';
                              _selectedRecipeTime = 'Any';
                              _minRating = 0;
                              _selectedCalories = 'Any';
                              refresh();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFFB87313),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FilterSwitchTile(
                        title: 'Recipes I can make now',
                        value: _onlyCanMakeNow,
                        onChanged: (value) {
                          _onlyCanMakeNow = value;
                          if (value) _onlyMissingOne = false;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 10),
                      _FilterSwitchTile(
                        title: 'Missing one ingredient only',
                        value: _onlyMissingOne,
                        onChanged: (value) {
                          _onlyMissingOne = value;
                          if (value) _onlyCanMakeNow = false;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 14),
                      _MissingSlider(
                        value: _maxMissingIngredients,
                        onChanged: (value) {
                          _maxMissingIngredients = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Recipe time',
                        selected: _selectedRecipeTime,
                        values: const [
                          'Any',
                          'Under 15 min',
                          'Under 30 min',
                          'Under 60 min',
                        ],
                        onSelected: (value) {
                          _selectedRecipeTime = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Rating',
                        selected: _ratingLabel,
                        values: const [
                          'Any',
                          '3+ Stars',
                          '4+ Stars',
                          '4.5+ Stars',
                        ],
                        onSelected: (value) {
                          _minRating = _ratingValueFromLabel(value);
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Calories',
                        selected: _selectedCalories,
                        values: const [
                          'Any',
                          'Under 300 cal',
                          'Under 500 cal',
                          'Under 700 cal',
                        ],
                        onSelected: (value) {
                          _selectedCalories = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Sort by',
                        selected: _sortBy,
                        values: const [
                          'Best match',
                          'Fewest missing',
                          'Most used',
                          'Highest rating',
                          'Fastest time',
                          'Lowest calories',
                        ],
                        onSelected: (value) {
                          _sortBy = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB87313),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Done (${_filteredRecipes.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1DE),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF3A2214),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF3A2214),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF888888), size: 25),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        cursorColor: const Color(0xFF6A6A6A),
                        decoration: const InputDecoration(
                          hintText: 'Search recipe',
                          hintStyle: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: _openFilterSheet,
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF888888),
                            size: 23,
                          ),
                        ),
                        if (_activeFilterCount > 0)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB87313),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_activeFilterCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${recipes.length} of ${widget.recipes.length} recipes',
                      style: const TextStyle(
                        color: Color(0xFF8B7355),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_activeFilterCount > 0 || _searchController.text.trim().isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _onlyCanMakeNow = false;
                          _onlyMissingOne = false;
                          _maxMissingIngredients = 20;
                          _sortBy = 'Best match';
                          _selectedRecipeTime = 'Any';
                          _minRating = 0;
                          _selectedCalories = 'Any';
                        });
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFFB87313),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: recipes.isEmpty
                  ? const Center(
                child: Text(
                  'No recipes found. Try clearing search or filters.',
                  style: TextStyle(
                    color: Color(0xFF8B7355),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                child: _MasonryRecipeGrid(recipes: recipes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasonryRecipeGrid extends StatelessWidget {
  const _MasonryRecipeGrid({required this.recipes});

  final List<RecipeMatch> recipes;

  @override
  Widget build(BuildContext context) {
    final left = <RecipeMatch>[];
    final right = <RecipeMatch>[];

    for (int i = 0; i < recipes.length; i++) {
      if (i.isEven) {
        left.add(recipes[i]);
      } else {
        right.add(recipes[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(left.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _MasonryRecipeCard(
                  recipe: left[index],
                  height: index.isEven ? 260 : 315,
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: List.generate(right.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _MasonryRecipeCard(
                  recipe: right[index],
                  height: index.isEven ? 310 : 255,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MasonryRecipeCard extends StatelessWidget {
  const _MasonryRecipeCard({
    required this.recipe,
    required this.height,
  });

  final RecipeMatch recipe;
  final double height;

  bool get _hasMissingOrUsed =>
      recipe.usedIngredientCount > 0 || recipe.missedIngredientCount > 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFCF7E8),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: recipe.image.isEmpty
                    ? Container(
                  color: const Color(0xFFEDE2C8),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFFB87313),
                    size: 42,
                  ),
                )
                    : Image.network(
                  recipe.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: const Color(0xFFEDE2C8),
                      child: const Icon(
                        Icons.restaurant,
                        color: Color(0xFFB87313),
                        size: 42,
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFB31A), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Color(0xFF777777),
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.readyInMinutes} min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          recipe.calories > 0 ? '${recipe.calories} cal' : '— cal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (_hasMissingOrUsed) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${recipe.usedIngredientCount} used  •  ${recipe.missedIngredientCount} missing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (recipe.missedIngredients.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Missing: ${recipe.missedIngredients.take(2).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSwitchTile extends StatelessWidget {
  const _FilterSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2C9A4)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3A2214),
            fontWeight: FontWeight.w800,
          ),
        ),
        value: value,
        activeColor: const Color(0xFF75A843),
        onChanged: onChanged,
      ),
    );
  }
}

class _MissingSlider extends StatelessWidget {
  const _MissingSlider({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == 20 ? 'Any' : '$value';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2C9A4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Max missing ingredients: $label',
            style: const TextStyle(
              color: Color(0xFF3A2214),
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: const Color(0xFF75A843),
            inactiveColor: const Color(0xFFE2C9A4),
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.selected,
    required this.values,
    required this.onSelected,
  });

  final String title;
  final String selected;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3A2214),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final isSelected = selected == value;

            return GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEDF7E7) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF75A843)
                        : const Color(0xFFE2C9A4),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF5C8E3E)
                        : const Color(0xFF5C5C66),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}