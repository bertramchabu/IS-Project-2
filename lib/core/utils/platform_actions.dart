// Platform-specific side effects (FR-AS-02 audio, FR-NA-13 CSV export).
// Native builds use dart:io/path_provider plus a console beep; web builds use
// package:web downloads and a WebAudio chime.
export 'platform_actions_io.dart'
    if (dart.library.js_interop) 'platform_actions_web.dart';
