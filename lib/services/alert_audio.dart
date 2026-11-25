import '../core/utils/platform_actions.dart';

/// Session-level audio alerting (FR-AS-02). Enabled only after the user
/// toggles it, so browsers accept the audio gesture requirement.
class AlertAudio {
  static bool enabled = false;

  static Future<void> chime() async {
    if (!enabled) return;
    await playAlertChime();
  }
}
