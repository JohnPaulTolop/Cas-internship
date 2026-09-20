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
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 840;
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
                      controller: widget.controller,
                    );
                    return wide
                        ? SizedBox(
                            height: 720,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: intro),
                                Expanded(child: form),
                              ],
                            ),
                          )
                        : Column(children: [intro, form]);
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
    padding: const EdgeInsets.all(44),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [AppTheme.blue, AppTheme.deepBlue]),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.hub_outlined, size: 58, color: Colors.white),
        SizedBox(height: 24),
        Text(
          'Practicum Connect',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'A unified internship workspace for students, coordinators, and administrators.',
          style: TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
        ),
        SizedBox(height: 34),
        _FeatureLine(
          icon: Icons.fact_check_outlined,
          text: 'Track and verify requirements',
        ),
        _FeatureLine(
          icon: Icons.punch_clock_outlined,
          text: 'Monitor DTR and rendered hours',
        ),
        _FeatureLine(
          icon: Icons.folder_copy_outlined,
          text: 'Keep documents organized',
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
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD166)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
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
    required this.controller,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onCreateStudent;
  final AppController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(44),
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
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Sign in to open your authorized workspace.'),
          const SizedBox(height: 28),
          if (controller.error != null) ...[
            MaterialBanner(
              content: Text(controller.error!),
              leading: const Icon(Icons.error_outline, color: Colors.red),
              backgroundColor: const Color(0xFFFFECEC),
              actions: [
                TextButton(
                  onPressed: controller.clearError,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
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
              prefixIcon: const Icon(Icons.lock_outline),
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
          const SizedBox(height: 24),
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
                : const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.busy ? null : onCreateStudent,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Create student account'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Coordinator and administrator accounts are issued by an administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
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
