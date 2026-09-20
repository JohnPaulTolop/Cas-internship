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
  final _ratings = <String, int>{
    'professionalism': 3,
    'workQuality': 3,
    'attendance': 3,
    'communication': 3,
    'initiative': 3,
  };
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F5FF), Color(0xFFE8E4FF)],
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<SupervisorEvaluationRecord?>(
          stream: widget.repository.watchPublicEvaluation(widget.token),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
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
              return const _Message(
                icon: Icons.link_off_outlined,
                title: 'Invalid evaluation link',
                message: 'Ask the practicum coordinator for a new link.',
              );
            }
            if (evaluation.submitted) {
              return const _Message(
                icon: Icons.task_alt,
                title: 'Evaluation submitted',
                message: 'Thank you. This one-time evaluation has been locked.',
              );
            }
            if (evaluation.archived) {
              return const _Message(
                icon: Icons.inventory_2_outlined,
                title: 'Evaluation archived',
                message: 'This academic-year record is no longer active.',
              );
            }
            if (evaluation.expired) {
              return const _Message(
                icon: Icons.timer_off_outlined,
                title: 'Evaluation link expired',
                message: 'Ask the practicum coordinator to issue a new link.',
              );
            }
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.workspace_premium_outlined,
                            color: AppTheme.blue,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Supervisor Evaluation',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${evaluation.studentName} • ${evaluation.companyName}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          ..._ratings.keys.map(
                            (key) => _RatingField(
                              label: _label(key),
                              value: _ratings[key]!,
                              onChanged: (value) =>
                                  setState(() => _ratings[key] = value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _comments,
                            maxLines: 5,
                            maxLength: 3000,
                            decoration: const InputDecoration(
                              labelText: 'Comments and recommendations',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: const Text('Submit final evaluation'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This link can be submitted only once.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  String _label(String key) => switch (key) {
    'workQuality' => 'Quality of work',
    'professionalism' => 'Professionalism',
    'attendance' => 'Attendance and punctuality',
    'communication' => 'Communication',
    _ => 'Initiative',
  };

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.submitSupervisorEvaluation(
        token: widget.token,
        ratings: Map.unmodifiable(_ratings),
        comments: _comments.text,
      );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stars = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => IconButton(
              tooltip: '${index + 1} of 5',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              onPressed: () => onChanged(index + 1),
              icon: Icon(
                index < value ? Icons.star : Icons.star_border,
                color: const Color(0xFFF5A623),
              ),
            ),
          ),
        );
        return constraints.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label), stars],
              )
            : Row(
                children: [
                  Expanded(child: Text(label)),
                  stars,
                ],
              );
      },
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.blue),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
