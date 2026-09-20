import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';

class WorkflowPage extends StatelessWidget {
  const WorkflowPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
      const SizedBox(height: 18),
      Expanded(child: child),
    ],
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color =
        normalized.contains('verif') ||
            normalized == 'active' ||
            normalized.contains('complete')
        ? const Color(0xFF159A61)
        : normalized.contains('reject') || normalized.contains('expire')
        ? const Color(0xFFD14343)
        : normalized.contains('revision') || normalized.contains('near')
        ? const Color(0xFFE4931A)
        : AppTheme.blue;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: const TextStyle(color: Colors.black54)),
                if (caption != null)
                  Text(caption!, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class EmptyWorkflowState extends StatelessWidget {
  const EmptyWorkflowState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Colors.black26),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String shortDate(DateTime? value) =>
    value == null ? '—' : DateFormat.yMMMd().format(value);

Future<void> openStorageDocument(
  BuildContext context,
  PracticumRepository repository,
  String? storagePath,
) async {
  if (storagePath == null || storagePath.isEmpty) return;
  try {
    final url = await repository.createDownloadUrl(storagePath);
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched) throw StateError('The browser could not open the file.');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open document: $error')),
      );
    }
  }
}

Color reviewStatusColor(ReviewStatus status) => switch (status) {
  ReviewStatus.verified => const Color(0xFF159A61),
  ReviewStatus.needsRevision => const Color(0xFFE4931A),
  ReviewStatus.rejected => const Color(0xFFD14343),
  ReviewStatus.underReview => const Color(0xFF6C63FF),
  ReviewStatus.pending => AppTheme.blue,
};
