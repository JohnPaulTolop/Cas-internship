import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
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
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Widget buildHeader() => LayoutBuilder(
        builder: (context, headerConstraints) {
          final titleBlock = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: const TextStyle(
                      color: AppTheme.blue,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .15,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: headerConstraints.maxWidth < 520 ? 20 : 23,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                    letterSpacing: -.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          );

          if (actions.isEmpty) return titleBlock;

          if (headerConstraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actions,
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 20),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: actions,
                  ),
                ),
              ),
            ],
          );
        },
      );

      Widget buildPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHeader(),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      );

      if (constraints.hasBoundedHeight) return buildPage();

      final screenHeight = MediaQuery.sizeOf(context).height;
      final fallbackHeight = screenHeight > 540 ? screenHeight - 116 : 440.0;
      return SizedBox(height: fallbackHeight, child: buildPage());
    },
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  final String? title;
  final String? subtitle;
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  Flexible(child: trailing!),
                ],
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
  const StatusBadge(this.label, {super.key, this.compact = false});
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = normalized.contains('verif') ||
            normalized.contains('approv') ||
            normalized == 'active' ||
            normalized.contains('complete') ||
            normalized.contains('passed')
        ? AppTheme.success
        : normalized.contains('reject') || normalized.contains('expire')
        ? AppTheme.danger
        : normalized.contains('revision') ||
              normalized.contains('near') ||
              normalized.contains('renew') ||
              normalized.contains('pending')
        ? AppTheme.warning
        : normalized.contains('review')
        ? AppTheme.purple
        : AppTheme.blue;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: compact ? 9.8 : 10.8,
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
    this.color = AppTheme.blue,
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
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 9.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class WorkspaceTabs extends StatelessWidget {
  const WorkspaceTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<int>? counts;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surfaceSoft,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selectedIndex;
          final count = counts != null && index < counts!.length
              ? counts![index]
              : null;
          return InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: active ? Border.all(color: AppTheme.border) : null,
              ),
              child: Row(
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: active ? AppTheme.deepBlue : AppTheme.muted,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.sky : const Color(0xFFE9EEF5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: active ? AppTheme.deepBlue : AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.labelWidth = 104});
  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 11.3,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
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
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: AppTheme.blue),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12.2),
            ),
          ],
        ),
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
  if (!AppConfig.hasSupabaseConfig) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppConfig.missingSupabaseMessage),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    return;
  }
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
  ReviewStatus.verified => AppTheme.success,
  ReviewStatus.needsRevision => AppTheme.warning,
  ReviewStatus.rejected => AppTheme.danger,
  ReviewStatus.underReview => AppTheme.purple,
  ReviewStatus.pending => AppTheme.blue,
};
