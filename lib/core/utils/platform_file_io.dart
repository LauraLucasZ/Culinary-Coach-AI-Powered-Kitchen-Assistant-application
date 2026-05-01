import 'dart:io';

dynamic createPlatformFileFromPath(String path) {
  final value = path.trim();
  if (value.isEmpty) return null;
  return File(value);
}

