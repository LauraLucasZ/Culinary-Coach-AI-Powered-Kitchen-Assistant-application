import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorProfileImageUrl,
    required this.caption,
    required this.imageUrl,
    required this.recipeTitle,
    required this.cookingTime,
    required this.tags,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.repostOfPostId,
    required this.originalAuthorId,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfileImageUrl;
  final String caption;
  final String? imageUrl;
  final String? recipeTitle;
  final String? cookingTime;
  final List<String> tags;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int repostCount;

  // Repost support
  final String? repostOfPostId;
  final String? originalAuthorId;

  bool get isRepost => repostOfPostId != null && repostOfPostId!.isNotEmpty;

  static CommunityPost fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final tagsRaw = data['tags'];
    final tags = (tagsRaw is List)
        ? tagsRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return CommunityPost(
      id: doc.id,
      authorId: (data['authorId'] as String?)?.trim() ?? '',
      authorName: (data['authorName'] as String?)?.trim() ?? 'User',
      authorProfileImageUrl: (data['authorProfileImageUrl'] as String?)?.trim(),
      caption: (data['caption'] as String?)?.trim() ?? '',
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      recipeTitle: (data['recipeTitle'] as String?)?.trim(),
      cookingTime: (data['cookingTime'] as String?)?.trim(),
      tags: tags,
      createdAt: createdAt,
      likeCount: _readInt(data['likeCount']),
      commentCount: _readInt(data['commentCount']),
      repostCount: _readInt(data['repostCount']),
      repostOfPostId: (data['repostOfPostId'] as String?)?.trim(),
      originalAuthorId: (data['originalAuthorId'] as String?)?.trim(),
    );
  }

  static int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }
}

