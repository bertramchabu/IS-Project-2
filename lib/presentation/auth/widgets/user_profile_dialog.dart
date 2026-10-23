import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/user_models.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../widgets/glass_ui.dart';

class UserProfileDialog extends StatefulWidget {
  final UserModel user;

  const UserProfileDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, UserModel user) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => UserProfileDialog(user: user),
    );
  }

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _departmentController;
  late final TextEditingController _phoneController;
  late bool _mfaEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _departmentController =
        TextEditingController(text: widget.user.department ?? '');
    _phoneController =
        TextEditingController(text: widget.user.phoneNumber ?? '');
    _mfaEnabled = widget.user.mfaEnabled;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final authBloc = context.read<AuthBloc>();

    final resultFuture = authBloc.stream.firstWhere(
      (state) =>
          state is AuthAuthenticated ||
          (state is AuthError && state.user != null),
    );
    authBloc.add(
      AuthProfileUpdateRequested(
        username: _usernameController.text.trim(),
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        mfaEnabled: _mfaEnabled,
      ),
    );

    final result = await resultFuture;
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
            SizedBox(width: 8),
            Text('Profile updated successfully'),
          ],
        ),
        backgroundColor: const Color(0xFF111827),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF1F2A3A)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgSurface = Color(0xFF111827);
    const bgSurfaceAlt = Color(0xFF1A2332);
    const borderColor = Color(0xFF1F2A3A);
    const accentColor = Color(0xFF00E5FF);
    const textPrimary = Color(0xFFF1F5F9);
    const textMuted = Color(0xFF94A3B8);

    final dateFormat = DateFormat('MMM d, yyyy • HH:mm');
    final initials = widget.user.username.isNotEmpty
        ? widget.user.username[0].toUpperCase()
        : 'U';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 520,
        child: GlassSurface(
          radius: 20,
          tint: bgSurface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [accentColor, Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: accentColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  widget.user.role.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.user.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username field
                        const Text(
                          'Full Name / Username',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          style:
                              const TextStyle(color: textPrimary, fontSize: 13),
                          decoration: _inputDecoration(
                              'e.g. John Doe', Icons.person_outline),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Username is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Department & Phone Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Department',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _departmentController,
                                    style: const TextStyle(
                                        color: textPrimary, fontSize: 13),
                                    decoration: _inputDecoration(
                                        'e.g. NOC Infrastructure',
                                        Icons.business_outlined),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phone Number',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _phoneController,
                                    style: const TextStyle(
                                        color: textPrimary, fontSize: 13),
                                    decoration: _inputDecoration(
                                        '+254 700 000 000',
                                        Icons.phone_outlined),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Security / MFA Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: bgSurfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _mfaEnabled
                                      ? const Color(0xFF22C55E)
                                          .withOpacity(0.12)
                                      : Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _mfaEnabled
                                      ? Icons.security_rounded
                                      : Icons.gpp_maybe_outlined,
                                  color: _mfaEnabled
                                      ? const Color(0xFF22C55E)
                                      : Colors.orange,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Multi-Factor Authentication (MFA)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _mfaEnabled
                                          ? 'Enhanced 2FA protection active'
                                          : 'Recommended for elevated privileges',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _mfaEnabled,
                                activeColor: accentColor,
                                onChanged: (val) {
                                  setState(() => _mfaEnabled = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Account metadata
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bgSurfaceAlt.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: borderColor.withOpacity(0.6)),
                          ),
                          child: Column(
                            children: [
                              _metaRow('User ID', widget.user.userId, textMuted,
                                  textPrimary),
                              const Divider(height: 12, color: borderColor),
                              _metaRow(
                                  'Member Since',
                                  dateFormat.format(widget.user.createdAt),
                                  textMuted,
                                  textPrimary),
                              if (widget.user.lastLogin != null) ...[
                                const Divider(height: 12, color: borderColor),
                                _metaRow(
                                    'Last Login',
                                    dateFormat.format(widget.user.lastLogin!),
                                    textMuted,
                                    textPrimary),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Modal Actions
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: textMuted,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: const Color(0xFF0A0E17),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0A0E17),
                              ),
                            )
                          : const Text(
                              'Save Profile',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1A2332),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1F2A3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _metaRow(
      String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: labelColor),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
