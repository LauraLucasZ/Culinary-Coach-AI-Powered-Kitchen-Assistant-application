import 'package:flutter/services.dart';

// this service tries to choose the best gif for each cooking step text
class CookingStepMediaMatcher {
  CookingStepMediaMatcher();

  // this is the folder where all start cooking gifs exist
  static const String _assetPrefix = 'assets/images/start-coocking-assets/';
  // this is the safe gif we use when matching is not clear
  static const String _fallbackAsset =
      'assets/images/start-coocking-assets/stir_ingredients_in_a_bowl.gif';

  // this cache stores gif paths so we do not read manifest every time
  List<String>? _cachedAssets;
  // this removes weak connector words so matching is based on cooking meaning
  static const Set<String> _ignoredTokens = <String>{
    'a',
    'an',
    'and',
    'the',
    'to',
    'of',
    'in',
    'on',
    'at',
    'for',
    'with',
    'by',
    'from',
    'into',
    'onto',
    'is',
    'are',
    'be',
    'it',
    'this',
    'that',
    'then',
    'after',
    'before',
    'until',
    'over',
    'under',
    'your',
    'you',
    'remove',
    'cool',
  };

  // this is the main method called from the screen to get one gif path for one step
  Future<String> matchForStep(String stepText) async {
    final assets = await _loadAssets();
    if (assets.isEmpty) return _fallbackAsset;

    final normalizedStep = _normalize(stepText);
    if (normalizedStep.isEmpty) return _pickFallbackAsset(assets);
    final stepTokens = _tokenize(normalizedStep);

    String bestAsset = assets.first;
    var bestScore = -1;
    for (final asset in assets) {
      final score = _scoreAsset(
        step: normalizedStep,
        stepTokens: stepTokens,
        assetPath: asset,
      );
      if (score > bestScore) {
        bestScore = score;
        bestAsset = asset;
      }
    }
    return bestScore < 0 ? _pickFallbackAsset(assets) : bestAsset;
  }

  // this exposes current gif assets so other services can pick by filename
  Future<List<String>> listAvailableGifAssets() async {
    return _loadAssets();
  }

  // this loads gif paths from flutter asset manifest and keeps it dynamic with your latest assets
  Future<List<String>> _loadAssets() async {
    final cached = _cachedAssets;
    if (cached != null) return cached;

    try {
      // this uses flutter asset manifest api because it is more stable on device builds
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets =
          manifest
              .listAssets()
              .where((path) => path.startsWith(_assetPrefix))
              .where((path) => path.toLowerCase().endsWith('.gif'))
              .toList()
            ..sort();

      _cachedAssets = assets;
      return _cachedAssets!;
    } catch (_) {
      _cachedAssets = const <String>[];
      return _cachedAssets!;
    }
  }

