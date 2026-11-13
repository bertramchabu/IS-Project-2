import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String _lastBlobUrl = '';
web.AudioContext? _audioContext;

/// Triggers a browser download of [csv] and returns the file name.
Future<String> downloadCsv(String fileName, String csv) async {
  final bytes = Uint8List.fromList(utf8.encode(csv));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  if (_lastBlobUrl.isNotEmpty) {
    web.URL.revokeObjectURL(_lastBlobUrl);
  }
  _lastBlobUrl = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = _lastBlobUrl
    ..download = fileName;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return fileName;
}

/// Two-tone WebAudio chime (FR-AS-02). The browser requires a prior user
/// gesture; the audio toggle in the UI satisfies it.
Future<void> playAlertChime() async {
  try {
    final context = _audioContext ??= web.AudioContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
    for (final (freq, start, dur) in [(880.0, 0.0, 0.22), (660.0, 0.25, 0.3)]) {
      final osc = context.createOscillator();
      final gain = context.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, context.currentTime + start);
      gain.gain.exponentialRampToValueAtTime(
          0.25, context.currentTime + start + 0.02);
      gain.gain.exponentialRampToValueAtTime(
          0.0001, context.currentTime + start + dur);
      osc.connect(gain);
      gain.connect(context.destination);
      osc.start(context.currentTime + start);
      osc.stop(context.currentTime + start + dur + 0.05);
    }
  } catch (_) {
    // Audio must never break the monitoring flow.
  }
}
