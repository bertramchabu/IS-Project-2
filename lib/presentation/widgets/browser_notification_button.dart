import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/app_error_logger.dart';
import '../../di/service_locator.dart' as di;
import '../../services/push_notification_service.dart';

class BrowserNotificationButton extends StatelessWidget {
  const BrowserNotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Enable browser push notifications',
      onPressed: () async {
        try {
          final enabled = await di
              .sl<PushNotificationService>()
              .enableBrowserNotifications();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled
                    ? 'Browser push notifications are enabled.'
                    : 'Notifications were not enabled. Allow notifications for this site in your browser settings.',
              ),
            ),
          );
        } catch (error) {
          AppErrorLogger.log('BrowserNotificationButton.enable', error);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not enable browser notifications: $error'),
            ),
          );
        }
      },
      icon: const Icon(Icons.notifications_active_outlined),
    );
  }
}
