import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Reads `profileImageBase64` from a Firestore user document map.
String? readProfileImageBase64(Map<String, dynamic>? data) {
  final v = data?['profileImageBase64'];
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Safely decodes a profile image Base64 string; returns null when invalid.
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

/// Encodes image bytes as a compressed JPEG Base64 string for Firestore.
Future<String?> encodeProfileImageBytesForFirestore(Uint8List input) async {
  if (input.isEmpty) return null;
  final jpeg = _toProfileJpegBytes(input);
  if (jpeg.isEmpty) return null;
  return base64Encode(jpeg);
}

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
