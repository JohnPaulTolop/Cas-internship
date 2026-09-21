import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/app_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.controller.signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FBFF), Color(0xFFEEF5FF), Color(0xFFF7F9FC)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    final intro = const _LoginIntro();
                    final form = _LoginForm(
                      formKey: _formKey,
                      email: _email,
                      password: _password,
                      obscure: _obscure,
                      onTogglePassword: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                      onCreateStudent: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _StudentSignUpDialog(controller: widget.controller),
                      ),
                      onCreateCoordinator: () => showDialog<void>(
                        context: context,
                        builder: (_) => _CoordinatorSignUpDialog(
                          controller: widget.controller,
                        ),
                      ),
                      controller: widget.controller,
                    );
                    if (!wide) {
                      return Column(children: [intro, form]);
                    }
                    return SizedBox(
                      height: 700,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 9, child: intro),
                          Expanded(flex: 10, child: form),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(42),
    decoration: const BoxDecoration(
      color: AppTheme.surfaceBlue,
      border: Border(right: BorderSide(color: AppTheme.border)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.blue,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Padding(
            padding: EdgeInsets.all(11),
            child: Icon(Icons.hub_outlined, size: 30, color: Colors.white),
          ),
        ),
        SizedBox(height: 28),
        Text(
          'Practicum Connect',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 31,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'A clear, organized internship workspace for students, coordinators, and administrators.',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
        SizedBox(height: 30),
        _FeatureLine(
          icon: Icons.fact_check_outlined,
          text: 'Track and verify internship requirements',
        ),
        _FeatureLine(
          icon: Icons.schedule_outlined,
          text: 'Monitor DTR and rendered hours',
        ),
        _FeatureLine(
          icon: Icons.folder_copy_outlined,
          text: 'Keep documents organized and accessible',
        ),
      ],
    ),
  );
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.blue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onCreateStudent,
    required this.onCreateCoordinator,
    required this.controller,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onCreateStudent;
  final VoidCallback onCreateCoordinator;
  final AppController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 42),
    child: Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Sign in to continue to your internship workspace.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 28),
          if (controller.error != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: .07),
                border: Border.all(color: AppTheme.danger.withValues(alpha: .20)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      controller.error!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.text),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Dismiss',
                    onPressed: controller.clearError,
                    icon: const Icon(Icons.close_rounded, size: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) => value == null || !value.contains('@')
                ? 'Enter a valid email address.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: obscure,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter your password.' : null,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: controller.busy ? null : onSubmit,
            icon: controller.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label: const Text('Sign in'),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'NEW ACCOUNT',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 410;
              final studentButton = OutlinedButton.icon(
                onPressed: controller.busy ? null : onCreateStudent,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Student registration'),
              );
              final coordinatorButton = OutlinedButton.icon(
                onPressed: controller.busy ? null : onCreateCoordinator,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Program Coordinator registration'),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    studentButton,
                    const SizedBox(height: 10),
                    coordinatorButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: studentButton),
                  const SizedBox(width: 10),
                  Expanded(child: coordinatorButton),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Students can register immediately. Program Coordinator registrations are reviewed by a CAS College Coordinator / SIP Admin before access is activated.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StudentSignUpDialog extends StatefulWidget {
  const _StudentSignUpDialog({required this.controller});

  final AppController controller;

  @override
  State<_StudentSignUpDialog> createState() => _StudentSignUpDialogState();
}

class _StudentSignUpDialogState extends State<_StudentSignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentNumber = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _studentNumber.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final success = await widget.controller.registerStudent(
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
      studentNumber: _studentNumber.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _submitting = false;
      _error = widget.controller.error ?? 'Account creation failed.';
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create student account'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Complete name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Enter your complete name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentNumber,
                decoration: const InputDecoration(
                  labelText: 'Student number',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your student number.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Use at least six characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (value) => value != _password.text
                    ? 'The passwords do not match.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1),
        label: const Text('Create account'),
      ),
    ],
  );
}

class _CoordinatorSignUpDialog extends StatefulWidget {
  const _CoordinatorSignUpDialog({required this.controller});

  final AppController controller;

  @override
  State<_CoordinatorSignUpDialog> createState() =>
      _CoordinatorSignUpDialogState();
}

class _CoordinatorSignUpDialogState extends State<_CoordinatorSignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _staffId = TextEditingController();
  final _department = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _staffId.dispose();
    _department.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final success = await widget.controller.registerCoordinatorRequest(
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
      staffId: _staffId.text,
      department: _department.text,
    );
    if (!mounted) return;

    if (!success) {
      setState(() {
        _submitting = false;
        _error = widget.controller.error ?? 'Program Coordinator request failed.';
      });
      return;
    }

    Navigator.pop(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_read_outlined,
          color: AppTheme.blue,
          size: 34,
        ),
        title: const Text('Registration request sent'),
        content: const Text(
          'Your coordinator account has been created as a pending request. '
          'A CAS College Coordinator / SIP Admin must verify your staff information before '
          'you can sign in to the coordinator workspace.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Program Coordinator registration request'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppTheme.blue,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Program Coordinator access is not automatic. Submit your real school staff information. An administrator will review and approve the request.',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.danger.withValues(alpha: .20),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Complete name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Enter your complete name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _staffId,
                decoration: const InputDecoration(
                  labelText: 'Employee / Faculty ID',
                  hintText: 'School-issued ID number',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your employee or faculty ID.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _department,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Department / College / Office',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your department, college, or office.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'School email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Use at least six characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (value) => value != _password.text
                    ? 'The passwords do not match.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: const Text('Submit for verification'),
      ),
    ],
  );
}
