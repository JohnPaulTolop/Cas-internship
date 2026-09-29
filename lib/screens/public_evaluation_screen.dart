import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';

class PublicEvaluationScreen extends StatefulWidget {
  const PublicEvaluationScreen({
    super.key,
    required this.token,
    required this.repository,
  });

  final String token;
  final PracticumRepository repository;

  @override
  State<PublicEvaluationScreen> createState() => _PublicEvaluationScreenState();
}

class _PublicEvaluationScreenState extends State<PublicEvaluationScreen> {
  final _comments = TextEditingController();
  final _email = TextEditingController();
  final _ratings = <String, int>{
    'professionalism': 3,
    'workQuality': 3,
    'attendance': 3,
    'communication': 3,
    'initiative': 3,
  };

  bool _submitting = false;
  bool _verifying = false;
  bool _authorized = false;
  bool _confirmed = false;
  String? _error;
  late Future<PublicEvaluationAccessRecord> _evaluationFuture;

  @override
  void initState() {
    super.initState();
    _evaluationFuture = widget.repository.loadPublicEvaluation(widget.token);
  }

  @override
  void dispose() {
    _comments.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: SafeArea(
      child: FutureBuilder<PublicEvaluationAccessRecord>(
        future: _evaluationFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _PortalMessage(
              icon: Icons.link_off_outlined,
              title: 'Evaluation link unavailable',
              message: '${snapshot.error}',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final evaluation = snapshot.data;
          if (evaluation == null) {
            return const _PortalMessage(
              icon: Icons.link_off_outlined,
              title: 'Invalid evaluation link',
              message: 'Ask the practicum coordinator for a new link.',
            );
          }
          if (evaluation.submitted) {
            return const _PortalMessage(
              icon: Icons.task_alt_rounded,
              title: 'Evaluation submitted',
              message:
                  'Thank you. This one-time supervisor evaluation has been submitted and locked.',
              success: true,
            );
          }
          if (evaluation.archived) {
            return const _PortalMessage(
              icon: Icons.inventory_2_outlined,
              title: 'Evaluation archived',
              message: 'This academic-year record is no longer active.',
            );
          }
          if (evaluation.expired) {
            return const _PortalMessage(
              icon: Icons.timer_off_outlined,
              title: 'Evaluation link expired',
              message: 'Ask the practicum coordinator to issue a new link.',
            );
          }

          return _buildPortal(context, evaluation);
        },
      ),
    ),
  );

