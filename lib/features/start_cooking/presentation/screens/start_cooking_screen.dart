import 'dart:async' show unawaited;

import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/history_recipes_service.dart';
import 'package:culinary_coach_app/features/start_cooking/data/services/cooking_step_media_matcher.dart';
import 'package:culinary_coach_app/features/start_cooking/data/services/openai_cooking_steps_service.dart';
import 'package:culinary_coach_app/features/start_cooking/data/services/openai_cooking_voice_service.dart';
import 'package:flutter/material.dart';

// this is the screen user sees after pressing start cooking
class StartCookingScreen extends StatefulWidget {
  // recipe has all details including instruction steps
  // userId is used to save progress in firestore
  const StartCookingScreen({super.key, required this.recipe, this.userId});

  final RecipeMatch recipe;
  final String? userId;

  @override
  State<StartCookingScreen> createState() => _StartCookingScreenState();
}

class _StartCookingScreenState extends State<StartCookingScreen> {
  // this list targets newly added gifs that visually look tiny because of inner padding
  static const Set<String> _boostedGifFileNames = <String>{
    'chopping with knife.gif',
    'cutting the fish .gif',
    'grind something.gif',
    'hand mixer.gif',
    'knead a dough with hands.gif',
    'letting the dough rest.gif',
    'pouring and straining juice into a cup.gif',
    'pouring the sauce on cooked food.gif',
    'shape dough into balls.gif',
    'spread a dough in baking pan.gif',
  };
  // this lets us reduce scale for specific gifs that become too tall on screen
  static const Map<String, double> _gifScaleOverrides = <String, double>{
    'pouring the sauce on cooked food.gif': 1.2,
  };

  // this speaks each step using openai tts or fallback tts
  final OpenAiCookingVoiceService _voiceService = OpenAiCookingVoiceService();
  // this cleans and translates instructions using openai when available
  final OpenAiCookingStepsService _stepsService = OpenAiCookingStepsService();
  // this chooses the best gif for the current step text
  final CookingStepMediaMatcher _mediaMatcher = CookingStepMediaMatcher();
  // this saves and restores cooking progress from started_recipes
  final HistoryRecipesService _historyRecipesService = HistoryRecipesService();
  // this keeps selected gif path for each step index to avoid recalculating
  final Map<int, String> _assetByStepIndex = <int, String>{};

  // these are the final cleaned steps shown in this flow
  List<String> _steps = const <String>[];
  // this tells which step is currently visible
  int _currentStepIndex = 0;
  // this controls speaking state for ui label
  bool _isSpeaking = false;
  // this controls loading state while gif path is being matched
  bool _isLoadingAsset = false;
  // this turns true only when user reaches final finish action
  bool _didCompleteRecipe = false;
  // this prevents double save on quick back navigation events
  bool _isPersistingExit = false;

