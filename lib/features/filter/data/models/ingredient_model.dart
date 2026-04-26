// lib/features/filter/data/models/ingredient_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class IngredientModel {
  final String id;
  final String name;
  final String nameArabic;
  final String imageUrl;
  final String category;
  final String categoryArabic;
  final bool isHalal;
  final String? halalStatusNote;
  final List<String> commonUses;
  final String season;
  final String searchQuery;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Price-related fields
  final double? price;
  final String? currency;
  final String? unit;
  final String? formattedPrice;
  final double? pricePerUnit;
  final String? country;
  final String? market;
  final bool? isActive;

  // NEW FIELDS
  double quantity;        // Quantity of ingredient (e.g., 2, 0.5, 1.5)
  bool isChecked;         // Whether ingredient is selected/checked

  IngredientModel({
    required this.id,
    required this.name,
    required this.nameArabic,
    required this.imageUrl,
    required this.category,
    required this.categoryArabic,
    required this.isHalal,
    this.halalStatusNote,
    required this.commonUses,
    required this.season,
    required this.searchQuery,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.price,
    this.currency,
    this.unit,
    this.formattedPrice,
    this.pricePerUnit,
    this.country,
    this.market,
    this.isActive,
    this.quantity = 1.0,      // Default quantity = 1
    this.isChecked = false,   // Default isChecked = false
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory IngredientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IngredientModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      nameArabic: data['nameArabic'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      category: data['category'] as String? ?? '',
      categoryArabic: data['categoryArabic'] as String? ?? '',
      isHalal: data['isHalal'] as bool? ?? true,
      halalStatusNote: data['halalStatusNote'] as String?,
      commonUses: List<String>.from(data['commonUses'] ?? []),
      season: data['season'] as String? ?? '',
      searchQuery: data['searchQuery'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      price: (data['price'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      unit: data['unit'] as String?,
      formattedPrice: data['formattedPrice'] as String?,
      pricePerUnit: (data['pricePerUnit'] as num?)?.toDouble(),
      country: data['country'] as String?,
      market: data['market'] as String?,
      isActive: data['isActive'] as bool?,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
      isChecked: data['isChecked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'nameArabic': nameArabic,
      'imageUrl': imageUrl,
      'category': category,
      'categoryArabic': categoryArabic,
      'isHalal': isHalal,
      'halalStatusNote': halalStatusNote,
      'commonUses': commonUses,
      'season': season,
      'searchQuery': searchQuery,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
      if (unit != null) 'unit': unit,
      if (formattedPrice != null) 'formattedPrice': formattedPrice,
      if (pricePerUnit != null) 'pricePerUnit': pricePerUnit,
      if (country != null) 'country': country,
      if (market != null) 'market': market,
      if (isActive != null) 'isActive': isActive,
      'quantity': quantity,
      'isChecked': isChecked,
    };
  }

  // Helper method to create a copy with updated values
  IngredientModel copyWith({
    String? id,
    String? name,
    String? nameArabic,
    String? imageUrl,
    String? category,
    String? categoryArabic,
    bool? isHalal,
    String? halalStatusNote,
    List<String>? commonUses,
    String? season,
    String? searchQuery,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? price,
    String? currency,
    String? unit,
    String? formattedPrice,
    double? pricePerUnit,
    String? country,
    String? market,
    bool? isActive,
    double? quantity,
    bool? isChecked,
  }) {
    return IngredientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameArabic: nameArabic ?? this.nameArabic,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      categoryArabic: categoryArabic ?? this.categoryArabic,
      isHalal: isHalal ?? this.isHalal,
      halalStatusNote: halalStatusNote ?? this.halalStatusNote,
      commonUses: commonUses ?? this.commonUses,
      season: season ?? this.season,
      searchQuery: searchQuery ?? this.searchQuery,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      unit: unit ?? this.unit,
      formattedPrice: formattedPrice ?? this.formattedPrice,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      country: country ?? this.country,
      market: market ?? this.market,
      isActive: isActive ?? this.isActive,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  // Calculate total price based on quantity
  double get totalPrice {
    if (price == null) return 0;
    return price! * quantity;
  }

  String get formattedTotalPrice {
    if (price == null) return 'N/A';
    return '${(price! * quantity).toStringAsFixed(2)} $currency';
  }
}