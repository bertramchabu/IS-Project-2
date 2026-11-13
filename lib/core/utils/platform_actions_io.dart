import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [csv] to the user's Downloads (or app documents) directory and
/// returns the file path.
Future<String> downloadCsv(String fileName, String csv) async {
  final dir = await getDownloadsDirectory() ??
      await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(csv);
  return file.path;
}

/// Platform alert sound (FR-AS-02).
Future<void> playAlertChime() async {
  try {
    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '[Console]::Beep(880, 220); [Console]::Beep(660, 300)',
    ]);
  } catch (_) {
    // Audio must never break the monitoring flow.
  }
}
