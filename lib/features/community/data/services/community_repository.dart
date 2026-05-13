import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/community/data/models/community_comment.dart';
import 'package:culinary_coach_app/features/community/data/models/community_notification.dart';
import 'package:culinary_coach_app/features/community/data/models/community_post.dart';
import 'package:culinary_coach_app/features/community/data/models/community_user.dart';
import 'package:culinary_coach_app/features/community/data/services/community_post_image_encoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class CommunityRepository {
  CommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User get _requireUser {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Not signed in');
    }
    return u;
  }

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> postsCol() =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> followersCol(String uid) =>
      userDoc(uid).collection('followers');

  CollectionReference<Map<String, dynamic>> followingCol(String uid) =>
      userDoc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> notificationsCol(String uid) =>
      userDoc(uid).collection('notifications');

  Stream<List<String>> watchFollowingUids(String uid) {
    return followingCol(uid).snapshots().map((snap) {
      final uids = snap.docs
          .map((d) => (d.data()['uid'] as String?)?.trim() ?? d.id)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      uids.sort();
      return uids;
    });
  }

  Stream<CommunityUser?> watchUser(String uid) {
    return userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommunityUser.fromDoc(doc);
    });
  }

  Future<CommunityUser?> getUser(String uid) async {
    final doc = await userDoc(uid).get();
    if (!doc.exists) return null;
    return CommunityUser.fromDoc(doc);
  }

  Future<bool> isFollowing({
    required String viewerUid,
    required String targetUid,
  }) async {
    if (viewerUid == targetUid) return false;
    final doc = await followingCol(viewerUid).doc(targetUid).get();
    return doc.exists;
  }

  Stream<bool> watchIsFollowing({
    required String viewerUid,
    required String targetUid,
  }) {
    if (viewerUid == targetUid) return Stream.value(false);
    return followingCol(viewerUid).doc(targetUid).snapshots().map((d) => d.exists);
  }

  Future<void> followUser({
    required String targetUid,
  }) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    if (viewerUid == targetUid) return;

    final viewerData = await getUser(viewerUid);
    final targetData = await getUser(targetUid);
    if (targetData == null) return;

    final viewerName = viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final viewerProfileUrl = viewerData?.profileImageUrl ?? viewer.photoURL;
    final now = Timestamp.now();

    await _firestore.runTransaction((tx) async {
      final followingRef = followingCol(viewerUid).doc(targetUid);
      final followerRef = followersCol(targetUid).doc(viewerUid);

      final existing = await tx.get(followingRef);
      if (existing.exists) return;

      tx.set(
        followingRef,
        {
          'uid': targetUid,
          'name': targetData.displayName,
          'profileImageUrl': targetData.profileImageUrl,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );
      tx.set(
        followerRef,
        {
          'uid': viewerUid,
          'name': viewerName,
          'profileImageUrl': viewerProfileUrl,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );

      tx.set(
        userDoc(targetUid),
        {'followersCount': FieldValue.increment(1), 'updatedAt': now},
        SetOptions(merge: true),
      );
      tx.set(
        userDoc(viewerUid),
        {'followingCount': FieldValue.increment(1), 'updatedAt': now},
        SetOptions(merge: true),
      );

      final notifRef = notificationsCol(targetUid).doc();
      tx.set(notifRef, {
        'type': 'follow',
        'fromUid': viewerUid,
        'fromName': viewerName,
        'fromProfileImageUrl': viewerProfileUrl,
        'message': '$viewerName started following you.',
        'createdAt': now,
        'read': false,
      });
    });
  }

  Future<void> unfollowUser({
    required String targetUid,
  }) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    if (viewerUid == targetUid) return;

    final now = Timestamp.now();
    await _firestore.runTransaction((tx) async {
      final followingRef = followingCol(viewerUid).doc(targetUid);
      final followerRef = followersCol(targetUid).doc(viewerUid);

      final existing = await tx.get(followingRef);
      if (!existing.exists) return;

      tx.delete(followingRef);
      tx.delete(followerRef);

      tx.set(
        userDoc(targetUid),
        {'followersCount': FieldValue.increment(-1), 'updatedAt': now},
        SetOptions(merge: true),
      );
      tx.set(
        userDoc(viewerUid),
        {'followingCount': FieldValue.increment(-1), 'updatedAt': now},
        SetOptions(merge: true),
      );
    });
  }

  Future<String> createPost({
    required String caption,
    String? recipeTitle,
    String? cookingTime,
    List<String>? tags,
    List<XFile> images = const [],
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final postRef = postsCol().doc();

    final now = Timestamp.now();
    final uid = viewer.uid;

    await viewer.getIdToken(true);

    var imageBase64List = <String>[];
    if (images.isNotEmpty) {
      developer.log(
        'createPost: encoding ${images.length} image(s) for Firestore (no Storage)',
        name: 'CommunityRepository',
      );
      try {
        imageBase64List = await encodeCommunityPostImagesForFirestore(images);
        developer.log(
          'createPost: encode OK count=${imageBase64List.length}',
          name: 'CommunityRepository',
        );
      } catch (e, st) {
        developer.log(
          'createPost: encode FAILED error=$e',
          name: 'CommunityRepository',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }

    if (images.isNotEmpty && imageBase64List.isEmpty) {
      throw StateError(
        'Could not process the selected images. Try again or pick different photos.',
      );
    }

    final payload = <String, dynamic>{
      'authorId': uid,
      'authorName': viewerData?.displayName ?? (viewer.displayName ?? 'User'),
      'authorProfileImageUrl': viewerData?.profileImageUrl ?? viewer.photoURL,
      'caption': caption.trim(),
      'recipeTitle': recipeTitle?.trim().isEmpty ?? true ? null : recipeTitle!.trim(),
      'cookingTime': cookingTime?.trim().isEmpty ?? true ? null : cookingTime!.trim(),
      'tags': (tags ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'createdAt': now,
      'likeCount': 0,
      'commentCount': 0,
      'repostCount': 0,
    };
    if (imageBase64List.isNotEmpty) {
      payload['imageBase64List'] = imageBase64List;
    }

    await postRef.set(payload);

    await userDoc(viewer.uid).set(
      {'communityPosts': FieldValue.increment(1), 'updatedAt': now},
      SetOptions(merge: true),
    );

    return postRef.id;
  }

  Query<Map<String, dynamic>> queryPostsForUser(String uid) {
    // Avoid composite-index requirements (authorId + createdAt).
    // We'll sort client-side by createdAt for stability.
    return postsCol().where('authorId', isEqualTo: uid);
  }

  /// Returns a query for the first "page" of feed posts.
  /// Note: uses whereIn with chunking limit 30 internally by returning multiple queries,
  /// but for simplicity in UI we provide a single "combined stream" method.
  Stream<List<CommunityPost>> watchFeedPosts({bool includeMyPosts = true}) {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;

    late final StreamController<List<CommunityPost>> controller;
    StreamSubscription? followingSub;
    final postSubs = <StreamSubscription>[];
    var latest = <List<CommunityPost>>[];

    void cancelPostSubs() {
      for (final s in postSubs) {
        s.cancel();
      }
      postSubs.clear();
      latest = <List<CommunityPost>>[];
    }

    void emitMerged() {
      final merged = latest.expand((e) => e).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged);
    }

    controller = StreamController<List<CommunityPost>>(
      onListen: () {
        followingSub = watchFollowingUids(viewerUid).listen((followed) {
          cancelPostSubs();

          final authors = <String>{
            if (includeMyPosts) viewerUid,
            ...followed,
          }.toList();

          if (authors.isEmpty) {
            controller.add(const <CommunityPost>[]);
            return;
          }

          // Firestore whereIn supports up to 30 values.
          final chunks = <List<String>>[];
          for (var i = 0; i < authors.length; i += 30) {
            chunks.add(
              authors.sublist(
                i,
                i + 30 > authors.length ? authors.length : i + 30,
              ),
            );
          }

          latest = List<List<CommunityPost>>.generate(chunks.length, (_) => const []);

          for (var i = 0; i < chunks.length; i++) {
            final chunk = chunks[i];
            postSubs.add(
              postsCol()
                  .where('authorId', whereIn: chunk)
                  .limit(50)
                  .snapshots()
                  .listen((snap) {
                final list = snap.docs.map(CommunityPost.fromDoc).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                latest[i] = list;
                emitMerged();
              }),
            );
          }

          // Emit immediately for stable UI while snapshots load.
          controller.add(const <CommunityPost>[]);
        });
      },
      onCancel: () async {
        await followingSub?.cancel();
        cancelPostSubs();
      },
    );

    return controller.stream;
  }

  Stream<List<CommunityPost>> watchPostsForUser(String uid) {
    return queryPostsForUser(uid).limit(50).snapshots().map((snap) {
      final posts = snap.docs.map(CommunityPost.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Stream<bool> watchHasLiked({
    required String postId,
    required String uid,
  }) {
    return postsCol()
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }

  Future<void> toggleLike({
    required String postId,
  }) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    final postRef = postsCol().doc(postId);
    final likeRef = postRef.collection('likes').doc(viewerUid);

    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;

      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        tx.set(
          userDoc(postSnap.data()!['authorId'] as String),
          {'likesCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
      } else {
        tx.set(likeRef, {'uid': viewerUid, 'createdAt': Timestamp.now()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        tx.set(
          userDoc(postSnap.data()!['authorId'] as String),
          {'likesCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }
    });
  }

  Stream<List<CommunityComment>> watchComments(String postId) {
    return postsCol()
        .doc(postId)
        .collection('comments')
        .limit(100)
        .snapshots()
        .map((snap) {
      final comments = snap.docs.map(CommunityComment.fromDoc).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    });
  }

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final postRef = postsCol().doc(postId);
    final commentRef = postRef.collection('comments').doc();

    final now = Timestamp.now();
    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;
      tx.set(commentRef, {
        'uid': viewer.uid,
        'name': viewerData?.displayName ?? (viewer.displayName ?? 'User'),
        'profileImageUrl': viewerData?.profileImageUrl ?? viewer.photoURL,
        'text': text.trim(),
        'createdAt': now,
      });
      tx.update(postRef, {'commentCount': FieldValue.increment(1)});
    });
  }

  Future<void> repost({
    required CommunityPost original,
    String? caption,
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final postRef = postsCol().doc();

    final now = Timestamp.now();
    await _firestore.runTransaction((tx) async {
      final originalRef = postsCol().doc(original.id);
      final originalSnap = await tx.get(originalRef);
      if (!originalSnap.exists) return;

      tx.set(postRef, {
        'authorId': viewer.uid,
        'authorName': viewerData?.displayName ?? (viewer.displayName ?? 'User'),
        'authorProfileImageUrl': viewerData?.profileImageUrl ?? viewer.photoURL,
        'caption': (caption?.trim().isNotEmpty ?? false) ? caption!.trim() : original.caption,
        if (original.imageUrls.isNotEmpty) 'imageUrls': original.imageUrls,
        if (original.imageBase64List.isNotEmpty)
          'imageBase64List': original.imageBase64List,
        'recipeTitle': original.recipeTitle,
        'cookingTime': original.cookingTime,
        'tags': original.tags,
        'createdAt': now,
        'likeCount': 0,
        'commentCount': 0,
        'repostCount': 0,
        'repostOfPostId': original.id,
        'originalAuthorId': original.authorId,
      });
      tx.update(originalRef, {'repostCount': FieldValue.increment(1)});
    });
  }

  Stream<List<CommunityUser>> watchAllUsers({int limit = 80}) {
    // Avoid relying on optional fields for ordering (some existing docs may not
    // have displayNameLower yet). Sort client-side for stability.
    return _firestore.collection('users').limit(limit).snapshots().map((snap) {
      final users = snap.docs.map(CommunityUser.fromDoc).toList();
      users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return users;
    });
  }

  Stream<List<CommunityUser>> watchSuggestedUsers({
    required String excludeUid,
    int limit = 10,
  }) {
    // Best-effort: show a stable list of recent users with displayNameLower present.
    // Exclude current user on the client side.
    return _firestore
        .collection('users')
        .orderBy('updatedAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snap) {
      final users = snap.docs.map(CommunityUser.fromDoc).toList();
      final filtered =
          users.where((u) => u.uid != excludeUid).take(limit).toList();
      return filtered;
    });
  }

  Stream<List<CommunityUser>> watchUserSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Stream.value(const <CommunityUser>[]);

    return _firestore
        .collection('users')
        .where('nameKeywords', arrayContains: q)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityUser.fromDoc).toList());
  }

  Stream<List<CommunityNotification>> watchNotifications() {
    final viewer = _requireUser;
    return notificationsCol(viewer.uid).limit(50).snapshots().map((snap) {
      final items = snap.docs.map(CommunityNotification.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Stream<int> watchUnreadNotificationsCount() {
    final viewer = _requireUser;
    return notificationsCol(viewer.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final viewer = _requireUser;
    await notificationsCol(viewer.uid).doc(notificationId).set(
      {'read': true},
      SetOptions(merge: true),
    );
  }

  Future<void> markAllNotificationsRead() async {
    final viewer = _requireUser;
    final snap = await notificationsCol(viewer.uid)
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.set(d.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

