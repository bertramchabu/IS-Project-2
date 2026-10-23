import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/user_models.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/widgets/user_profile_dialog.dart';
import '../../widgets/glass_ui.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _AdminColors {
  static const bg = Color(0xFF0A0E17);
  static const surface = Color(0xB3111827);
  static const surfaceAlt = Color(0xAA1A2332);
  static const border = Color(0x526A7D98);
  static const accent = Color(0xFF00E5FF);
  static const violet = Color(0xFF7C3AED);
  static const healthy = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const critical = Color(0xFFEF4444);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class SystemAdminHome extends StatefulWidget {
  const SystemAdminHome({super.key});

  @override
  State<SystemAdminHome> createState() => _SystemAdminHomeState();
}

class _SystemAdminHomeState extends State<SystemAdminHome> {
  int _selectedTabIndex = 0;

  // Threshold configurations state
  double _globalThreshold = 0.70;
  bool _adaptiveReductionEnabled = true;
  double _reductionThreshold = 0.30;
  int _reductionPercentage = 90;
  bool _isSavingConfig = false;

  // Model Retraining simulation state
  bool _isRetraining = false;
  double _trainingProgress = 0.0;
  String _trainingStatus = 'Ready';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authenticatedUserFrom(authState);
    final username = user?.username ?? 'System Admin';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: _AdminColors.bg,
      appBar: _buildAppBar(context, user, username, initials),
      body: GlassBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
              child: _buildSelectedTabContent(user),
            ),
          );

          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedTabIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Administration section',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('User Management'),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Network Nodes'),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Thresholds & Adaptive'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('BiLSTM Model Management'),
                      ),
                      DropdownMenuItem(
                        value: 4,
                        child: Text('Audit Logs & Health'),
                      ),
                    ],
                    onChanged: (index) {
                      if (index != null) {
                        setState(() => _selectedTabIndex = index);
                      }
                    },
                  ),
                ),
                content,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavigationSidebar(),
              const VerticalDivider(width: 1, color: _AdminColors.border),
              content,
            ],
          );
        },
      ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, UserModel? user, String username, String initials) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xCC111827),
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: _AdminColors.border, width: 1),
      ),
      titleSpacing: compact ? 12 : 24,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_AdminColors.accent, _AdminColors.violet],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'NetVision AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: _AdminColors.textPrimary,
                ),
              ),
              if (!compact)
                const Text(
                'System Administration & Governance',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: _AdminColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Role pill
        if (!compact) Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _AdminColors.violet.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AdminColors.violet.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security_rounded,
                  size: 14, color: _AdminColors.violet),
              SizedBox(width: 6),
              Text(
                'SYSTEM ADMIN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _AdminColors.violet,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        if (!compact) const SizedBox(width: 12),
        // Clickable User Profile
        InkWell(
          onTap:
              user == null ? null : () => UserProfileDialog.show(context, user),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _AdminColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _AdminColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: _AdminColors.accent.withOpacity(0.2),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _AdminColors.accent,
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: _AdminColors.textMuted),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: _AdminColors.textSecondary, size: 20),
          tooltip: 'Logout',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildNavigationSidebar() {
    final navItems = [
      {'title': 'User Management', 'icon': Icons.people_alt_outlined},
      {'title': 'Network Nodes', 'icon': Icons.hub_outlined},
      {'title': 'Thresholds & Adaptive', 'icon': Icons.tune_rounded},
      {'title': 'BiLSTM Model Management', 'icon': Icons.psychology_outlined},
      {
        'title': 'Audit Logs & Health',
        'icon': Icons.history_toggle_off_rounded
      },
    ];

    return GlassSurface(
      radius: 0,
      tint: _AdminColors.surface,
      child: SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'ADMINISTRATION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: _AdminColors.textMuted,
                ),
              ),
            ),
            ...List.generate(navItems.length, (idx) {
              final item = navItems[idx];
              final selected = _selectedTabIndex == idx;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? _AdminColors.accent.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? _AdminColors.accent.withOpacity(0.35)
                        : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  selected: selected,
                  leading: Icon(
                    item['icon'] as IconData,
                    size: 18,
                    color: selected
                        ? _AdminColors.accent
                        : _AdminColors.textSecondary,
                  ),
                  title: Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? _AdminColors.accent
                          : _AdminColors.textPrimary,
                    ),
                  ),
                  onTap: () => setState(() => _selectedTabIndex = idx),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(UserModel? user) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildUserManagementTab();
      case 1:
        return _buildNodeManagementTab();
      case 2:
        return _buildThresholdConfigTab(user);
      case 3:
        return _buildModelManagementTab();
      case 4:
        return _buildAuditAndHealthTab();
      default:
        return _buildUserManagementTab();
    }
  }

  // ─── Tab 1: User Management ────────────────────────────────────────────────
  Widget _buildUserManagementTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTabHeader(
              'User Directory & Access Control',
              'Manage user identities, role-based access, and operational statuses',
            ),
            ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AdminColors.accent,
                foregroundColor: const Color(0xFF0A0E17),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live Users Table from Firestore
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error loading users: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            return GlassSurface(
              radius: 14,
              tint: _AdminColors.surface,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(_AdminColors.surfaceAlt),
                  columns: const [
                    DataColumn(
                        label: Text('USER',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('EMAIL',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('ROLE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('STATUS',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('MFA',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('ACTIONS',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final username = data['username'] as String? ?? 'User';
                    final email = data['email'] as String? ?? '';
                    final roleId =
                        data['roleId'] as String? ?? 'role_network_admin';
                    final isActive = data['isActive'] as bool? ?? true;
                    final mfa = data['mfaEnabled'] as bool? ?? false;

                    final roleLabel = roleId == 'role_system_admin'
                        ? 'System Administrator'
                        : roleId == 'role_ict_manager'
                            ? 'ICT Manager'
                            : 'Network Administrator';

                    final roleColor = roleId == 'role_system_admin'
                        ? _AdminColors.violet
                        : roleId == 'role_ict_manager'
                            ? _AdminColors.accent
                            : _AdminColors.healthy;

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: roleColor.withOpacity(0.2),
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: roleColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(username,
                                  style: const TextStyle(
                                      color: _AdminColors.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        DataCell(Text(email,
                            style: const TextStyle(
                                color: _AdminColors.textSecondary,
                                fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: roleColor.withOpacity(0.4)),
                            ),
                            child: Text(roleLabel,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: roleColor)),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isActive
                                      ? _AdminColors.healthy
                                      : _AdminColors.critical)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Disabled',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? _AdminColors.healthy
                                    : _AdminColors.critical,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Icon(
                            mfa
                                ? Icons.verified_user_rounded
                                : Icons.shield_outlined,
                            size: 16,
                            color: mfa
                                ? _AdminColors.healthy
                                : _AdminColors.textMuted,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isActive
                                      ? Icons.block_rounded
                                      : Icons.check_circle_outline,
                                  size: 16,
                                  color: isActive
                                      ? _AdminColors.warning
                                      : _AdminColors.healthy,
                                ),
                                tooltip: isActive ? 'Deactivate' : 'Activate',
                                onPressed: () async {
                                  await _firestore
                                      .collection('users')
                                      .doc(doc.id)
                                      .update({'isActive': !isActive});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 16, color: _AdminColors.accent),
                                tooltip: 'Edit Role',
                                onPressed: () => _showEditRoleDialog(
                                    doc.id, username, roleId),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddUserDialog() {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    String selectedRole = 'role_network_admin';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: _AdminColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _AdminColors.border),
              ),
              title: const Text('Add System User',
                  style:
                      TextStyle(color: _AdminColors.textPrimary, fontSize: 16)),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameCtrl,
                      style: const TextStyle(
                          color: _AdminColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        filled: true,
                        fillColor: _AdminColors.surfaceAlt,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      style: const TextStyle(
                          color: _AdminColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        filled: true,
                        fillColor: _AdminColors.surfaceAlt,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deptCtrl,
                      style: const TextStyle(
                          color: _AdminColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        filled: true,
                        fillColor: _AdminColors.surfaceAlt,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      dropdownColor: _AdminColors.surfaceAlt,
                      style: const TextStyle(
                          color: _AdminColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'System Role',
                        filled: true,
                        fillColor: _AdminColors.surfaceAlt,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'role_network_admin',
                            child: Text('Network Administrator')),
                        DropdownMenuItem(
                            value: 'role_ict_manager',
                            child: Text('ICT Manager')),
                        DropdownMenuItem(
                            value: 'role_system_admin',
                            child: Text('System Administrator')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: _AdminColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (usernameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty) {
                      return;
                    }
                    await _firestore.collection('users').add({
                      'username': usernameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'roleId': selectedRole,
                      'department': deptCtrl.text.trim(),
                      'isActive': true,
                      'mfaEnabled': false,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AdminColors.accent,
                    foregroundColor: const Color(0xFF0A0E17),
                  ),
                  child: const Text('Create User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditRoleDialog(String userId, String username, String currentRole) {
    String selected = currentRole;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: _AdminColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _AdminColors.border),
              ),
              title: Text('Edit Role: $username',
                  style: const TextStyle(
                      color: _AdminColors.textPrimary, fontSize: 16)),
              content: DropdownButtonFormField<String>(
                value: selected,
                dropdownColor: _AdminColors.surfaceAlt,
                style: const TextStyle(
                    color: _AdminColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Assign Role',
                  filled: true,
                  fillColor: _AdminColors.surfaceAlt,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'role_network_admin',
                      child: Text('Network Administrator')),
                  DropdownMenuItem(
                      value: 'role_ict_manager', child: Text('ICT Manager')),
                  DropdownMenuItem(
                      value: 'role_system_admin',
                      child: Text('System Administrator')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selected = val);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: _AdminColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _firestore
                        .collection('users')
                        .doc(userId)
                        .update({'roleId': selected});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AdminColors.accent,
                    foregroundColor: const Color(0xFF0A0E17),
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Tab 2: Network Node Registration ──────────────────────────────────────
  Widget _buildNodeManagementTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTabHeader(
              'Network Node Registration',
              'Register and configure distributed monitoring endpoints & edge routers',
            ),
            ElevatedButton.icon(
              onPressed: _showRegisterNodeDialog,
              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
              label: const Text('Register Node'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AdminColors.accent,
                foregroundColor: const Color(0xFF0A0E17),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live Nodes Table from Firestore
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('networkNodes').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            return GlassSurface(
              radius: 14,
              tint: _AdminColors.surface,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(_AdminColors.surfaceAlt),
                  columns: const [
                    DataColumn(
                        label: Text('NODE NAME',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('IP ADDRESS',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('GEOLOCATION',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('TYPE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                    DataColumn(
                        label: Text('MONITORING',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _AdminColors.textMuted))),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['nodeName'] as String? ?? doc.id;
                    final ip = data['ipAddress'] as String? ?? '0.0.0.0';
                    final lat = data['latitude'] as num? ?? 0.0;
                    final lng = data['longitude'] as num? ?? 0.0;
                    final type = data['nodeType'] as String? ?? 'Gateway';
                    final isActive = data['isActive'] as bool? ?? true;

                    return DataRow(
                      cells: [
                        DataCell(Text(name,
                            style: const TextStyle(
                                color: _AdminColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5))),
                        DataCell(Text(ip,
                            style: const TextStyle(
                                color: _AdminColors.accent,
                                fontFamily: 'monospace',
                                fontSize: 12))),
                        DataCell(Text(
                            '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}',
                            style: const TextStyle(
                                color: _AdminColors.textSecondary,
                                fontSize: 11.5))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _AdminColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _AdminColors.border),
                            ),
                            child: Text(type,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: _AdminColors.textSecondary)),
                          ),
                        ),
                        DataCell(
                          Switch(
                            value: isActive,
                            activeColor: _AdminColors.healthy,
                            onChanged: (val) async {
                              await _firestore
                                  .collection('networkNodes')
                                  .doc(doc.id)
                                  .update({'isActive': val});
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showRegisterNodeDialog() {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '-1.2921');
    final lngCtrl = TextEditingController(text: '36.8219');
    String selectedType = 'Gateway Router';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _AdminColors.border),
          ),
          title: const Text('Register Network Node',
              style: TextStyle(color: _AdminColors.textPrimary, fontSize: 16)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(
                      color: _AdminColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Node Name (e.g. Eldoret Core Gateway)',
                    filled: true,
                    fillColor: _AdminColors.surfaceAlt,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipCtrl,
                  style: const TextStyle(
                      color: _AdminColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'IP Address (e.g. 192.168.10.1)',
                    filled: true,
                    fillColor: _AdminColors.surfaceAlt,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        style: const TextStyle(
                            color: _AdminColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          filled: true,
                          fillColor: _AdminColors.surfaceAlt,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        style: const TextStyle(
                            color: _AdminColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          filled: true,
                          fillColor: _AdminColors.surfaceAlt,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: _AdminColors.surfaceAlt,
                  style: const TextStyle(
                      color: _AdminColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Node Type',
                    filled: true,
                    fillColor: _AdminColors.surfaceAlt,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Gateway Router', child: Text('Gateway Router')),
                    DropdownMenuItem(
                        value: 'Core Switch', child: Text('Core Switch')),
                    DropdownMenuItem(
                        value: 'Edge Access Point',
                        child: Text('Edge Access Point')),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedType = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: _AdminColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || ipCtrl.text.trim().isEmpty)
                  return;
                await _firestore.collection('networkNodes').add({
                  'nodeName': nameCtrl.text.trim(),
                  'ipAddress': ipCtrl.text.trim(),
                  'latitude': double.tryParse(latCtrl.text) ?? -1.2921,
                  'longitude': double.tryParse(lngCtrl.text) ?? 36.8219,
                  'nodeType': selectedType,
                  'status': 'Healthy',
                  'isActive': true,
                  'registeredAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _AdminColors.accent,
                foregroundColor: const Color(0xFF0A0E17),
              ),
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  // ─── Tab 3: Threshold & Adaptive Policy ─────────────────────────────────────
  Widget _buildThresholdConfigTab(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          'Threshold & Adaptive Resource Policies',
          'Configure global prediction thresholds and dynamic computational load optimization',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _AdminColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Global Alert Threshold Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Fault Probability Alert Threshold',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _AdminColors.textPrimary),
                      ),
                      Text(
                        'Generates visual and audio alerts when BiLSTM model exceeds this score',
                        style: TextStyle(
                            fontSize: 11.5, color: _AdminColors.textMuted),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _AdminColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _AdminColors.accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${(_globalThreshold * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _AdminColors.accent),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _globalThreshold,
                min: 0.50,
                max: 0.95,
                divisions: 9,
                activeColor: _AdminColors.accent,
                inactiveColor: _AdminColors.border,
                onChanged: (val) => setState(() => _globalThreshold = val),
              ),
              const Divider(height: 24, color: _AdminColors.border),

              // Adaptive Prediction Reduction Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adaptive Resource Management (Objective III)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _AdminColors.textPrimary),
                      ),
                      Text(
                        'Reduces prediction rate by 90% during nominal conditions to prevent computational waste',
                        style: TextStyle(
                            fontSize: 11.5, color: _AdminColors.textMuted),
                      ),
                    ],
                  ),
                  Switch(
                    value: _adaptiveReductionEnabled,
                    activeColor: _AdminColors.healthy,
                    onChanged: (val) =>
                        setState(() => _adaptiveReductionEnabled = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sub-settings if enabled
              if (_adaptiveReductionEnabled) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reduction Trigger (Fault Prob < X)',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: _AdminColors.textMuted)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _AdminColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _AdminColors.border),
                            ),
                            child: Text(
                              '${(_reductionThreshold * 100).toStringAsFixed(0)}% (30% Target)',
                              style: const TextStyle(
                                  color: _AdminColors.textPrimary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Compute Reduction Rate',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: _AdminColors.textMuted)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _AdminColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _AdminColors.border),
                            ),
                            child: Text(
                              '$_reductionPercentage% (Objective III Target)',
                              style: const TextStyle(
                                  color: _AdminColors.healthy,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Save button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSavingConfig
                      ? null
                      : () async {
                          setState(() => _isSavingConfig = true);
                          await _firestore
                              .collection('systemConfig')
                              .doc('thresholds')
                              .set({
                            'globalThreshold': _globalThreshold,
                            'adaptiveReductionEnabled':
                                _adaptiveReductionEnabled,
                            'reductionThreshold': _reductionThreshold,
                            'reductionPercentage': _reductionPercentage,
                            'updatedAt': FieldValue.serverTimestamp(),
                            'updatedBy': user?.userId ?? 'admin',
                          });
                          setState(() => _isSavingConfig = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'System configuration saved successfully'),
                                backgroundColor: _AdminColors.healthy,
                              ),
                            );
                          }
                        },
                  icon: _isSavingConfig
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Configuration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AdminColors.accent,
                    foregroundColor: const Color(0xFF0A0E17),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tab 4: BiLSTM Model Management ────────────────────────────────────────
  Widget _buildModelManagementTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          'BiLSTM Deep Learning Model Management',
          'Inspect neural architecture, holdout validation scores, and trigger model retraining',
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Model Spec card
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _AdminColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.layers_rounded,
                            color: _AdminColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'NEURAL NETWORK SPECIFICATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: _AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _specRow('Active Model Version', 'netvision_bilstm_v1.2.0'),
                    const Divider(height: 14, color: _AdminColors.border),
                    _specRow('Input Sequence Dimensions',
                        '30 Timesteps x 5 Multivariate KPIs'),
                    const Divider(height: 14, color: _AdminColors.border),
                    _specRow('Hidden Layers',
                        '2x Bidirectional LSTM (64 Units each)'),
                    const Divider(height: 14, color: _AdminColors.border),
                    _specRow('Regularization', 'Dropout Rate = 0.20'),
                    const Divider(height: 14, color: _AdminColors.border),
                    _specRow('Output Layer',
                        'Dense Sigmoid (Fault Probability [0, 1])'),
                    const Divider(height: 14, color: _AdminColors.border),
                    _specRow('F1-Score / RMSE',
                        '0.872 / 0.078 (Holds Objective II)'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),

            // Right Model Actions card
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _AdminColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.model_training_rounded,
                            color: _AdminColors.violet, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'MODEL RETRAINING PIPELINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: _AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Retrain BiLSTM with newly aggregated time-series telemetry to maintain predictive precision and reduce false alarms.',
                      style: TextStyle(
                          fontSize: 12,
                          color: _AdminColors.textSecondary,
                          height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    if (_isRetraining) ...[
                      LinearProgressIndicator(
                        value: _trainingProgress,
                        backgroundColor: _AdminColors.surfaceAlt,
                        color: _AdminColors.accent,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_trainingStatus (${(_trainingProgress * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _AdminColors.accent),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRetraining ? null : _triggerRetraining,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(_isRetraining
                            ? 'Training in Progress...'
                            : 'Trigger Model Retraining'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AdminColors.violet,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _triggerRetraining() async {
    setState(() {
      _isRetraining = true;
      _trainingProgress = 0.1;
      _trainingStatus = 'Batch Normalization...';
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _trainingProgress = 0.45;
      _trainingStatus = 'Training Epochs 1-50...';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _trainingProgress = 0.85;
      _trainingStatus = 'Evaluating Holdout Test Metrics...';
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _trainingProgress = 1.0;
      _trainingStatus = 'Completed: F1=0.875, RMSE=0.076';
      _isRetraining = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Model retraining completed and new weights deployed!'),
        backgroundColor: _AdminColors.healthy,
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: _AdminColors.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _AdminColors.textPrimary)),
      ],
    );
  }

  // ─── Tab 5: Audit Logs & System Health ──────────────────────────────────────
  Widget _buildAuditAndHealthTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          'System Health & Security Audit Logs',
          'Live connectivity indicators, database telemetry, and administrative action logs',
        ),
        const SizedBox(height: 20),

        // 4 Health Cards
        Row(
          children: [
            Expanded(
              child: _healthCard('Firebase Auth', 'Connected',
                  Icons.vpn_key_rounded, _AdminColors.healthy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _healthCard('Cloud Firestore', 'Synced (0ms)',
                  Icons.storage_rounded, _AdminColors.healthy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _healthCard('BiLSTM Engine', 'Online (1.4s)',
                  Icons.memory_rounded, _AdminColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _healthCard('MQTT Stream', 'Active (1s tick)',
                  Icons.sensors_rounded, _AdminColors.healthy),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Audit Logs List
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _AdminColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      color: _AdminColors.textMuted, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'RECENT AUDIT LOG ENTRIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _auditLogRow('10:14:22', 'admin@netvision.local',
                  'THRESHOLD_UPDATE', 'Updated global alert threshold to 70%'),
              const Divider(height: 12, color: _AdminColors.border),
              _auditLogRow(
                  '09:48:05',
                  'jdoe@netvision.local',
                  'ALERT_ACKNOWLEDGE',
                  'Acknowledged critical latency spike on Mombasa-01'),
              const Divider(height: 12, color: _AdminColors.border),
              _auditLogRow(
                  '09:22:18',
                  'msmith@netvision.local',
                  'REPORT_EXPORT',
                  'Exported monthly executive reliability PDF'),
              const Divider(height: 12, color: _AdminColors.border),
              _auditLogRow('08:00:10', 'system', 'MODEL_INITIALIZE',
                  'BiLSTM inference runtime v1.2.0 loaded into memory'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _healthCard(
      String service, String status, IconData icon, Color color) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _AdminColors.textPrimary)),
              Text(status,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auditLogRow(String time, String user, String action, String details) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(time,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: _AdminColors.accent)),
          const SizedBox(width: 12),
          Text(user,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _AdminColors.textPrimary)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _AdminColors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _AdminColors.border),
            ),
            child: Text(action,
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: _AdminColors.violet)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(details,
                style: const TextStyle(
                    fontSize: 11.5, color: _AdminColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _AdminColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: _AdminColors.textMuted,
          ),
        ),
      ],
    );
  }
}
