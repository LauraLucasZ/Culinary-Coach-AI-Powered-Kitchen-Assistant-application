// Model for one story in Firestore (image as Base64, expires after ~24 hours).
// CommunityStoryRing bundles one user's active stories for the strip UI.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Community story stored in Firestore (base64 image, no Firebase Storage).
/// Legacy docs may still contain `videoBase64` / `videoThumbBase64` / `mediaType`;
/// the app ignores video playback but keeps parsing non-breaking.
class CommunityStory {
  const CommunityStory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.imageBase64,
    required this.imageBase64List,
    required this.textOverlay,
    required this.textColorValue,
    required this.textSize,
    required this.textPosX,
    required this.textPosY,
    required this.createdAt,
    required this.expiresAt,
    required this.likedBy,
    required this.archived,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String imageBase64;
  // This stores all story photos (new stories use a list, old stories may have only one).
  final List<String> imageBase64List;
  final String textOverlay;
  // This stores the chosen text color as an ARGB int, so we can rebuild the Color later.
  final int textColorValue;
  // This stores the chosen font size for the story text.
  final double textSize;
  // This stores the text position on the photo as 0..1 values (relative to image size).
  final double textPosX;
  final double textPosY;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> likedBy;
  final bool archived;

  int get likeCount => likedBy.length;

  /// Effective expiry for "active" UI: use [expiresAt] when it is valid and not before
  /// [createdAt]; otherwise treat as missing/invalid and use [createdAt] + 24h.
  // Stories hide from the strip after this time (default 24h from createdAt if expiresAt missing).
  DateTime get resolvedExpiresAt {
    final c = createdAt;

    final fallback = c.millisecondsSinceEpoch > 0
        ? c.add(const Duration(hours: 24))
        : DateTime.fromMillisecondsSinceEpoch(0);
    final ex = expiresAt;
    if (ex.millisecondsSinceEpoch <= 0) return fallback;
    if (c.millisecondsSinceEpoch > 0 && ex.isBefore(c)) return fallback;
    return ex;
  }

  bool isActiveAt(DateTime when) => when.isBefore(resolvedExpiresAt);

  bool likedByUid(String? uid) {
    final u = uid?.trim();
    if (u == null || u.isEmpty) return false;
    for (final e in likedBy) {
      if (e.trim() == u) return true;
    }
    return false;
  }

  /// Archive list thumbnail (image only; legacy video-only stories may be empty).
  // This picks a stable thumbnail for the archive list (first image is enough).
  String get archiveThumbBase64 =>
      imageBase64List.isNotEmpty ? imageBase64List.first : imageBase64;

  // Parse Firestore document into a CommunityStory for the viewer and archive list.
  static CommunityStory fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    final created = _readTime(data['createdAt']);
    final expires = _readTime(data['expiresAt']);
    final likedRaw = data['likedBy'];
    final liked = <String>[];
    if (likedRaw is List) {
      for (final e in likedRaw) {
        if (e is String && e.trim().isNotEmpty) liked.add(e.trim());
      }
    }
    final b64List = _readImageBase64List(data);
    final b64 = b64List.isNotEmpty ? b64List.first : _readImageBase64(data);

    // This reads saved story text style values, or uses safe defaults if missing.
    final textColorValue = _readInt(data['textColorValue'], fallback: 0xFFFFFFFF);
    final textSize = _readDouble(data['textSize'], fallback: 20);
    final textPosX = _readDouble(data['textPosX'], fallback: 0.5).clamp(0.0, 1.0);
    final textPosY = _readDouble(data['textPosY'], fallback: 0.75).clamp(0.0, 1.0);
    return CommunityStory(
      id: doc.id,
      userId: (data['userId'] as String?)?.trim() ?? '',
      userName: (data['userName'] as String?)?.trim() ?? 'User',
      userAvatar: () {
        final u = (data['userAvatar'] as String?)?.trim();
        if (u == null || u.isEmpty) return null;
        return u;
      }(),
      imageBase64: b64,
      imageBase64List: b64List.isNotEmpty ? b64List : (b64.isNotEmpty ? [b64] : const []),
      textOverlay: (data['textOverlay'] as String?) ?? '',
      textColorValue: textColorValue,
      textSize: textSize,
      textPosX: textPosX,
      textPosY: textPosY,
      createdAt: created,
      expiresAt: expires,
      likedBy: liked,
      archived: (data['archived'] as bool?) ?? true,
    );
  }

  static String _readImageBase64(Map<String, dynamic> data) {
    final direct = (data['imageBase64'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final list = data['imageBase64List'];
    if (list is List && list.isNotEmpty) {
      final first = list.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    return '';
  }

  // This reads `imageBase64List` and filters out empty strings.
  static List<String> _readImageBase64List(Map<String, dynamic> data) {
    final raw = data['imageBase64List'];
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // This reads an int from Firestore safely (some older docs store numbers as strings).
  static int _readInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  // This reads a double from Firestore safely (some older docs store numbers as strings).
  static double _readDouble(dynamic v, {required double fallback}) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  static DateTime _readTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      if (raw <= 0) return DateTime.fromMillisecondsSinceEpoch(0);
      // Heuristic: seconds vs millis
      if (raw < 20000000000) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) return _readTime(raw.toInt());
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
      final asInt = int.tryParse(t);
      if (asInt != null) return _readTime(asInt);
      final parsed = DateTime.tryParse(t);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

// One user's ring on the stories strip — list of their non-expired stories.
class CommunityStoryRing {
  const CommunityStoryRing({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.stories,
  });

  final String userId;
  final String userName;
  final String? userAvatar;
  final List<CommunityStory> stories;
}
