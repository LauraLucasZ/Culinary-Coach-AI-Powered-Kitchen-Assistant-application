// lib/features/home/presentation/screens/recipe_details_screen.dart

import 'dart:convert';

import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({super.key, required this.recipe});

  final RecipeMatch recipe;

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  static const String _spoonacularKey = String.fromEnvironment('SPOONACULAR_API_KEY');

  late RecipeMatch _recipe;
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
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
                  _CircleIconButton(icon: Icons.favorite_border_rounded, onTap: () {}),
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
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB31A), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _recipe.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Color(0xFF8B7355), fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 16),
                        _InfoText(icon: Icons.schedule_rounded, text: '${_recipe.readyInMinutes} mins'),
                        const SizedBox(width: 12),
                        _InfoText(icon: Icons.restaurant_menu_rounded, text: '${_recipe.servings} servings'),
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
                        child: const Icon(Icons.restaurant, color: Color(0xFFB87313), size: 60),
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
                      style: TextStyle(color: Color(0xFF3A2214), fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recipe.summary.isNotEmpty
                          ? _recipe.summary
                          : 'A delicious recipe selected for you. Check the ingredients and follow the directions below.',
                      style: const TextStyle(color: Color(0xFF8B7355), height: 1.45, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _StatBox(title: 'Servings', value: '${_recipe.servings}'),
                        const SizedBox(width: 12),
                        _StatBox(title: 'Cook', value: '${_recipe.readyInMinutes} min'),
                        const SizedBox(width: 12),
                        const _StatBox(title: 'Preparation', value: '4 min'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _ExpandableInfo(
                      title: 'Ingredients',
                      children: _ingredientList().isEmpty
                          ? [const Text('No ingredients available.', style: TextStyle(color: Color(0xFF8B7355)))]
                          : _ingredientList()
                          .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text('• $e', style: const TextStyle(color: Color(0xFF3A2214), fontWeight: FontWeight.w600)),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    _ExpandableInfo(
                      title: 'Direction',
                      initiallyExpanded: true,
                      children: _recipe.instructions.isEmpty
                          ? [const Text('Detailed directions are not available for this recipe.', style: TextStyle(color: Color(0xFF8B7355)))]
                          : _recipe.instructions.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '${entry.key + 1}. ${entry.value}',
                            style: const TextStyle(color: Color(0xFF3A2214), height: 1.35, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator(color: Color(0xFFB87313))),
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
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF3A2214), size: 19),
      ),
    );
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
        Text(text, style: const TextStyle(color: Color(0xFF8B7355), fontWeight: FontWeight.w700, fontSize: 12)),
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
        decoration: BoxDecoration(color: const Color(0xFFFCF7E8), borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF8B7355), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(color: Color(0xFF3A2214), fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ExpandableInfo extends StatelessWidget {
  const _ExpandableInfo({required this.title, required this.children, this.initiallyExpanded = false});
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFFCF7E8), borderRadius: BorderRadius.circular(18)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(title, style: const TextStyle(color: Color(0xFF3A2214), fontWeight: FontWeight.w900)),
          iconColor: const Color(0xFFB87313),
          collapsedIconColor: const Color(0xFFB87313),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: children,
        ),
      ),
    );
  }
}
