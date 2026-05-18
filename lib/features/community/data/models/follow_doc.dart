// Data written when you follow someone — lives in following/ and followers/ subcollections.
// Keeps uid, display name, and avatar URL on each side of the relationship.

import 'package:cloud_firestore/cloud_firestore.dart';

// Payload written into following/ and followers/ subcollection documents.
class FollowDoc {
  const FollowDoc({
    required this.uid,
    required this.name,
    required this.profileImageUrl,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String? profileImageUrl;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'profileImageUrl': profileImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