  Widget _buildPortal(
    BuildContext context,
    PublicEvaluationAccessRecord evaluation,
  ) {
    return Column(
      children: [
        _PortalHeader(
          supervisorName: evaluation.supervisorName,
          authorized: _authorized,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervisor Evaluation Submission',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Complete the evaluation for the assigned student intern.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 860;
                        final internCard = _AssignedInternCard(
                          evaluation: evaluation,
                        );
                        final evaluationCard = _EvaluationCard(
                          evaluation: evaluation,
                          authorized: _authorized,
                          verifying: _verifying,
                          submitting: _submitting,
                          confirmed: _confirmed,
                          error: _error,
                          emailController: _email,
                          commentsController: _comments,
                          ratings: _ratings,
                          onVerify: _verifyAccess,
                          onRatingChanged: (key, value) =>
                              setState(() => _ratings[key] = value),
                          onConfirmedChanged: (value) =>
                              setState(() => _confirmed = value),
                          onSubmit: _submit,
                          labelFor: _label,
                        );

                        if (!wide) {
                          return Column(
                            children: [
                              internCard,
                              const SizedBox(height: 16),
                              evaluationCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 310, child: internCard),
                            const SizedBox(width: 16),
                            Expanded(child: evaluationCard),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const _PortalFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _label(String key) => switch (key) {
    'workQuality' => 'Quality of work',
    'professionalism' => 'Professionalism',
    'attendance' => 'Attendance and punctuality',
    'communication' => 'Communication',
    _ => 'Initiative',
  };

  Future<void> _verifyAccess() async {
    final entered = _email.text.trim();
    if (entered.isEmpty || !entered.contains('@')) {
      setState(() {
        _error = 'Enter the registered supervisor email address.';
      });
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await widget.repository.verifyPublicEvaluationAccess(
        token: widget.token,
        supervisorEmail: entered,
      );
      if (mounted) {
        setState(() {
          _verifying = false;
          _authorized = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _authorized = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_confirmed) {
      setState(() {
        _error =
            'Confirm that the evaluation is complete and accurate before submitting.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.repository.submitSupervisorEvaluation(
        token: widget.token,
        supervisorEmail: _email.text.trim(),
        ratings: Map.unmodifiable(_ratings),
        comments: _comments.text,
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _evaluationFuture = widget.repository.loadPublicEvaluation(
            widget.token,
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '$error';
        });
      }
    }
  }
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({required this.supervisorName, required this.authorized});

  final String supervisorName;
  final bool authorized;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(supervisorName);

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          return Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: AppTheme.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practicum Connect',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Supervisor Evaluation Portal',
                    style: TextStyle(color: AppTheme.muted, fontSize: 10.5),
                  ),
                ],
              ),
              const Spacer(),
              if (!compact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: authorized
                        ? const Color(0xFFF0FDF4)
                        : AppTheme.surfaceBlue,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: authorized
                          ? const Color(0xFFBBF7D0)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        authorized
                            ? Icons.lock_rounded
                            : Icons.lock_outline_rounded,
                        size: 15,
                        color: authorized ? AppTheme.success : AppTheme.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        authorized ? 'Secure access verified' : 'Secure access',
                        style: TextStyle(
                          color: authorized
                              ? const Color(0xFF15803D)
                              : AppTheme.navy,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
              ],
              CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.sky,
                foregroundColor: AppTheme.deepBlue,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supervisorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      const Text(
                        'Industry Supervisor',
                        style: TextStyle(color: AppTheme.muted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AssignedInternCard extends StatelessWidget {
  const _AssignedInternCard({required this.evaluation});

  final PublicEvaluationAccessRecord evaluation;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(evaluation.studentName);

    return _Panel(
      title: 'Assigned Intern',
      icon: Icons.person_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderStrong),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    evaluation.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.subtle,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.sky,
                foregroundColor: AppTheme.deepBlue,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evaluation.studentName,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Student Intern',
                      style: TextStyle(color: AppTheme.muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow(
            icon: Icons.business_outlined,
            label: 'Institution',
            value: evaluation.companyName.isEmpty
                ? 'Not specified'
                : evaluation.companyName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Supervisor',
            value: evaluation.supervisorName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'Link Valid Until',
            value: _dateLabel(evaluation.expiresAt),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFFB45309),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This secure evaluation link is assigned to one intern and can only be submitted once.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({
    required this.evaluation,
    required this.authorized,
    required this.verifying,
    required this.submitting,
    required this.confirmed,
    required this.error,
    required this.emailController,
    required this.commentsController,
    required this.ratings,
    required this.onVerify,
    required this.onRatingChanged,
    required this.onConfirmedChanged,
    required this.onSubmit,
    required this.labelFor,
  });

  final PublicEvaluationAccessRecord evaluation;
  final bool authorized;
  final bool verifying;
  final bool submitting;
  final bool confirmed;
  final String? error;
  final TextEditingController emailController;
  final TextEditingController commentsController;
  final Map<String, int> ratings;
  final VoidCallback onVerify;
  final void Function(String key, int value) onRatingChanged;
  final ValueChanged<bool> onConfirmedChanged;
  final VoidCallback onSubmit;
  final String Function(String key) labelFor;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Evaluation Form',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!authorized)
            _AccessVerification(
              evaluation: evaluation,
              controller: emailController,
              verifying: verifying,
              error: error,
              onVerify: onVerify,
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    color: AppTheme.blue,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Rate each area from 1 to 5, where 1 is the lowest and 5 is the highest. Review your answers before final submission.',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...ratings.keys.map(
              (key) => _RatingField(
                label: labelFor(key),
                value: ratings[key]!,
                onChanged: (value) => onRatingChanged(key, value),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Additional Feedback (Optional)',
              style: TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: commentsController,
              minLines: 4,
              maxLines: 6,
              maxLength: 3000,
              decoration: const InputDecoration(
                hintText:
                    'Share comments about the intern’s performance, strengths, areas for improvement, or recommendations.',
                alignLabelWithHint: true,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              _ErrorBox(message: error!),
            ],
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: submitting ? null : () => onConfirmedChanged(!confirmed),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: confirmed,
                      onChanged: submitting
                          ? null
                          : (value) => onConfirmedChanged(value ?? false),
                    ),
                    const SizedBox(width: 2),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I confirm that the evaluation is complete, accurate, and final.',
                              style: TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'After submission, this evaluation cannot be edited.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: submitting || !confirmed ? null : onSubmit,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: const Text('Submit Final Evaluation'),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: Color(0xFFB45309),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Once submitted, the evaluation will be locked and can no longer be edited.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessVerification extends StatelessWidget {
  const _AccessVerification({
    required this.evaluation,
    required this.controller,
    required this.verifying,
    required this.error,
    required this.onVerify,
  });

  final PublicEvaluationAccessRecord evaluation;
  final TextEditingController controller;
  final bool verifying;
  final String? error;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_person_outlined, color: AppTheme.blue, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure Access Verification',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Verify your registered supervisor email before the evaluation form is unlocked.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'This evaluation is assigned to ${evaluation.supervisorName}.',
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) {
            if (!verifying) onVerify();
          },
          decoration: const InputDecoration(
            labelText: 'Registered supervisor email',
            hintText: 'name@company.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          _ErrorBox(message: error!),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: verifying ? null : onVerify,
            icon: verifying
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Verify Access'),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.blue, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ],
    ),
  );
}

class _RatingField extends StatelessWidget {
  const _RatingField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.surfaceSoft,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        final stars = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final selected = index < value;
            return IconButton(
              tooltip: '${index + 1} of 5',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: const EdgeInsets.all(5),
              onPressed: () => onChanged(index + 1),
              icon: Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                color: selected ? AppTheme.warning : AppTheme.subtle,
                size: 23,
              ),
            );
          }),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: stars),
                  _RatingValue(value: value),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            stars,
            const SizedBox(width: 8),
            _RatingValue(value: value),
          ],
        );
      },
    ),
  );
}

class _RatingValue extends StatelessWidget {
  const _RatingValue({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(
      '$value/5',
      style: const TextStyle(
        color: AppTheme.navy,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 14, color: AppTheme.muted),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 9.5),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.danger,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppTheme.danger,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PortalFooter extends StatelessWidget {
  const _PortalFooter();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppTheme.border)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        const brand = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Practicum Connect',
              style: TextStyle(
                color: AppTheme.blue,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'A partnership for real-world learning.',
              style: TextStyle(color: AppTheme.muted, fontSize: 9.5),
            ),
          ],
        );
        const security = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.muted),
            SizedBox(width: 5),
            Text(
              'Secure  •  Simple  •  Purpose-Driven',
              style: TextStyle(color: AppTheme.muted, fontSize: 9.5),
            ),
          ],
        );

        if (compact) {
          return const Column(children: [brand, SizedBox(height: 8), security]);
        }
        return const Row(children: [brand, Spacer(), security]);
      },
    ),
  );
}

class _PortalMessage extends StatelessWidget {
  const _PortalMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.success = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.background,
    child: Column(
      children: [
        const _SimplePortalHeader(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(34),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: success
                            ? const Color(0xFFF0FDF4)
                            : AppTheme.surfaceBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        size: 30,
                        color: success ? AppTheme.success : AppTheme.blue,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SimplePortalHeader extends StatelessWidget {
  const _SimplePortalHeader();

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      color: AppTheme.surface,
      border: Border(bottom: BorderSide(color: AppTheme.border)),
    ),
    child: const Row(
      children: [
        Icon(Icons.work_outline_rounded, color: AppTheme.blue, size: 22),
        SizedBox(width: 9),
        Text(
          'Practicum Connect',
          style: TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        Spacer(),
        Icon(Icons.lock_outline_rounded, color: AppTheme.muted, size: 16),
        SizedBox(width: 5),
        Text(
          'Secure Evaluation Portal',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) return 'SI';
  return parts.map((part) => part[0].toUpperCase()).join();
}

String _dateLabel(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
