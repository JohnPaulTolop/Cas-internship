import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_feature.dart';
import '../models/app_user.dart';
import '../services/app_controller.dart';
import 'module_screens.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppFeature _selected = AppFeature.dashboard;

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final features = RoleAccess.forRole(user.role).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final navigation = _SideNavigation(
          features: features,
          selected: _selected,
          userName: user.displayName,
          role: user.role.label,
          onSelected: (feature) {
            setState(() => _selected = feature);
            if (!desktop) Navigator.pop(context);
          },
          onLogout: widget.controller.signOut,
        );

        final scaffold = Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !desktop,
            title: Text(_selected.label),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  backgroundColor: AppTheme.blue,
                  foregroundColor: Colors.white,
                  child: Text(_initials(user.displayName)),
                ),
              ),
            ],
          ),
          drawer: desktop ? null : Drawer(child: navigation),
          body: Padding(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: ModuleRouter(
              feature: _selected,
              user: user,
              repository: widget.controller.repository,
            ),
          ),
        );

        return desktop
            ? Row(
                children: [
                  SizedBox(width: 245, child: navigation),
                  Expanded(child: scaffold),
                ],
              )
            : scaffold;
      },
    );
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
      .join();
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.features,
    required this.selected,
    required this.userName,
    required this.role,
    required this.onSelected,
    required this.onLogout,
  });

  final List<AppFeature> features;
  final AppFeature selected;
  final String userName;
  final String role;
  final ValueChanged<AppFeature> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.blue,
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.hub_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Practicum\nConnect',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE4EAF1), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: features
                  .map(
                    (feature) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: ListTile(
                        selected: selected == feature,
                        selectedTileColor: AppTheme.blue.withValues(alpha: .11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(feature.icon),
                        title: Text(feature.label),
                        textColor: const Color(0xFF536170),
                        iconColor: const Color(0xFF718096),
                        selectedColor: AppTheme.deepBlue,
                        onTap: () => onSelected(feature),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(color: Color(0xFFE4EAF1), height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1E7EF)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.blue,
                  foregroundColor: Colors.white,
                  child: Text(_initials(userName)),
                ),
                title: Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Sign out',
                  onPressed: onLogout,
                  color: AppTheme.navy,
                  icon: const Icon(Icons.logout, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
      .join();
}
