// lib/features/filter/data/services/ingredient_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';

class IngredientService {
  IngredientService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collectionName = 'full_ingredients'; // ✅ Changed to match upload

  Stream<List<IngredientModel>> getAllIngredients() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => IngredientModel.fromFirestore(doc))
          .toList();
    });
  }

  // Client-side filtering - NO INDEX REQUIRED
  Stream<List<IngredientModel>> getIngredientsByCategoryStream(String category) {
    if (category == 'All') {
      return getAllIngredients();
    }

    return getAllIngredients().map((ingredients) {
      return ingredients.where((i) => i.category == category).toList();
    });
  }

  Future<List<IngredientModel>> getIngredientsByCategory(String category) async {
    final snapshot = await _firestore.collection(_collectionName).get();
    final allIngredients = snapshot.docs
        .map((doc) => IngredientModel.fromFirestore(doc))
        .toList();

    if (category == 'All') {
      allIngredients.sort((a, b) => a.name.compareTo(b.name));
      return allIngredients;
    }

    final filtered = allIngredients.where((i) => i.category == category).toList();
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  Future<List<String>> getAllCategories() async {
    final snapshot = await _firestore.collection(_collectionName).get();
    final categories = snapshot.docs
        .map((doc) => doc.data()['category'] as String)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final snapshot = await _firestore.collection(_collectionName).get();
    final counts = <String, int>{};
    for (var doc in snapshot.docs) {
      final category = doc.data()['category'] as String;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> addIngredient(IngredientModel ingredient) async {
    await _firestore
        .collection(_collectionName)
        .doc(ingredient.id)
        .set(ingredient.toFirestore());
  }

  Future<void> addMultipleIngredients(List<IngredientModel> ingredients) async {
    final batch = _firestore.batch();
    for (var ingredient in ingredients) {
      final docRef = _firestore.collection(_collectionName).doc(ingredient.id);
      batch.set(docRef, ingredient.toFirestore());
    }
    await batch.commit();
  }

  Future<void> deleteIngredient(String id) async {
    await _firestore.collection(_collectionName).doc(id).delete();
  }

  Future<bool> isCollectionEmpty() async {
    final snapshot = await _firestore.collection(_collectionName).limit(1).get();
    return snapshot.docs.isEmpty;
  }

  // New method to get ingredient count
  Future<int> getIngredientCount() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}