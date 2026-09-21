import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import 'workflow_shared.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Settings',
    subtitle: 'Manage your Practicum Connect account and security options.',
    eyebrow: 'Home  ›  Settings',
    child: ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final account = SectionCard(
              title: 'Account Information',
              child: Column(
                children: [
                  _SettingsRow(label: 'Name', value: user.displayName),
                  _SettingsRow(label: 'Email', value: user.email),
                  _SettingsRow(label: 'Role', value: user.role.label),
                  if (user.studentNumber?.isNotEmpty == true)
                    _SettingsRow(
                      label: 'Student ID',
                      value: user.studentNumber!,
                    ),
                  if (user.staffId?.isNotEmpty == true)
                    _SettingsRow(label: 'Staff ID', value: user.staffId!),
                  if (user.program?.isNotEmpty == true)
                    _SettingsRow(label: 'Program', value: user.program!),
                  if (user.department?.isNotEmpty == true)
                    _SettingsRow(
                      label: 'Department',
                      value: user.department!,
                    ),
                  if (user.academicYear?.isNotEmpty == true)
                    _SettingsRow(
                      label: 'Academic Year',
                      value: user.academicYear!,
                      showDivider: false,
                    ),
                ],
              ),
            );
            final preferences = SectionCard(
              title: 'Preferences & Security',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.light_mode_outlined,
                          color: AppTheme.blue,
                          size: 20,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Light appearance',
                                style: TextStyle(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Practicum Connect uses a clean light interface for consistent school deployment.',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 10,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: user.email.isEmpty
                        ? null
                        : () => _sendPasswordReset(context),
                    icon: const Icon(Icons.lock_reset_rounded, size: 17),
                    label: const Text('Send password reset email'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Account role and internship details are managed by authorized school personnel.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );

            if (stacked) {
              return Column(
                children: [
                  account,
                  const SizedBox(height: 12),
                  preferences,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: account),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: preferences),
              ],
            );
          },
        ),
      ],
    ),
  );

  Future<void> _sendPasswordReset(BuildContext context) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to ${user.email}.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to send reset email.')),
      );
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(height: 1),
    ],
  );
}
