import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import 'document_workflow_screens.dart';
import 'workflow_shared.dart';

class StudentNotificationPanelScreen extends StatefulWidget {
  const StudentNotificationPanelScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  State<StudentNotificationPanelScreen> createState() =>
      _StudentNotificationPanelScreenState();
}

class _StudentNotificationPanelScreenState
    extends State<StudentNotificationPanelScreen> {
  String _query = '';
  String _type = 'all';
  bool _unreadOnly = false;
  NotificationRecord? _selected;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<NotificationRecord>>(
    stream: widget.repository.watchNotifications(widget.user),
    builder: (context, snapshot) {
      final all = snapshot.data ?? const <NotificationRecord>[];
      final unread = all
          .where((notice) => !notice.isReadBy(widget.user.uid))
          .length;
      final records = all.where((notice) {
        final queryMatches =
            _query.isEmpty ||
            '${notice.title} ${notice.message}'.toLowerCase().contains(_query);
        final typeMatches = _type == 'all' || notice.type == _type;
        final unreadMatches = !_unreadOnly || !notice.isReadBy(widget.user.uid);
        return queryMatches && typeMatches && unreadMatches;
      }).toList();
      final selected =
          _selected != null &&
              records.any((notice) => notice.id == _selected!.id)
          ? records.firstWhere((notice) => notice.id == _selected!.id)
          : records.firstOrNull;
      return WorkflowPage(
        title: 'Notifications',
        subtitle:
            'View internship updates, reminders, and coordinator feedback.',
        actions: [StatusBadge('$unread unread notifications')],
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search notifications',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.toLowerCase()),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items:
                        const {
                              'all': 'All types',
                              'general': 'General',
                              'document_feedback': 'Document feedback',
                              'deadline': 'Deadlines',
                              'status_update': 'Status updates',
                            }.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => _type = value ?? 'all'),
                  ),
                ),
                FilterChip(
                  label: const Text('Unread only'),
                  selected: _unreadOnly,
                  onSelected: (value) => setState(() => _unreadOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = Card(
                    child: records.isEmpty
                        ? const EmptyWorkflowState(
                            icon: Icons.notifications_none,
                            title: 'No notifications',
                            message: 'New internship updates will appear here.',
                          )
                        : ListView.separated(
                            itemCount: records.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final notice = records[index];
                              final isUnread = !notice.isReadBy(
                                widget.user.uid,
                              );
                              return ListTile(
                                selected: selected?.id == notice.id,
                                selectedTileColor: AppTheme.blue.withValues(
                                  alpha: .08,
                                ),
                                leading: Icon(
                                  _icon(notice.type),
                                  color: isUnread
                                      ? AppTheme.blue
                                      : Colors.black38,
                                ),
                                title: Text(
                                  notice.title,
                                  style: TextStyle(
                                    fontWeight: isUnread
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  notice.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      DateFormat.MMMd().format(
                                        notice.createdAt,
                                      ),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    if (isUnread)
                                      const Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: AppTheme.blue,
                                      ),
                                  ],
                                ),
                                onTap: () async {
                                  setState(() => _selected = notice);
                                  await widget.repository.markNotificationRead(
                                    user: widget.user,
                                    notification: notice,
                                  );
                                },
                              );
                            },
                          ),
                  );
                  final details = selected == null
                      ? const EmptyWorkflowState(
                          icon: Icons.mark_email_unread_outlined,
                          title: 'Select a notification',
                          message: 'Details and available actions appear here.',
                        )
                      : _NotificationDetails(
                          user: widget.user,
                          notice: selected,
                          repository: widget.repository,
                        );
                  if (constraints.maxWidth < 900)
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 350,
                          child: SingleChildScrollView(child: details),
                        ),
                      ],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: list),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(child: details),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  IconData _icon(String type) => switch (type) {
    'document_feedback' => Icons.rate_review_outlined,
    'deadline' => Icons.event_outlined,
    'status_update' => Icons.track_changes_outlined,
    _ => Icons.notifications_outlined,
  };
}

class _NotificationDetails extends StatelessWidget {
  const _NotificationDetails({
    required this.user,
    required this.notice,
    required this.repository,
  });
  final AppUser user;
  final NotificationRecord notice;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: notice.title,
    trailing: StatusBadge(notice.isReadBy(user.uid) ? 'Read' : 'Unread'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DateFormat.yMMMd().add_jm().format(notice.createdAt),
          style: const TextStyle(color: Colors.black54),
        ),
        const Divider(height: 28),
        Text(notice.message, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 20),
        if (notice.relatedId != null)
          FilledButton.icon(
            onPressed: () async {
              final record = await repository.getRequirement(notice.relatedId!);
              if (record == null || record.storagePath == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('The related document is not available.'),
                    ),
                  );
                }
                return;
              }
              if (context.mounted) {
                await openStorageDocument(
                  context,
                  repository,
                  record.storagePath,
                );
              }
            },
            icon: const Icon(Icons.description_outlined),
            label: const Text('View related requirement'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Status Tracker')),
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: StudentStatusTrackerScreen(
                    user: user,
                    repository: repository,
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.track_changes_outlined),
          label: const Text('Open status tracker'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              repository.markNotificationRead(user: user, notification: notice),
          icon: const Icon(Icons.mark_email_read_outlined),
          label: const Text('Mark as read'),
        ),
      ],
    ),
  );
}
