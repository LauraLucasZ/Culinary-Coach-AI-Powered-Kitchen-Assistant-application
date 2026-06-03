// In-app notification (follow, like, comment) stored under users/{uid}/notifications.
// NotificationsScreen lists these via StreamBuilder.

import 'package:cloud_firestore/cloud_firestore.dart';

// One notification in users/{uid}/notifications (follow, like, comment, etc.).
class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.fromProfileImageUrl,
    required this.message,
    required this.createdAt,
    required this.read,
    this.postId,
    this.repostId,
    this.storyId,
    this.commentId,
    this.replyId,
    this.recipientUserId,
    this.senderUserId,
  });

  final String id;
  final String type;
  final String fromUid;
  final String fromName;
  final String? fromProfileImageUrl;
  final String message;
  final DateTime createdAt;
  final bool read;
  final String? postId;
  final String? repostId;
  final String? storyId;
  final String? commentId;
  final String? replyId;
  final String? recipientUserId;
  final String? senderUserId;

  // Build notification model from users/{uid}/notifications/{id} snapshot.
  static CommunityNotification fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final fromUid = (data['fromUid'] as String?)?.trim() ?? '';
    final senderUserId = (data['senderUserId'] as String?)?.trim();
    return CommunityNotification(
      id: doc.id,
      type: (data['type'] as String?)?.trim() ?? 'unknown',
      fromUid: fromUid,
      fromName: (data['fromName'] as String?)?.trim() ?? 'User',
      fromProfileImageUrl: (data['fromProfileImageUrl'] as String?)?.trim(),
      message: (data['message'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      read: (data['read'] as bool?) ?? false,
      postId: (data['postId'] as String?)?.trim(),
      repostId: (data['repostId'] as String?)?.trim(),
      storyId: (data['storyId'] as String?)?.trim(),
      commentId: (data['commentId'] as String?)?.trim(),
      replyId: (data['replyId'] as String?)?.trim(),
      recipientUserId: (data['recipientUserId'] as String?)?.trim(),
      senderUserId: (senderUserId != null && senderUserId.isNotEmpty)
          ? senderUserId
          : (fromUid.isNotEmpty ? fromUid : null),
    );
  }
}

