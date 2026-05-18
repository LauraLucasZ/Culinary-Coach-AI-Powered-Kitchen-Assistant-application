// Helpers for profile photos stored as Base64 strings in Firestore.
// Decode for Image.memory; encode/compress before save so the user doc stays small enough.

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Pull the profileImageBase64 string field from a Firestore user map.
String? readProfileImageBase64(Map<String, dynamic>? data) {
  final v = data?['profileImageBase64'];
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

// base64Decode turns the Firestore string into Uint8List bytes for Image.memory.
Uint8List? tryDecodeProfileImageBase64(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    final bytes = base64Decode(trimmed);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

// Resize/compress to JPEG, then base64Encode before saving to users/{uid}.
// Called from ProfileScreen after gallery pick — returns string for profileImageBase64 field.
Future<String?> encodeProfileImageBytesForFirestore(Uint8List input) async {
  if (input.isEmpty) return null;
  final jpeg = _toProfileJpegBytes(input);
  if (jpeg.isEmpty) return null;
  return base64Encode(jpeg);
}

// Shrink large photos before upload — Firestore documents have a ~1 MiB size limit.
Uint8List _toProfileJpegBytes(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    return Uint8List(0);
  }
  const maxSide = 512;
  var work = decoded;
  if (work.width > maxSide || work.height > maxSide) {
    if (work.width >= work.height) {
      work = img.copyResize(
        work,
        width: maxSide,
        interpolation: img.Interpolation.linear,
      );
    } else {
      work = img.copyResize(
        work,
        height: maxSide,
        interpolation: img.Interpolation.linear,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(work, quality: 80));
}