  @override
  void initState() {
    super.initState();
    // this shows a quick placeholder while cleaned steps are being prepared
    _steps = const <String>['preparing clean cooking instructions'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // this runs after first frame so async work does not block build
      _initializeFlow();
    });
  }

  // this sets up voice, restores old step if exists, then starts current step
  Future<void> _initializeFlow() async {
    await _prepareSteps();
    if (!mounted || _steps.isEmpty) return;
    await _setupVoice();
    await _restoreSavedProgressIfAny();
    await _loadGifForCurrentStep();
    await _speakCurrentStep();
  }

  // this asks openai to clean and translate instructions before cooking starts
  Future<void> _prepareSteps() async {
    final availableAssets = await _mediaMatcher.listAvailableGifAssets();
    final plan = await _stepsService.cleanInstructionPlan(
      instructions: widget.recipe.instructions,
      recipeTitle: widget.recipe.title,
      availableGifAssetPaths: availableAssets,
    );
    final pathByFileName = <String, String>{
      for (final asset in availableAssets) asset.split('/').last: asset,
    };
    if (!mounted) return;
    setState(() {
      _steps = plan.stepTexts;
      _currentStepIndex = 0;
      _assetByStepIndex.clear();
      // this preloads ai-selected gifs so we skip local matching when ai gave a clear choice
      for (var i = 0; i < plan.steps.length; i++) {
        final gifFileName = plan.steps[i].gifFileName;
        if (gifFileName == null || gifFileName.isEmpty) continue;
        final assetPath = pathByFileName[gifFileName];
        if (assetPath == null) continue;
        _assetByStepIndex[i] = assetPath;
      }
    });
  }

  // this prepares tts service one time
  Future<void> _setupVoice() async {
    await _voiceService.init();
  }

  // this returns text of currently active step
  String get _currentStepText => _steps[_currentStepIndex];

  // this gives extra scale only to new gifs that look too small
  double _gifScaleForAsset(String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) return 1.0;
    final fileName = assetPath.split('/').last;
    final overrideScale = _gifScaleOverrides[fileName];
    if (overrideScale != null) return overrideScale;
    return _boostedGifFileNames.contains(fileName) ? 2.9 : 1.0;
  }

  // this loads saved step from firestore if recipe was started before
  Future<void> _restoreSavedProgressIfAny() async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) return;
    final savedStep = await _historyRecipesService.fetchSavedCookingStep(
      userId: userId,
      recipeId: widget.recipe.id,
    );
    if (!mounted || savedStep == null) return;

    final nextIndex = (savedStep - 1).clamp(0, _steps.length - 1);
    setState(() => _currentStepIndex = nextIndex);
  }

  // this loads and caches gif path for current step index
  Future<void> _loadGifForCurrentStep() async {
    if (_assetByStepIndex.containsKey(_currentStepIndex)) return;
    setState(() => _isLoadingAsset = true);
    final matched = await _mediaMatcher.matchForStep(_currentStepText);
    if (!mounted) return;
    setState(() {
      _assetByStepIndex[_currentStepIndex] = matched;
      _isLoadingAsset = false;
    });
  }

  // this speaks current step with step number intro
  Future<void> _speakCurrentStep() async {
    await _voiceService.stop();
    final spokenText =
        'Step ${_currentStepIndex + 1} of ${_steps.length}. $_currentStepText';
    if (mounted) setState(() => _isSpeaking = true);
    await _voiceService.speak(spokenText);
    if (mounted) setState(() => _isSpeaking = false);
  }

  // this moves to next step and saves progress each time
  Future<void> _goToNextStep() async {
    if (_currentStepIndex >= _steps.length - 1) {
      if (!mounted) return;
      await _voiceService.stop();
      // this marks completion when user finishes last step
      _didCompleteRecipe = true;
      await _saveProgress(exitedCookingScreen: true);
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    setState(() => _currentStepIndex += 1);
    await _saveProgress(exitedCookingScreen: false);
    await _loadGifForCurrentStep();
    await _speakCurrentStep();
  }

  // this goes one step back and saves new position
  Future<void> _goToPreviousStep() async {
    if (_currentStepIndex == 0) return;
    await _voiceService.stop();
    setState(() => _currentStepIndex -= 1);
    await _saveProgress(exitedCookingScreen: false);
    await _loadGifForCurrentStep();
    await _speakCurrentStep();
  }

  // this repeats speaking for same step
  Future<void> _repeatStep() async {
    await _speakCurrentStep();
  }

  // this writes progress and completion fields into started_recipes doc
  Future<void> _saveProgress({required bool exitedCookingScreen}) async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) return;
    await _historyRecipesService.saveCookingProgress(
      userId: userId,
      recipeId: widget.recipe.id,
      currentStep: _didCompleteRecipe ? _steps.length : _currentStepIndex + 1,
      totalSteps: _steps.length,
      isCompleted: _didCompleteRecipe,
      exitedCookingScreen: exitedCookingScreen,
    );
  }

  // this handles back exit and saves latest progress before leaving
  Future<void> _handleExitFromScreen() async {
    if (_isPersistingExit) return;
    _isPersistingExit = true;
    await _voiceService.stop();
    try {
      await _saveProgress(exitedCookingScreen: true);
    } finally {
      _isPersistingExit = false;
    }
  }

  @override
  void dispose() {
    // this disposes voice resources when screen is removed
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepNumber = _currentStepIndex + 1;
    final totalSteps = _steps.length;
    final currentAsset = _assetByStepIndex[_currentStepIndex];
    final isLastStep = _currentStepIndex == totalSteps - 1;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF1F1B16);
    final subTitleColor = isDarkMode ? const Color(0xFFBFBFBF) : const Color(0xFF7C7060);
    final stepTextColor = isDarkMode ? const Color(0xFFE7E7E7) : const Color(0xFF2E2821);
    final progressTrackColor = isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFEEE5D8);
    final outlineButtonColor = isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF7A4E0A);
    final outlineBorderColor = isDarkMode ? const Color(0xFF4A4A4A) : const Color(0xFFD8C4A4);

    return PopScope(
      canPop: true,
      // this captures system back gesture and app bar back to save progress
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        unawaited(_handleExitFromScreen());
      },
      child: Scaffold(
        backgroundColor: scaffoldColor,
        appBar: AppBar(
          backgroundColor: scaffoldColor,
          elevation: 0,
          title: Text(
            'Start Cooking',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: IconThemeData(color: titleColor),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // this gives a larger gif size while staying layout-safe
              final gifHeight = isLandscape
                  ? (constraints.maxHeight * 0.34).clamp(140.0, 200.0)
                  : (constraints.maxHeight * 0.42).clamp(220.0, 300.0);
              // this reads scale once so each step keeps same visual size
              final gifScale = _gifScaleForAsset(currentAsset);

              // this landscape branch uses scroll to avoid overflow when height is short
              if (isLandscape) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: totalSteps <= 1 ? 1 : stepNumber / totalSteps,
                          backgroundColor: progressTrackColor,
                          color: const Color(0xFFE1A441),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Step $stepNumber / $totalSteps',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subTitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        // this reserves extra layout space so scaled gifs do not overlap step text
                        height: gifHeight * gifScale,
                        child: Center(
                          child: currentAsset == null || _isLoadingAsset
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Color(0xFFB87313),
                                  ),
                                )
                              : Transform.scale(
                                  // this scales only selected new gifs while preserving old gif size
                                  scale: gifScale,
                                  child: Image.asset(
                                    // this displays selected gif for the step
                                    currentAsset,
                                    height: gifHeight,
                                    width: constraints.maxWidth,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    gaplessPlayback: true,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Color(0xFF8D806E),
                                        size: 36,
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentStepText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: stepTextColor,
                          height: 1.38,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _currentStepIndex == 0
                                  ? null
                                  : _goToPreviousStep,
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 16,
                              ),
                              label: const Text('Prev'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: outlineButtonColor,
                                side: BorderSide(color: outlineBorderColor),
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _repeatStep,
                              icon: Icon(
                                _isSpeaking
                                    ? Icons.volume_up_rounded
                                    : Icons.replay,
                                size: 15,
                              ),
                              label: Text(_isSpeaking ? 'Speaking' : 'Repeat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: outlineButtonColor,
                                side: BorderSide(color: outlineBorderColor),
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _goToNextStep,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                              ),
                              label: Text(isLastStep ? 'Finish' : 'Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE1A441),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // this portrait branch keeps the original centered design
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: totalSteps <= 1 ? 1 : stepNumber / totalSteps,
                        backgroundColor: progressTrackColor,
                        color: const Color(0xFFE1A441),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Step $stepNumber / $totalSteps',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subTitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, bodyConstraints) {
                          // this limits gif box based on available portrait height to prevent overflow
                          final maxGifSlotHeight = (bodyConstraints.maxHeight - 92)
                              .clamp(120.0, bodyConstraints.maxHeight)
                              .toDouble();
                          final desiredGifSlotHeight =
                              (gifHeight * gifScale).toDouble();
                          final effectiveGifSlotHeight = desiredGifSlotHeight
                              .clamp(120.0, maxGifSlotHeight)
                              .toDouble();
                          // this keeps base image size in sync after slot clamping
                          final effectiveBaseGifHeight =
                              (effectiveGifSlotHeight / gifScale)
                                  .clamp(90.0, gifHeight)
                                  .toDouble();

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                // this reserves safe space for boosted gifs without pushing text out
                                height: effectiveGifSlotHeight,
                                child: Center(
                                  child: currentAsset == null || _isLoadingAsset
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Color(0xFFB87313),
                                          ),
                                        )
                                      : Transform.scale(
                                          // this scales only selected new gifs while preserving old gif size
                                          scale: gifScale,
                                          child: Image.asset(
                                            // this displays selected gif for the step
                                            currentAsset,
                                            height: effectiveBaseGifHeight,
                                            width: constraints.maxWidth,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            gaplessPlayback: true,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                    color: Color(0xFF8D806E),
                                                    size: 36,
                                                  );
                                                },
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                _currentStepText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: stepTextColor,
                                  height: 1.38,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentStepIndex == 0
                                ? null
                                : _goToPreviousStep,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 16,
                            ),
                            label: const Text('Prev'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: outlineButtonColor,
                              side: BorderSide(color: outlineBorderColor),
                              minimumSize: const Size.fromHeight(38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _repeatStep,
                            icon: Icon(
                              _isSpeaking
                                  ? Icons.volume_up_rounded
                                  : Icons.replay,
                              size: 15,
                            ),
                            label: Text(_isSpeaking ? 'Speaking' : 'Repeat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: outlineButtonColor,
                              side: BorderSide(color: outlineBorderColor),
                              minimumSize: const Size.fromHeight(38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _goToNextStep,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                            ),
                            label: Text(isLastStep ? 'Finish' : 'Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE1A441),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
