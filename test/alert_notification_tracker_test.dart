import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/alert_model.dart';
import 'package:netvision_ai/presentation/alerts/alert_notification_tracker.dart';

void main() {
  AlertModel alert(String id) => AlertModel(
        alertId: id,
        nodeId: 'node-1',
        severity: AlertSeverity.high,
        status: AlertStatus.active,
        title: 'Network alert $id',
        description: 'Test alert',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  test('does not notify for the initial snapshot and emits only new alerts',
      () {
    final tracker = AlertNotificationTracker();
    final existing = alert('existing');
    final added = alert('new');

    expect(tracker.observe([existing]), isEmpty);
    expect(tracker.observe([existing, added]), [added]);
    expect(tracker.observe([existing, added]), isEmpty);
  });

  test('alerts removed from the active set can notify if reactivated', () {
    final tracker = AlertNotificationTracker();
    final current = alert('current');

    tracker.observe([current]);
    expect(tracker.observe([]), isEmpty);
    expect(tracker.observe([current]), [current]);
  });
}
