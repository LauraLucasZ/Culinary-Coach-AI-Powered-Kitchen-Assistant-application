List<String> buildSearchKeywords(String input) {
  final normalized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return const [];

  final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
  final keywords = <String>{};

  // Prefixes for each word: "sondos" -> s, so, son, ...
  for (final w in words) {
    for (var i = 1; i <= w.length; i++) {
      keywords.add(w.substring(0, i));
    }
  }

  // Prefixes for full string: "sondos ahmed" -> s, so, ... "sondos a", ...
  for (var i = 1; i <= normalized.length; i++) {
    keywords.add(normalized.substring(0, i));
  }

  return keywords.toList()..sort();
}

