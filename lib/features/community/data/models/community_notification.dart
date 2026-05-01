import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  final String id;
  final String type;
  final String fromUid;
  final String fromName;
  final String? fromProfileImageUrl;
  final String message;
  final DateTime createdAt;
  final bool read;

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
    return CommunityNotification(
      id: doc.id,
      type: (data['type'] as String?)?.trim() ?? 'unknown',
      fromUid: (data['fromUid'] as String?)?.trim() ?? '',
      fromName: (data['fromName'] as String?)?.trim() ?? 'User',
      fromProfileImageUrl: (data['fromProfileImageUrl'] as String?)?.trim(),
      message: (data['message'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      read: (data['read'] as bool?) ?? false,
    );
  }
}

