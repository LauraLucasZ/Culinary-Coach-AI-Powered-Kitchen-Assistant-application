// lib/features/filter/presentation/widgets/custom_image_cache.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CustomImageCache {
  static final CustomImageCache _instance = CustomImageCache._internal();
  factory CustomImageCache() => _instance;
  CustomImageCache._internal();

  // In-memory cache
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _cacheExpiry = {};

  // Cache configuration
  static const int _maxMemoryCacheSize = 50; // Max images in memory
  static const Duration _cacheDuration = Duration(days: 7); // Keep for 7 days

  // Loading tracking to prevent duplicate loads
  final Map<String, Future<Uint8List?>> _pendingLoads = {};

  /// Generate cache key from URL
  String _getCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Load image from cache or network
  Future<Uint8List?> getImage(String url) async {
    if (url.isEmpty || url.contains('your-cdn.com')) return null;

    final cacheKey = _getCacheKey(url);

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      final expiry = _cacheExpiry[cacheKey];
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        return _memoryCache[cacheKey];
      } else {
        // Expired, remove from memory
        _memoryCache.remove(cacheKey);
        _cacheExpiry.remove(cacheKey);
      }
    }

    // Check if already loading to prevent duplicate requests
    if (_pendingLoads.containsKey(cacheKey)) {
      return _pendingLoads[cacheKey];
    }

    // Load image
    final future = _loadImageFromNetworkOrDisk(url, cacheKey);
    _pendingLoads[cacheKey] = future;

    final result = await future;
    _pendingLoads.remove(cacheKey);

    return result;
  }

  /// Load image from network or disk cache
  Future<Uint8List?> _loadImageFromNetworkOrDisk(String url, String cacheKey) async {
    // Try disk cache first
    final diskImage = await _getFromDisk(cacheKey);
    if (diskImage != null) {
      // Store in memory cache
      _addToMemoryCache(cacheKey, diskImage);
      return diskImage;
    }

    // Download from network
    try {
      final networkImage = await _downloadImage(url);
      if (networkImage != null) {
        // Save to disk and memory
        await _saveToDisk(cacheKey, networkImage);
        _addToMemoryCache(cacheKey, networkImage);
        return networkImage;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }

    return null;
  }

  /// Download image from network
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        client.close();
        return bytes;
      }
      client.close();
      return null;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  /// Add image to memory cache
  void _addToMemoryCache(String key, Uint8List bytes) {
    // Limit memory cache size
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry
      final oldestKey = _cacheExpiry.keys.first;
      _memoryCache.remove(oldestKey);
      _cacheExpiry.remove(oldestKey);
    }

    _memoryCache[key] = bytes;
    _cacheExpiry[key] = DateTime.now().add(_cacheDuration);
  }

  /// Get image from disk cache
  Future<Uint8List?> _getFromDisk(String cacheKey) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final file = File(path.join(cacheDir.path, 'img_cache_$cacheKey'));

      if (await file.exists()) {
        final stats = await file.stat();
        final age = DateTime.now().difference(stats.modified);

        if (age < _cacheDuration) {
          return await file.readAsBytes();
        } else {
          // Delete expired file
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Disk read error: $e');
    }
    return null;
  }

  /// Save image to disk cache
  Future<void> _saveToDisk(String cacheKey, Uint8List bytes) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final file = File(path.join(cacheDir.path, 'img_cache_$cacheKey'));
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Disk write error: $e');
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    _memoryCache.clear();
    _cacheExpiry.clear();
    _pendingLoads.clear();

    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync();
      for (var file in files) {
        if (file is File && file.path.contains('img_cache_')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Clear cache error: $e');
    }
  }

  /// Get memory cache size
  int get memoryCacheSize => _memoryCache.length;
}

/// Custom cached image widget
class CustomCachedImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CustomCachedImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CustomCachedImage> createState() => _CustomCachedImageState();
}

class _CustomCachedImageState extends State<CustomCachedImage> {
  Future<Uint8List?>? _future;
  final CustomImageCache _cache = CustomImageCache();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CustomCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  void _loadImage() {
    _future = _cache.getImage(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty || widget.imageUrl.contains('your-cdn.com')) {
      return widget.errorWidget ?? _defaultErrorWidget();
    }

    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ?? _defaultPlaceholder();
        }

        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true, // Prevents image from disappearing during rebuild
          );
        }

        return widget.errorWidget ?? _defaultErrorWidget();
      },
    );
  }

  Widget _defaultPlaceholder() {
    return Center(
      child: SizedBox(
        width: widget.width * 0.4,
        height: widget.height * 0.4,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget() {
    return Icon(
      Icons.restaurant,
      size: widget.width * 0.5,
      color: const Color(0xFFCB6B2E).withValues(alpha: 0.7),
    );
  }
}