import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class IngredientModel {
  final String name;
  final String imageUrl;
  final String category;

  const IngredientModel({
    required this.name,
    required this.imageUrl,
    required this.category,
  });
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  bool isAnalyzing = false;
  List<IngredientModel>? scannedIngredients;
  String? errorMessage;

  final ImagePicker _picker = ImagePicker();

  // 🔥 IMPORTANT: Replace this with your actual OpenAI API Key
  // Get your API key from: https://platform.openai.com/api-keys
  final String apiKey = "YOUR_OPENAI_API_KEY_HERE";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildGradientOverlay(),
          _buildTopBar(),
          _buildScannerOverlay(),
          _buildBottomControls(),

          if (isAnalyzing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing ingredients...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          if (scannedIngredients != null && scannedIngredients!.isNotEmpty)
            _buildResultsSheet(),

          if (errorMessage != null)
            _buildErrorSnackbar(),
        ],
      ),
    );
  }

  // ================= UI =================

  Widget _buildCameraPreview() {
    return SizedBox.expand(
      child: _image == null
          ? Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Take a photo of your ingredients',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      )
          : Image.file(_image!, fit: BoxFit.cover),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
          _circleButton(Icons.help_outline, () => _showHelpDialog()),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Scan'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Take a clear photo of your ingredients'),
            SizedBox(height: 8),
            Text('2. Make sure ingredients are well-lit'),
            SizedBox(height: 8),
            Text('3. Place ingredients in the center frame'),
            SizedBox(height: 8),
            Text('4. Wait for AI to detect them'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFFF7A00), width: 3),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFFF7A00), width: 3),
                    left: BorderSide(color: Color(0xFFFF7A00), width: 3),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFFF7A00), width: 3),
                    right: BorderSide(color: Color(0xFFFF7A00), width: 3),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFF7A00), width: 3),
                    left: BorderSide(color: Color(0xFFFF7A00), width: 3),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFF7A00), width: 3),
                    right: BorderSide(color: Color(0xFFFF7A00), width: 3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Column(
        children: [
          const Text(
            "Place ingredient in the frame to identify it.",
            style: TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
                onPressed: _pickFromGallery,
              ),

              GestureDetector(
                onTap: _pickFromCamera,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A00),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 35),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
                onPressed: () {
                  setState(() {
                    _image = null;
                    scannedIngredients = null;
                    errorMessage = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 350,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Detected Ingredients",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3A2214)),
                ),
                TextButton(
                  onPressed: () {
                    // Add to shopping list
                    Navigator.pop(context, scannedIngredients?.map((i) => i.name).toList());
                  },
                  child: const Text(
                    'Add All',
                    style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Expanded(
              child: GridView.builder(
                itemCount: scannedIngredients!.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (_, i) {
                  final ing = scannedIngredients![i];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ing.imageUrl.isNotEmpty
                            ? Image.network(
                          ing.imageUrl,
                          height: 50,
                          width: 50,
                          errorBuilder: (_, __, ___) => Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(Icons.food_bank, color: Color(0xFFFF7A00), size: 30),
                          ),
                        )
                            : Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Icon(Icons.food_bank, color: Color(0xFFFF7A00), size: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ing.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF3A2214)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            ing.category,
                            style: const TextStyle(fontSize: 9, color: Color(0xFFFF7A00)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'An error occurred'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              setState(() => errorMessage = null);
            },
          ),
        ),
      );
    });
    return const SizedBox.shrink();
  }

  // ================= IMAGE PICKING =================

  Future<void> _pickFromCamera() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (file != null) {
        setState(() {
          _image = File(file.path);
          scannedIngredients = null;
          errorMessage = null;
        });
        _analyzeImage();
      }
    } else {
      setState(() {
        errorMessage = 'Camera permission is required to take photos';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        _image = File(file.path);
        scannedIngredients = null;
        errorMessage = null;
      });
      _analyzeImage();
    }
  }

  // ================= AI ANALYSIS =================

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    // Check if API key is configured
    if (apiKey == "YOUR_OPENAI_API_KEY_HERE" || apiKey.isEmpty) {
      setState(() {
        errorMessage = 'Please configure your OpenAI API key in the code';
        isAnalyzing = false;
      });
      return;
    }

    setState(() => isAnalyzing = true);

    try {
      // Compress image before sending
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Check image size (OpenAI has limits)
      if (base64Image.length > 20 * 1024 * 1024) { // 20MB limit
        throw Exception('Image too large. Please choose a smaller image.');
      }

      // Using Chat Completions API with Vision capability
      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": "List all the ingredients you can see in this image. Return ONLY a valid JSON array of ingredient names as strings. Example format: [\"tomato\", \"onion\", \"garlic\"]. Do not include any other text or explanation. If you can't see any ingredients clearly, return an empty array []."
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,$base64Image"
                  }
                }
              ]
            }
          ],
          "max_tokens": 500,
          "temperature": 0.3,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception('API Error: ${errorData['error']['message'] ?? response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      // Clean and parse the response
      String cleanedContent = content.trim();

      // Remove markdown code blocks if present
      if (cleanedContent.startsWith('```json')) {
        cleanedContent = cleanedContent.substring(7);
      }
      if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent.substring(3);
      }
      if (cleanedContent.endsWith('```')) {
        cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
      }

      cleanedContent = cleanedContent.trim();

      // If empty array or empty content
      if (cleanedContent == '[]' || cleanedContent.isEmpty) {
        throw Exception('No ingredients detected in the image');
      }

      // Parse the JSON array
      final List<dynamic> ingredientList = jsonDecode(cleanedContent);

      if (ingredientList.isEmpty) {
        throw Exception('No ingredients detected in the image');
      }

      setState(() {
        scannedIngredients = ingredientList.map((item) {
          String name = item.toString().toLowerCase().trim();
          return IngredientModel(
            name: _capitalize(name),
            imageUrl: _getIngredientImageUrl(name),
            category: _getIngredientCategory(name),
          );
        }).toList();
        isAnalyzing = false;
      });

    } on http.ClientException catch (e) {
      print('Network error: $e');
      setState(() {
        errorMessage = 'Network error. Please check your internet connection.';
        isAnalyzing = false;
      });
    } catch (e) {
      print('Error analyzing image: $e');
      setState(() {
        errorMessage = _getUserFriendlyError(e);
        isAnalyzing = false;
      });
    }
  }

  // Helper method to get ingredient images from reliable sources
  String _getIngredientImageUrl(String ingredientName) {
    // Using The Meal DB API for ingredient images (free, no API key needed)
    final encodedName = Uri.encodeComponent(ingredientName);
    return "https://www.themealdb.com/images/ingredients/$encodedName.png";
  }

  // Helper method to categorize ingredients
  String _getIngredientCategory(String name) {
    final vegetables = ['tomato', 'onion', 'garlic', 'potato', 'carrot', 'broccoli', 'spinach', 'lettuce', 'cucumber', 'pepper', 'celery', 'zucchini', 'cabbage', 'cauliflower', 'eggplant', 'pumpkin'];
    final fruits = ['apple', 'banana', 'orange', 'grape', 'strawberry', 'mango', 'pineapple', 'watermelon', 'kiwi', 'peach', 'pear', 'lemon', 'lime', 'avocado', 'blueberry', 'raspberry'];
    final meats = ['chicken', 'beef', 'pork', 'fish', 'shrimp', 'bacon', 'sausage', 'turkey', 'lamb', 'salmon', 'tuna', 'steak', 'ground beef', 'chicken breast'];
    final dairy = ['milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg', 'eggs', 'sour cream', 'cream cheese'];
    final grains = ['rice', 'bread', 'pasta', 'flour', 'oat', 'cereal', 'wheat', 'corn', 'quinoa', 'barley', 'noodle'];
    final spices = ['salt', 'pepper', 'paprika', 'cumin', 'cinnamon', 'oregano', 'basil', 'thyme', 'rosemary', 'garlic powder', 'onion powder', 'chili powder'];
    final legumes = ['bean', 'beans', 'lentil', 'lentils', 'chickpea', 'soy', 'tofu', 'edamame'];

    name = name.toLowerCase();

    if (vegetables.contains(name)) return 'Vegetable';
    if (fruits.contains(name)) return 'Fruit';
    if (meats.contains(name)) return 'Meat';
    if (dairy.contains(name)) return 'Dairy';
    if (grains.contains(name)) return 'Grain';
    if (spices.contains(name)) return 'Spice';
    if (legumes.contains(name)) return 'Legume';

    return 'Ingredient';
  }

  String _getUserFriendlyError(dynamic error) {
    String errorStr = error.toString().toLowerCase();

    if (errorStr.contains('401') || errorStr.contains('unauthorized') || errorStr.contains('api key')) {
      return 'Invalid or missing API key. Please check your OpenAI API key configuration.';
    } else if (errorStr.contains('429')) {
      return 'Rate limit exceeded. Please try again in a few moments.';
    } else if (errorStr.contains('500') || errorStr.contains('503')) {
      return 'OpenAI server error. Please try again.';
    } else if (errorStr.contains('no ingredients') || errorStr.contains('empty array')) {
      return 'No ingredients detected. Please take a clearer photo with better lighting.';
    } else if (errorStr.contains('socket') || errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (errorStr.contains('image too large')) {
      return 'Image is too large. Please choose a smaller image.';
    } else {
      return 'Failed to analyze image. Please try again.';
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}