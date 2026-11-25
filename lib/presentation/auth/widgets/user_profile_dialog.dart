import 'package:flutter/material.dart';

import '../../../data/models/user_models.dart';

class UserProfileDialog extends StatelessWidget {
  const UserProfileDialog({
    super.key,
    required this.user,
  });

  final UserModel user;

  static Future<void> show(BuildContext context, UserModel user) {
    return showDialog<void>(
      context: context,
      builder: (_) => UserProfileDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.role.displayName;
    final initials = user.username.isNotEmpty
        ? user.username.trim().split(RegExp(r'\s+')).take(2).map((segment) => segment[0].toUpperCase()).join()
        : 'U';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.cyan.withValues(alpha: 0.18),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleLabel,
                        style: TextStyle(
                          color: Colors.blueGrey.shade200,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoRow(label: 'Email', value: user.email ?? 'Not provided'),
            _InfoRow(
              label: 'Department',
              value: user.department ?? 'Not specified',
            ),
            _InfoRow(
              label: 'Phone',
              value: user.phoneNumber ?? 'Not provided',
            ),
            _InfoRow(
              label: 'Status',
              value: user.isActive ? 'Active' : 'Inactive',
            ),
            _InfoRow(
              label: '2FA',
              value: user.mfaEnabled ? 'Enabled' : 'Disabled',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