  // this gives a score for one gif based on words in the cooking step
  int _scoreAsset({
    required String step,
    required Set<String> stepTokens,
    required String assetPath,
  }) {
    final assetName = assetPath.split('/').last;
    final normalizedAsset = _normalize(assetName);
    final assetTokens = _tokenize(normalizedAsset);

    var score = 0;

    for (final token in stepTokens) {
      if (assetTokens.contains(token)) score += 7;
    }

    // this map gives extra hints so similar words can still match the right gif
    final lexicalHint = <String, List<String>>{
      'chop': ['cut', 'knife', 'cutting'],
      'cut': ['cut', 'knife', 'cutting'],
      'slice': ['cut', 'knife', 'cutting'],
      'dice': ['cut', 'knife', 'cutting'],
      'mince': ['cut', 'knife', 'cutting'],
      'mix': ['stir', 'bowl', 'ingredients'],
      'stir': ['stir', 'pot', 'bowl'],
      'whisk': ['stir', 'bowl'],
      'boil': ['boil', 'water', 'pot'],
      'simmer': ['boil', 'water', 'pot'],
      'fry': ['frying', 'pan', 'stove'],
      'saute': ['frying', 'pan', 'stove'],
      'sear': ['frying', 'pan', 'stove'],
      'grill': ['frying', 'pan', 'stove'],
      'toast': ['toaster'],
      'bake': ['oven'],
      'egg': ['egg', 'pan'],
      'steak': ['frying', 'pan'],
      'season': ['salt', 'pepper', 'ingredients'],
      'add': ['adding', 'ingredients', 'sauce', 'salt'],
      'pour': ['pouring', 'sauce', 'cup', 'juice'],
      'strain': ['straining', 'cup', 'juice', 'pouring'],
      'juice': ['juice', 'cup', 'straining', 'pouring'],
      'cup': ['cup', 'pouring', 'straining'],
      'oven': ['oven', 'bake'],
      'rinse': ['rinse', 'water', 'straining'],
      'wash': ['rinse', 'water', 'straining'],
      'refrigerator': ['refrigator', 'cool', 'cold'],
      'fridge': ['refrigator', 'cool', 'cold'],
      'refrigator': ['refrigator', 'cool', 'cold', 'freezer', 'freeze'],
      'measure': ['weight', 'machine'],
      'weight': ['weight', 'machine'],
      'pot': ['pot', 'stove'],
      'pan': ['pan', 'stove'],
    };

    for (final entry in lexicalHint.entries) {
      if (!stepTokens.contains(entry.key)) continue;
      for (final hint in entry.value) {
        if (assetTokens.contains(hint)) score += 6;
      }
    }

    if (step.contains('preheat') && assetTokens.contains('oven')) {
      score += 12;
    }
    if (step.contains('water') && assetTokens.contains('boiling')) {
      score += 12;
    }
    if (step.contains('bowl') && assetTokens.contains('bowl')) {
      score += 10;
    }
    if (step.contains('stove') && assetTokens.contains('stove')) {
      score += 8;
    }
    if (step.contains('grill') && assetTokens.contains('frying')) {
      score += 11;
    }
    if (step.contains('pour') && assetTokens.contains('pouring')) {
      score += 12;
    }
    if (step.contains('strain') && assetTokens.contains('straining')) {
      score += 12;
    }
    if (step.contains('juice') && assetTokens.contains('juice')) {
      score += 12;
    }
    if (step.contains('cup') && assetTokens.contains('cup')) {
      score += 10;
    }
    if (step.contains('oven') && assetTokens.contains('oven')) {
      score += 12;
    }
    if (step.contains('rinse') && assetTokens.contains('rinse')) {
      score += 12;
    }
    if ((step.contains('refrigerator') ||
            step.contains('fridge') ||
            step.contains('refrigator')) &&
        assetTokens.contains('refrigator')) {
      score += 12;
    }

    // this prevents egg gif from showing when instruction is not about eggs
    final hasEggInStep =
        stepTokens.contains('egg') || stepTokens.contains('eggs');
    final hasEggInAsset =
        assetTokens.contains('egg') || assetTokens.contains('eggs');
    if (hasEggInAsset && !hasEggInStep) {
      score -= 28;
    }
    if (hasEggInStep && hasEggInAsset) {
      score += 16;
    }

    return score;
  }

  // this cleans text so matching is easier and more consistent
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // this splits cleaned text into unique words for quick matching
  Set<String> _tokenize(String text) {
    return _normalize(
      text,
    ).split(' ').where((token) {
      if (token.isEmpty) return false;
      if (_ignoredTokens.contains(token)) return false;
      if (token.length <= 2) return false;
      return true;
    }).toSet();
  }

  // this ensures fallback still works if the original fallback gif was deleted
  String _pickFallbackAsset(List<String> assets) {
    if (assets.contains(_fallbackAsset)) return _fallbackAsset;
    if (assets.isNotEmpty) return assets.first;
    return _fallbackAsset;
  }
}
