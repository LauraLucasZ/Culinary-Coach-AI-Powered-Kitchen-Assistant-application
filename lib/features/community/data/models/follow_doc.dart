import 'package:cloud_firestore/cloud_firestore.dart';

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

