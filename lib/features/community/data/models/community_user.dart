import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityUser {
  const CommunityUser({
    required this.uid,
    required this.displayName,
    required this.profileImageUrl,
    required this.badge,
    required this.cookingLevel,
    required this.favoriteCuisine,
    required this.dietaryPreference,
    required this.followersCount,
    required this.followingCount,
    required this.likesCount,
    required this.nameKeywords,
  });

  final String uid;
  final String displayName;
  final String? profileImageUrl;
  final String badge;
  final String? cookingLevel;
  final String? favoriteCuisine;
  final String? dietaryPreference;
  final int followersCount;
  final int followingCount;
  final int likesCount;
  final List<String> nameKeywords;

  static CommunityUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final uid = (data['uid'] as String?)?.trim();
    final fallbackUid = doc.id;
    final displayName = _resolveDisplayName(data).trim();

    final keywordsRaw = data['nameKeywords'];
    final keywords = (keywordsRaw is List)
        ? keywordsRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return CommunityUser(
      uid: (uid == null || uid.isEmpty) ? fallbackUid : uid,
      displayName: displayName.isEmpty ? 'User' : displayName,
      profileImageUrl: _resolveProfileImageUrl(data),
      badge: ((data['badge'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['badge'] as String).trim()
          : 'Home Chef',
      cookingLevel: (data['cookingLevel'] as String?)?.trim(),
      favoriteCuisine: (data['favoriteCuisine'] as String?)?.trim(),
      dietaryPreference: (data['dietaryPreference'] as String?)?.trim(),
      followersCount: _readInt(data['followersCount']),
      followingCount: _readInt(data['followingCount']),
      likesCount: _readInt(data['likesCount']),
      nameKeywords: keywords,
    );
  }

  static String _resolveDisplayName(Map<String, dynamic> data) {
    String readString(String key) {
      final v = data[key];
      return v is String ? v.trim() : '';
    }

    final displayName = readString('displayName');
    if (displayName.isNotEmpty) return displayName;

    final fullName = readString('fullName');
    if (fullName.isNotEmpty) return fullName;

    final name = readString('name');
    if (name.isNotEmpty) return name;

    final joined = _joinName(data['firstName'], data['lastName']);
    if (joined.isNotEmpty) return joined;

    final email = readString('email');
    if (email.contains('@')) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }

    return 'SmartChef User';
  }

  static String? _resolveProfileImageUrl(Map<String, dynamic> data) {
    String? readString(String key) {
      final v = data[key];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return readString('profileImageUrl') ??
        readString('photoUrl') ??
        readString('photoURL') ??
        readString('avatarUrl');
  }

  static int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static String _joinName(dynamic first, dynamic last) {
    final f = first is String ? first.trim() : '';
    final l = last is String ? last.trim() : '';
    final joined = [if (f.isNotEmpty) f, if (l.isNotEmpty) l].join(' ').trim();
    return joined;
  }
}

