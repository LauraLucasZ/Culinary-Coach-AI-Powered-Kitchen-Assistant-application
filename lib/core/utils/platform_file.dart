// Conditional import so the codebase still compiles on web.
import 'platform_file_stub.dart' if (dart.library.io) 'platform_file_io.dart';

/// Returns a platform `File` object when available (mobile/desktop).
/// Returns `null` on web or when path is empty.
dynamic platformFileFromPath(String path) => createPlatformFileFromPath(path);

