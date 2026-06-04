import 'dart:convert';

import 'package:http/http.dart' as http;

// this model keeps one cleaned step and optional gif filename picked by ai
class CleanedCookingStep {
  const CleanedCookingStep({required this.text, this.gifFileName});

  final String text;
  final String? gifFileName;
}

// this model carries all cleaned steps and keeps helper getter for text list
class CleanedCookingPlan {
  const CleanedCookingPlan({required this.steps});

  final List<CleanedCookingStep> steps;

  List<String> get stepTexts => steps.map((step) => step.text).toList();
}

// this service cleans cooking instructions with openai and translates to english when needed
class OpenAiCookingStepsService {
  OpenAiCookingStepsService();

  // this key comes from dart define and is needed for openai requests
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  // this endpoint generates cleaned instruction steps as text
  static final Uri _chatUri = Uri.parse(
    'https://api.openai.com/v1/chat/completions',
  );
  // this lightweight model keeps responses fast for this cleanup job
  static const String _model = 'gpt-4o-mini';

  // this cleans steps and can also choose gif filenames from existing assets
  Future<CleanedCookingPlan> cleanInstructionPlan({
    required List<String> instructions,
    required String recipeTitle,
    required List<String> availableGifAssetPaths,
  }) async {
    final fallback = _localFallbackPlan(instructions);
    //converts full paths into file names
    final availableGifFileNames = availableGifAssetPaths
        .map((path) => path.split('/').last)
        .toSet();
    //map for forgiving matching
    final normalizedGifNameMap = <String, String>{
      for (final name in availableGifFileNames) _normalizeGifFileName(name): name,
    };
    //if there is no openai key, return local fallback
    if (_apiKey.trim().isEmpty) return fallback;

    final compactInput = instructions
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
    if (compactInput.isEmpty) return fallback;

    final numberedInput = compactInput
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}) ${entry.value}')
        .join('\n');

    try {
      // this asks openai to remove noise comments and convert all steps to clean english
      final response = await http
          .post(
            _chatUri,
            headers: <String, String>{
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'model': _model,
              'temperature': 0.1,
              'response_format': <String, dynamic>{
                'type': 'json_schema',
                'json_schema': <String, dynamic>{
                  'name': 'cooking_plan_with_gifs',
                  'strict': true,
                  'schema': <String, dynamic>{
                    'type': 'object',
                    'properties': <String, dynamic>{
                      'steps': <String, dynamic>{
                        'type': 'array',
                        'items': <String, dynamic>{
                          'type': 'object',
                          'properties': <String, dynamic>{
                            'text': <String, dynamic>{'type': 'string'},
                            'gif': <String, dynamic>{'type': ['string', 'null']},
                          },
                          'required': <String>['text', 'gif'],
                          'additionalProperties': false,
                        },
                      },
                    },
                    'required': <String>['steps'],
                    'additionalProperties': false,
                  },
                },
              },
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'system',
                  'content':
                      'you clean messy cooking instructions and return concise step-by-step output\n'
                      'rules\n'
                      '- keep only practical cooking actions\n'
                      '- remove noise filler and irrelevant comments\n'
                      '- if input is non-english translate to english\n'
                      '- do not invent ingredients or actions\n'
                      '- keep 3 to 16 steps when possible\n'
                      '- choose one gif filename for each step from provided gif list when suitable\n'
                      '- if no gif is suitable use null for that step gif\n'
                      '- output strict json only in this shape {"steps":[{"text":"...","gif":"filename.gif or null"}]}',
                },
                <String, String>{
                  'role': 'user',
                  'content':
                      'recipe title: $recipeTitle\n'
                      'available gif filenames:\n${availableGifFileNames.join('\n')}\n'
                      'raw instructions:\n$numberedInput',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return fallback;
      final choices = body['choices'];
      if (choices is! List || choices.isEmpty) return fallback;
      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) return fallback;
      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) return fallback;
      final content = (message['content'] ?? '').toString().trim();
      if (content.isEmpty) return fallback;

      final parsed = _extractPlanFromContent(
        content: content,
        availableGifFileNames: availableGifFileNames,
        normalizedGifNameMap: normalizedGifNameMap,
      );
      if (parsed.steps.isEmpty) return fallback;
      return parsed;
    } catch (_) {
      return fallback;
    }
  }

  // old, this keeps compatibility for call sites that only need cleaned step text
  Future<List<String>> cleanInstructionSteps({
    required List<String> instructions,
    required String recipeTitle,
  }) async {
    final plan = await cleanInstructionPlan(
      instructions: instructions,
      recipeTitle: recipeTitle,
      availableGifAssetPaths: const <String>[],
    );
    return plan.stepTexts;
  }

  // this parses/decodes strict json or json inside markdown response
  CleanedCookingPlan _extractPlanFromContent({
    required String content,
    required Set<String> availableGifFileNames,
    required Map<String, String> normalizedGifNameMap,
  }) {
    Map<String, dynamic>? asJson;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) asJson = decoded;
    } catch (_) {
      final jsonBlock = RegExp(r'\{[\s\S]*\}').firstMatch(content)?.group(0);
      if (jsonBlock == null) return const CleanedCookingPlan(steps: <CleanedCookingStep>[]);
      try {
        final decoded = jsonDecode(jsonBlock);
        if (decoded is Map<String, dynamic>) asJson = decoded;
      } catch (_) {
        return const CleanedCookingPlan(steps: <CleanedCookingStep>[]);
      }
    }

    if (asJson == null) return const CleanedCookingPlan(steps: <CleanedCookingStep>[]);
    final rawSteps = asJson['steps'];
    if (rawSteps is! List) {
      return const CleanedCookingPlan(steps: <CleanedCookingStep>[]);
    }

    final cleanedSteps = <CleanedCookingStep>[];
    for (final item in rawSteps) {
      if (item is Map<String, dynamic>) {
        final cleanedText = (item['text'] ?? '')
            .toString()
            .replaceFirst(RegExp(r'^\d+[\)\.\-:]\s*'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (cleanedText.isEmpty) continue;

        // this accepts several key names to survive slight model formatting drift
        final gifNameRaw =
            item['gif'] ??
            item['gifFileName'] ??
            item['gif_file_name'] ??
            item['asset'] ??
            item['image'];
        final gifName = gifNameRaw?.toString().trim();
        final safeGif = _resolveGifName(
          gifName: gifName,
          availableGifFileNames: availableGifFileNames,
          normalizedGifNameMap: normalizedGifNameMap,
        );
        cleanedSteps.add(CleanedCookingStep(text: cleanedText, gifFileName: safeGif));
        continue;
      }

      final cleanedText = item
          .toString()
          .replaceFirst(RegExp(r'^\d+[\)\.\-:]\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanedText.isEmpty) continue;
      cleanedSteps.add(CleanedCookingStep(text: cleanedText, gifFileName: null));
    }
    return CleanedCookingPlan(steps: cleanedSteps);
  }

  // this maps near-matching gif names from ai to real filenames in assets
  String? _resolveGifName({
    required String? gifName,
    required Set<String> availableGifFileNames,
    required Map<String, String> normalizedGifNameMap,
  }) {
    if (gifName == null || gifName.isEmpty) return null;
    if (availableGifFileNames.contains(gifName)) return gifName;

    final normalized = _normalizeGifFileName(gifName);
    final directNormalizedMatch = normalizedGifNameMap[normalized];
    if (directNormalizedMatch != null) return directNormalizedMatch;

    final withGifSuffix = '$normalized gif';
    final looseMatch = normalizedGifNameMap[withGifSuffix];
    if (looseMatch != null) return looseMatch;

    return null;
  }

  // this normalizes names so spacing and separators do not break mapping
  String _normalizeGifFileName(String value) {
    return value
        .toLowerCase()
        .replaceAll('.gif', '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // this fallback keeps simple readable steps when ai is unavailable
  CleanedCookingPlan _localFallbackPlan(List<String> instructions) {
    if (instructions.isEmpty) {
      return const CleanedCookingPlan(
        steps: <CleanedCookingStep>[
          CleanedCookingStep(
            text: 'Instructions are not available for this recipe. Please go back and pick another recipe.',
          ),
        ],
      );
    }

    if (instructions.length > 1) {
      final cleaned = instructions
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) {
        return CleanedCookingPlan(
          steps: cleaned.map((step) => CleanedCookingStep(text: step)).toList(),
        );
      }
    }

    final single = instructions.first.trim();
    if (single.isEmpty) {
      return const CleanedCookingPlan(
        steps: <CleanedCookingStep>[CleanedCookingStep(text: 'No instructions provided.')],
      );
    }
    final splitByNumbering = single.split(RegExp(r'\s(?=\d+[\)\.\-])'));
    if (splitByNumbering.length <= 1) {
      return CleanedCookingPlan(
        steps: <CleanedCookingStep>[CleanedCookingStep(text: single)],
      );
    }
    final cleaned = splitByNumbering
        .map(
          (step) => step.replaceFirst(RegExp(r'^\d+[\)\.\-:]\s*'), '').trim(),
        )
        .where((step) => step.isNotEmpty)
        .toList();
    final fallbackSteps = cleaned.isEmpty ? <String>[single] : cleaned;
    return CleanedCookingPlan(
      steps: fallbackSteps.map((step) => CleanedCookingStep(text: step)).toList(),
    );
  }
}
