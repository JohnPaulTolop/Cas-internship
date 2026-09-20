import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import 'workflow_shared.dart';

class MoaManagementScreen extends StatefulWidget {
  const MoaManagementScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  State<MoaManagementScreen> createState() => _MoaManagementScreenState();
}

class _MoaManagementScreenState extends State<MoaManagementScreen> {
  String _query = '';
  String _status = 'All MOAs';
  MoaRecord? _selected;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'MOA Management',
    subtitle:
        'Manage, monitor, and track agreements with partner institutions.',
    actions: [
      OutlinedButton.icon(
        onPressed: () => _showMoaDialog(context),
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload MOA file'),
      ),
      FilledButton.icon(
        onPressed: () => _showMoaDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New MOA'),
      ),
    ],
    child: StreamBuilder<List<MoaRecord>>(
      stream: widget.repository.watchMoas(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <MoaRecord>[];
        final records = all.where((record) {
          final matchesQuery =
              _query.isEmpty ||
              '${record.partnerName} ${record.moaNumber} ${record.programs.join(' ')}'
                  .toLowerCase()
                  .contains(_query);
          final matchesStatus =
              _status == 'All MOAs' || record.status == _status;
          return matchesQuery && matchesStatus;
        }).toList();
        final selected =
            _selected != null &&
                records.any((record) => record.id == _selected!.id)
            ? records.firstWhere((record) => record.id == _selected!.id)
            : records.firstOrNull;
        return Column(
          children: [
            _MoaStats(records: all),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search institution or reference',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.toLowerCase()),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items:
                        const [
                              'All MOAs',
                              'Active',
                              'Nearing expiration',
                              'Expired',
                              'For renewal',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'All MOAs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = _MoaList(
                    records: records,
                    selected: selected,
                    onSelect: (record) => setState(() => _selected = record),
                  );
                  final detail = selected == null
                      ? const EmptyWorkflowState(
                          icon: Icons.handshake_outlined,
                          title: 'No MOA selected',
                          message: 'Select an agreement to view details.',
                        )
                      : _MoaDetails(
                          record: selected,
                          repository: widget.repository,
                          onEdit: () =>
                              _showMoaDialog(context, existing: selected),
                          onRenew: () => _renew(context, selected),
                          onDelete: () => _delete(context, selected),
                        );
                  if (constraints.maxWidth < 980)
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 480,
                          child: SingleChildScrollView(child: detail),
                        ),
                      ],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: list),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(child: detail),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _showMoaDialog(
    BuildContext context, {
    MoaRecord? existing,
  }) async {
    final partner = TextEditingController(text: existing?.partnerName);
    final number = TextEditingController(text: existing?.moaNumber);
    final programs = TextEditingController(text: existing?.programs.join(', '));
    final contactName = TextEditingController(text: existing?.contactName);
    final contactEmail = TextEditingController(text: existing?.contactEmail);
    final contactPhone = TextEditingController(text: existing?.contactPhone);
    final remarks = TextEditingController(text: existing?.remarks);
    var startDate = existing?.startDate ?? DateTime.now();
    var endDate =
        existing?.endDate ?? DateTime.now().add(const Duration(days: 365));
    var manualStatus = existing?.manualStatus;
    PlatformFile? file;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create MOA' : 'Edit MOA details'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(partner, 'Partner institution'),
                  _field(number, 'Reference number'),
                  _field(programs, 'Programs (comma separated)'),
                  _field(contactName, 'Contact person'),
                  _field(contactEmail, 'Contact email'),
                  _field(contactPhone, 'Contact phone'),
                  _date(
                    context,
                    'Date signed',
                    startDate,
                    (value) => setDialogState(() => startDate = value),
                  ),
                  _date(
                    context,
                    'Expiration date',
                    endDate,
                    (value) => setDialogState(() => endDate = value),
                  ),
                  SizedBox(
                    width: 310,
                    child: DropdownButtonFormField<String?>(
                      initialValue: manualStatus,
                      decoration: const InputDecoration(
                        labelText: 'Manual status',
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Automatic'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'for_renewal',
                          child: Text('For renewal'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => manualStatus = value),
                    ),
                  ),
                  SizedBox(
                    width: 310,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx'],
                        );
                        if (selected != null)
                          setDialogState(() => file = selected);
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        file?.name ??
                            (existing?.fileName ?? 'Choose MOA document'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 632,
                    child: TextField(
                      controller: remarks,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (existing == null) {
                    if (file == null)
                      throw ArgumentError('Choose the MOA document.');
                    await widget.repository.addMoa(
                      actor: widget.user,
                      partnerName: partner.text,
                      moaNumber: number.text,
                      startDate: startDate,
                      endDate: endDate,
                      file: file!,
                      programs: _split(programs.text),
                      contactName: contactName.text,
                      contactEmail: contactEmail.text,
                      contactPhone: contactPhone.text,
                      remarks: remarks.text,
                    );
                  } else {
                    if (file != null) {
                      await widget.repository.renewMoa(
                        actor: widget.user,
                        record: existing,
                        endDate: endDate,
                        replacementFile: file,
                      );
                    }
                    await widget.repository.updateMoaDetails(
                      actor: widget.user,
                      record: existing,
                      partnerName: partner.text,
                      moaNumber: number.text,
                      startDate: startDate,
                      endDate: endDate,
                      programs: _split(programs.text),
                      contactName: contactName.text,
                      contactEmail: contactEmail.text,
                      contactPhone: contactPhone.text,
                      remarks: remarks.text,
                      manualStatus: manualStatus,
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (error) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                }
              },
              child: Text(existing == null ? 'Create MOA' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      partner,
      number,
      programs,
      contactName,
      contactEmail,
      contactPhone,
      remarks,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _renew(BuildContext context, MoaRecord record) async {
    var endDate = record.endDate.isAfter(DateTime.now())
        ? record.endDate.add(const Duration(days: 365))
        : DateTime.now().add(const Duration(days: 365));
    PlatformFile? file;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Renew ${record.moaNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _date(
                context,
                'New expiration',
                endDate,
                (value) => setDialogState(() => endDate = value),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await FilePicker.pickFile(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'doc', 'docx'],
                  );
                  if (selected != null) {
                    setDialogState(() => file = selected);
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: Text(file?.name ?? 'Replace file (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.renewMoa(
                  actor: widget.user,
                  record: record,
                  endDate: endDate,
                  replacementFile: file,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, MoaRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete MOA record?'),
        content: Text(
          'This permanently removes ${record.moaNumber} and its uploaded file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteMoa(actor: widget.user, record: record);
      if (mounted) {
        setState(() => _selected = null);
      }
    }
  }

  Widget _field(TextEditingController controller, String label) => SizedBox(
    width: 310,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _date(
    BuildContext context,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => SizedBox(
    width: 310,
    child: OutlinedButton.icon(
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text('$label: ${shortDate(value)}'),
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDate: value,
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    ),
  );

  List<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class _MoaStats extends StatelessWidget {
  const _MoaStats({required this.records});
  final List<MoaRecord> records;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(
        label: 'Total MOAs',
        value: '${records.length}',
        icon: Icons.handshake_outlined,
        color: const Color(0xFF1769AA),
      ),
      StatCard(
        label: 'Active MOAs',
        value: '${records.where((item) => item.status == 'Active').length}',
        icon: Icons.verified_outlined,
        color: const Color(0xFF159A61),
      ),
      StatCard(
        label: 'Nearing expiration',
        value:
            '${records.where((item) => item.status == 'Nearing expiration').length}',
        icon: Icons.warning_amber_outlined,
        color: const Color(0xFFE4931A),
      ),
      StatCard(
        label: 'Expired',
        value: '${records.where((item) => item.status == 'Expired').length}',
        icon: Icons.event_busy_outlined,
        color: const Color(0xFFD14343),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 42) / 4
            : constraints.maxWidth >= 560
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _MoaList extends StatelessWidget {
  const _MoaList({
    required this.records,
    required this.selected,
    required this.onSelect,
  });
  final List<MoaRecord> records;
  final MoaRecord? selected;
  final ValueChanged<MoaRecord> onSelect;

  @override
  Widget build(BuildContext context) => Card(
    child: records.isEmpty
        ? const EmptyWorkflowState(
            icon: Icons.handshake_outlined,
            title: 'No MOAs found',
            message: 'Create the first partner agreement.',
          )
        : ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                selected: selected?.id == record.id,
                selectedTileColor: const Color(0xFFEAF4FF),
                leading: const Icon(Icons.business_outlined),
                title: Text(
                  record.partnerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${record.moaNumber} • ${record.programs.isEmpty ? 'All programs' : record.programs.join(', ')}\nSigned ${shortDate(record.startDate)} • Expires ${shortDate(record.endDate)}',
                ),
                isThreeLine: true,
                trailing: StatusBadge(record.status),
                onTap: () => onSelect(record),
              );
            },
          ),
  );
}

class _MoaDetails extends StatelessWidget {
  const _MoaDetails({
    required this.record,
    required this.repository,
    required this.onEdit,
    required this.onRenew,
    required this.onDelete,
  });
  final MoaRecord record;
  final PracticumRepository repository;
  final VoidCallback onEdit;
  final VoidCallback onRenew;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: record.partnerName,
    trailing: StatusBadge(record.status),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Reference', record.moaNumber),
        _row(
          'Programs',
          record.programs.isEmpty ? 'All programs' : record.programs.join(', '),
        ),
        _row('Date signed', shortDate(record.startDate)),
        _row('Expiration', shortDate(record.endDate)),
        _row(
          'Remaining',
          record.isExpired ? 'Expired' : '${record.daysUntilExpiry} days',
        ),
        const Divider(height: 28),
        const Text(
          'Point of Contact',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        _row('Name', record.contactName ?? '—'),
        _row('Email', record.contactEmail ?? '—'),
        _row('Phone', record.contactPhone ?? '—'),
        if (record.remarks?.isNotEmpty == true) ...[
          const Divider(height: 28),
          const Text('Remarks', style: TextStyle(fontWeight: FontWeight.w800)),
          Text(record.remarks!),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              openStorageDocument(context, repository, record.storagePath),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('View MOA document'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit details'),
            ),
            OutlinedButton.icon(
              onPressed: onRenew,
              icon: const Icon(Icons.event_repeat_outlined),
              label: const Text('Renew'),
            ),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
