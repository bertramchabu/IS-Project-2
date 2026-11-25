import '../../data/models/alert_model.dart';

class AlertNotificationTracker {
  Set<String> _activeAlertIds = {};
  bool _hasInitialSnapshot = false;

  List<AlertModel> observe(List<AlertModel> activeAlerts) {
    if (!_hasInitialSnapshot) {
      _activeAlertIds = activeAlerts.map((alert) => alert.alertId).toSet();
      _hasInitialSnapshot = true;
      return const [];
    }

    final newAlerts = activeAlerts
        .where((alert) => !_activeAlertIds.contains(alert.alertId))
        .toList();
    _activeAlertIds = activeAlerts.map((alert) => alert.alertId).toSet();
    return newAlerts;
  }
}
