import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
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
  String _program = 'All Programs';
  String _expiryFilter = 'Any Date';
  MoaRecord? _selected;
  int _tab = 0;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'MOA Management',
    subtitle:
        'Manage, monitor, and track Memorandum of Agreements with partner institutions.',
    actions: [
      OutlinedButton.icon(
        onPressed: () => _showPartnerManager(context),
        icon: const Icon(Icons.apartment_outlined, size: 15),
        label: const Text('Partner Institutions'),
      ),
      FilledButton.icon(
        onPressed: () => _showMoaDialog(context),
        icon: const Icon(Icons.add, size: 15),
        label: const Text('New MOA'),
      ),
    ],
    child: StreamBuilder<List<MoaRecord>>(
      stream: widget.repository.watchMoas(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <MoaRecord>[];
        final tabStatus = switch (_tab) {
          1 => 'Active',
          2 => 'Nearing expiration',
          3 => 'Expired',
          4 => 'For renewal',
          _ => null,
        };
        final programs = <String>{
          'All Programs',
          ...all.expand((record) => record.programs),
        }.where((value) => value.trim().isNotEmpty).toList()..sort();
        final effectiveProgram = programs.contains(_program)
            ? _program
            : 'All Programs';
        final records = all.where((record) {
          final matchesQuery =
              _query.isEmpty ||
              '${record.partnerName} ${record.moaNumber} ${record.programs.join(' ')} '
                      '${record.contactName ?? ''} ${record.contactEmail ?? ''}'
                  .toLowerCase()
                  .contains(_query);
          final matchesStatus =
              (_status == 'All MOAs' || record.status == _status) &&
              (tabStatus == null || record.status == tabStatus);
          final matchesProgram =
              effectiveProgram == 'All Programs' ||
              record.programs.isEmpty ||
              record.programs.contains(effectiveProgram);
          final matchesExpiry = switch (_expiryFilter) {
            'Expired' => record.isExpired,
            'Within 30 days' =>
              !record.isExpired && record.daysUntilExpiry <= 30,
            'Within 90 days' =>
              !record.isExpired && record.daysUntilExpiry <= 90,
            'Beyond 90 days' =>
              !record.isExpired && record.daysUntilExpiry > 90,
            _ => true,
          };
          return matchesQuery &&
              matchesStatus &&
              matchesProgram &&
              matchesExpiry;
        }).toList();
        final selected =
            _selected != null &&
                records.any((record) => record.id == _selected!.id)
            ? records.firstWhere((record) => record.id == _selected!.id)
            : records.firstOrNull;
        final counts = [
          all.length,
          all.where((item) => item.status == 'Active').length,
          all.where((item) => item.status == 'Nearing expiration').length,
          all.where((item) => item.status == 'Expired').length,
          all.where((item) => item.status == 'For renewal').length,
        ];
        return Column(
          children: [
            _MoaStats(records: all),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: WorkspaceTabs(
                labels: const [
                  'All MOAs',
                  'Active',
                  'Nearing Expiration',
                  'Expired',
                  'For Renewal',
                ],
                counts: counts,
                selectedIndex: _tab,
                onSelected: (value) => setState(() => _tab = value),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText:
                              'Search institution, reference no., or contact person…',
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.toLowerCase()),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: effectiveProgram,
                        decoration: const InputDecoration(labelText: 'Program'),
                        items: programs
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _program = value ?? 'All Programs'),
                      ),
                    ),
                    SizedBox(
                      width: 165,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
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
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _expiryFilter,
                        decoration: const InputDecoration(
                          labelText: 'Expiration',
                        ),
                        items:
                            const [
                                  'Any Date',
                                  'Within 30 days',
                                  'Within 90 days',
                                  'Beyond 90 days',
                                  'Expired',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _expiryFilter = value ?? 'Any Date'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _query = '';
                        _status = 'All MOAs';
                        _program = 'All Programs';
                        _expiryFilter = 'Any Date';
                        _tab = 0;
                      }),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Reset Filters'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = _MoaList(
                    records: records,
                    selected: selected,
                    onSelect: (record) => setState(() => _selected = record),
                    onEdit: (record) =>
                        _showMoaDialog(context, existing: record),
                    onRenew: (record) => _renew(context, record),
                    onDelete: (record) => _delete(context, record),
                    repository: widget.repository,
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
                  if (constraints.maxWidth < 980) {
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 9),
                        SizedBox(
                          height: 450,
                          child: SingleChildScrollView(child: detail),
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: list),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 320,
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

  Future<void> _showPartnerManager(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Partner Institutions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Maintain company/agency information independently from MOA records.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showPartnerDialog(dialogContext),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New Partner'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<PartnerInstitutionRecord>>(
                    stream: widget.repository.watchPartnerInstitutions(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Unable to load partners: ${snapshot.error}',
                          ),
                        );
                      }
                      final records =
                          snapshot.data ?? const <PartnerInstitutionRecord>[];
                      if (records.isEmpty) {
                        return const EmptyWorkflowState(
                          icon: Icons.apartment_outlined,
                          title: 'No partner institutions yet',
                          message:
                              'Register a company or agency before linking it to an MOA.',
                        );
                      }
                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            leading: const CircleAvatar(
                              child: Icon(Icons.business_outlined, size: 18),
                            ),
                            title: Text(record.name),
                            subtitle: Text(
                              [
                                if (record.industryField.isNotEmpty)
                                  record.industryField,
                                if (record.contactName.isNotEmpty)
                                  record.contactName,
                                if (record.contactEmail.isNotEmpty)
                                  record.contactEmail,
                              ].join(' • '),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                StatusBadge(record.status, compact: true),
                                IconButton(
                                  tooltip: 'Edit partner',
                                  onPressed: () => _showPartnerDialog(
                                    dialogContext,
                                    existing: record,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete partner',
                                  onPressed: () =>
                                      _deletePartner(dialogContext, record),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPartnerDialog(
    BuildContext context, {
    PartnerInstitutionRecord? existing,
  }) async {
    final name = TextEditingController(text: existing?.name);
    final address = TextEditingController(text: existing?.address);
    final type = TextEditingController(text: existing?.institutionType);
    final industry = TextEditingController(text: existing?.industryField);
    final contactName = TextEditingController(text: existing?.contactName);
    final contactEmail = TextEditingController(text: existing?.contactEmail);
    final contactPhone = TextEditingController(text: existing?.contactPhone);
    final programs = TextEditingController(text: existing?.programs.join(', '));
    final remarks = TextEditingController(text: existing?.remarks);
    var status = existing?.status ?? 'Active';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Register Partner Institution'
                : 'Edit Partner Institution',
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(name, 'Institution / company name'),
                  _field(type, 'Institution type'),
                  _field(industry, 'Industry / field'),
                  _field(programs, 'Programs covered (comma separated)'),
                  _field(contactName, 'Contact person'),
                  _field(contactEmail, 'Contact email'),
                  _field(contactPhone, 'Contact phone'),
                  SizedBox(
                    width: 310,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Partner status',
                      ),
                      items: const ['Active', 'Inactive']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? 'Active'),
                    ),
                  ),
                  SizedBox(
                    width: 632,
                    child: TextField(
                      controller: address,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Address'),
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
                  await widget.repository.savePartnerInstitution(
                    actor: widget.user,
                    id: existing?.id,
                    name: name.text,
                    address: address.text,
                    institutionType: type.text,
                    industryField: industry.text,
                    contactName: contactName.text,
                    contactEmail: contactEmail.text,
                    contactPhone: contactPhone.text,
                    programs: _split(programs.text),
                    status: status,
                    remarks: remarks.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: Text(
                existing == null ? 'Register Partner' : 'Save Changes',
              ),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      name,
      address,
      type,
      industry,
      contactName,
      contactEmail,
      contactPhone,
      programs,
      remarks,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _deletePartner(
    BuildContext context,
    PartnerInstitutionRecord partner,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete partner institution?'),
        content: Text(
          'Delete ${partner.name}? Partners linked to an MOA cannot be deleted.',
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
    if (confirmed != true) return;
    try {
      await widget.repository.deletePartnerInstitution(
        actor: widget.user,
        partner: partner,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showMoaDialog(
    BuildContext context, {
    MoaRecord? existing,
  }) async {
    final registeredPartners = await widget.repository
        .watchPartnerInstitutions()
        .first;
    if (!context.mounted) return;
    String? selectedPartnerId = existing?.partnerId;
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
                  SizedBox(
                    width: 310,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: selectedPartnerId,
                      decoration: const InputDecoration(
                        labelText: 'Registered partner (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Manual / not yet registered'),
                        ),
                        ...registeredPartners.map(
                          (record) => DropdownMenuItem<String?>(
                            value: record.id,
                            child: Text(
                              record.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPartnerId = value;
                          final selected = registeredPartners
                              .where((record) => record.id == value)
                              .firstOrNull;
                          if (selected != null) {
                            partner.text = selected.name;
                            programs.text = selected.programs.join(', ');
                            contactName.text = selected.contactName;
                            contactEmail.text = selected.contactEmail;
                            contactPhone.text = selected.contactPhone;
                          }
                        });
                      },
                    ),
                  ),
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
                      isExpanded: true,
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
                        if (selected != null) {
                          setDialogState(() => file = selected);
                        }
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
                    if (file == null) {
                      throw ArgumentError('Choose the MOA document.');
                    }
                    await widget.repository.addMoa(
                      actor: widget.user,
                      partnerName: partner.text,
                      partnerId: selectedPartnerId,
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
                      partnerId: selectedPartnerId,
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
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
    // Keep the current expiration date by default. This allows the same dialog
    // to replace only the file without forcing an extra one-year renewal.
    var endDate = record.endDate;
    PlatformFile? file;
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Replace file / renew ${record.moaNumber}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _date(
                  context,
                  'Expiration date',
                  endDate,
                  (value) => setDialogState(() => endDate = value),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final selected = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'doc', 'docx'],
                          );
                          if (selected != null) {
                            setDialogState(() => file = selected);
                          }
                        },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    file?.name ??
                        (record.fileName == null
                            ? 'Choose replacement file (optional)'
                            : 'Current: ${record.fileName}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a file to replace the stored MOA. Leave it unchanged if you only want to update the expiration date.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await widget.repository.renewMoa(
                          actor: widget.user,
                          record: record,
                          endDate: endDate,
                          replacementFile: file,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                file == null
                                    ? 'MOA expiration date updated.'
                                    : 'MOA file replaced successfully.',
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Unable to update MOA: $error'),
                              duration: const Duration(seconds: 6),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
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
        color: AppTheme.blue,
      ),
      StatCard(
        label: 'Active MOAs',
        value: '${records.where((item) => item.status == 'Active').length}',
        icon: Icons.verified_outlined,
        color: AppTheme.success,
      ),
      StatCard(
        label: 'Nearing Expiration',
        value:
            '${records.where((item) => item.status == 'Nearing expiration').length}',
        caption: 'within 3 months',
        icon: Icons.warning_amber_outlined,
        color: AppTheme.warning,
      ),
      StatCard(
        label: 'Expired',
        value: '${records.where((item) => item.status == 'Expired').length}',
        icon: Icons.event_busy_outlined,
        color: AppTheme.danger,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 30) / 4
            : constraints.maxWidth >= 560
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
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
    required this.onEdit,
    required this.onRenew,
    required this.onDelete,
    required this.repository,
  });

  final List<MoaRecord> records;
  final MoaRecord? selected;
  final ValueChanged<MoaRecord> onSelect;
  final ValueChanged<MoaRecord> onEdit;
  final ValueChanged<MoaRecord> onRenew;
  final ValueChanged<MoaRecord> onDelete;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Card(
    child: records.isEmpty
        ? const EmptyWorkflowState(
            icon: Icons.handshake_outlined,
            title: 'No MOAs found',
            message: 'Create the first partner agreement.',
          )
        : Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: AppTheme.surfaceSoft,
                child: const Row(
                  children: [
                    SizedBox(width: 28),
                    Expanded(flex: 3, child: Text('Institution', style: _head)),
                    Expanded(
                      flex: 2,
                      child: Text('Reference No.', style: _head),
                    ),
                    Expanded(flex: 2, child: Text('Program/s', style: _head)),
                    Expanded(flex: 2, child: Text('Date Signed', style: _head)),
                    Expanded(
                      flex: 2,
                      child: Text('Expiration Date', style: _head),
                    ),
                    Expanded(flex: 2, child: Text('Status', style: _head)),
                    SizedBox(width: 34),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final active = selected?.id == record.id;
                    return InkWell(
                      onTap: () => onSelect(record),
                      child: Container(
                        color: active ? AppTheme.surfaceBlue : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Icon(
                                active
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 14,
                                color: active ? AppTheme.blue : AppTheme.muted,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                record.partnerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(flex: 2, child: _cell(record.moaNumber)),
                            Expanded(
                              flex: 2,
                              child: _cell(
                                record.programs.isEmpty
                                    ? 'All'
                                    : record.programs.join(', '),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _cell(shortDate(record.startDate)),
                            ),
                            Expanded(
                              flex: 2,
                              child: _cell(shortDate(record.endDate)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(
                                  record.status,
                                  compact: true,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 34,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_horiz, size: 16),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      onEdit(record);
                                      break;
                                    case 'view':
                                      openStorageDocument(
                                        context,
                                        repository,
                                        record.storagePath,
                                      );
                                      break;
                                    case 'renew':
                                      onRenew(record);
                                      break;
                                    case 'delete':
                                      onDelete(record);
                                      break;
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit MOA'),
                                  ),
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Text('View Documents'),
                                  ),
                                  PopupMenuItem(
                                    value: 'renew',
                                    child: Text('Update / Renew'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${records.length} of ${records.length} selected',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.muted,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '10 / page',
                      style: TextStyle(fontSize: 9, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );

  static const TextStyle _head = TextStyle(
    fontSize: 8.6,
    color: AppTheme.muted,
    fontWeight: FontWeight.w700,
  );

  Widget _cell(String value) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 9.1),
  );
}

class _MoaDetails extends StatefulWidget {
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
  State<_MoaDetails> createState() => _MoaDetailsState();
}

class _MoaDetailsState extends State<_MoaDetails> {
  int _tab = 0;

  @override
  void didUpdateWidget(covariant _MoaDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _tab = 0;
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: widget.record.partnerName,
    trailing: StatusBadge(widget.record.status, compact: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.record.moaNumber,
          style: const TextStyle(fontSize: 9, color: AppTheme.muted),
        ),
        const SizedBox(height: 7),
        WorkspaceTabs(
          labels: const ['Overview', 'Documents', 'History', 'Notes'],
          selectedIndex: _tab,
          onSelected: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey('${widget.record.id}-$_tab'),
            child: _tabContent(context),
          ),
        ),
        const SizedBox(height: 14),
        if (_tab == 0) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Details'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.sync_alt_outlined, size: 14),
                  label: const Text('Update Status'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
        ],
        OutlinedButton.icon(
          onPressed: widget.onRenew,
          icon: const Icon(Icons.upload_file_outlined, size: 14),
          label: const Text('Replace File / Renew'),
        ),
        const SizedBox(height: 7),
        TextButton.icon(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.delete_outline, size: 14),
          label: const Text('Delete MOA'),
        ),
      ],
    ),
  );

  Widget _tabContent(BuildContext context) => switch (_tab) {
    1 => _documents(context),
    2 => _history(),
    3 => _notes(),
    _ => _overview(),
  };

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InfoRow('Institution Name', widget.record.partnerName, labelWidth: 98),
      InfoRow('Reference No.', widget.record.moaNumber, labelWidth: 98),
      InfoRow(
        'Program/s Covered',
        widget.record.programs.isEmpty
            ? 'All programs'
            : widget.record.programs.join(', '),
        labelWidth: 98,
      ),
      InfoRow(
        'Date Signed',
        shortDate(widget.record.startDate),
        labelWidth: 98,
      ),
      InfoRow(
        'Expiration Date',
        shortDate(widget.record.endDate),
        labelWidth: 98,
      ),
      InfoRow(
        'Remaining',
        widget.record.isExpired
            ? 'Expired'
            : '${widget.record.daysUntilExpiry} days',
        labelWidth: 98,
      ),
      const Divider(height: 22),
      const Text(
        'Status',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: widget.onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(child: StatusBadge(widget.record.status, compact: true)),
              const Icon(Icons.keyboard_arrow_down, size: 17),
            ],
          ),
        ),
      ),
      const Divider(height: 22),
      const Text(
        'Point of Contact',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      InfoRow('Name', widget.record.contactName ?? '—', labelWidth: 74),
      InfoRow('Email', widget.record.contactEmail ?? '—', labelWidth: 74),
      InfoRow('Phone', widget.record.contactPhone ?? '—', labelWidth: 74),
    ],
  );

  Widget _documents(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceSoft,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'MOA Document',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 18,
              color: AppTheme.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.record.fileName ?? 'No file attached',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: widget.record.storagePath?.isNotEmpty == true
              ? () => openStorageDocument(
                  context,
                  widget.repository,
                  widget.record.storagePath,
                )
              : null,
          icon: const Icon(Icons.visibility_outlined, size: 15),
          label: const Text('View MOA Document'),
        ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          onPressed: widget.onRenew,
          icon: const Icon(Icons.upload_file_outlined, size: 14),
          label: const Text('Replace attached file'),
        ),
      ],
    ),
  );

  Widget _history() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceSoft,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Record History',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _historyLine(
          Icons.add_circle_outline,
          'Record created',
          widget.record.createdAt,
        ),
        _historyLine(
          Icons.event_available_outlined,
          'Agreement signed',
          widget.record.startDate,
        ),
        _historyLine(
          Icons.event_busy_outlined,
          'Current expiration',
          widget.record.endDate,
        ),
      ],
    ),
  );

  Widget _historyLine(IconData icon, String label, DateTime? date) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 9.5))),
        Text(
          shortDate(date),
          style: const TextStyle(fontSize: 8.8, color: AppTheme.muted),
        ),
      ],
    ),
  );

  Widget _notes() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceSoft,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      widget.record.remarks?.trim().isNotEmpty == true
          ? widget.record.remarks!
          : 'No notes have been added for this MOA.',
      style: const TextStyle(
        fontSize: 9.7,
        color: AppTheme.muted,
        height: 1.45,
      ),
    ),
  );
}
