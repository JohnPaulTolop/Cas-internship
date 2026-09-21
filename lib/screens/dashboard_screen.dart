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
        final desktop = constraints.maxWidth >= 1040;
        final navigation = _SideNavigation(
          features: features,
          selected: _selected,
          user: user,
          onSelected: (feature) {
            setState(() => _selected = feature);
            if (!desktop) Navigator.pop(context);
          },
          onLogout: widget.controller.signOut,
        );

        final content = Scaffold(
          backgroundColor: AppTheme.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(66),
            child: _TopBar(
              user: user,
              desktop: desktop,
              onNotifications: RoleAccess.canAccess(
                user.role,
                AppFeature.notifications,
              )
                  ? () => setState(() => _selected = AppFeature.notifications)
                  : null,
              onLogout: widget.controller.signOut,
            ),
          ),
          drawer: desktop
              ? null
              : Drawer(
                  width: 280,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: const RoundedRectangleBorder(),
                  child: navigation,
                ),
          body: LayoutBuilder(
            builder: (context, bodyConstraints) {
              final roomy = bodyConstraints.maxWidth >= 900;
              final horizontalPadding = roomy ? 24.0 : 14.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  roomy ? 22 : 14,
                  horizontalPadding,
                  roomy ? 24 : 14,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppTheme.contentMaxWidth,
                    ),
                    child: SizedBox.expand(
                      child: ModuleRouter(
                        feature: _selected,
                        user: user,
                        repository: widget.controller.repository,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );

        if (!desktop) return content;
        return ColoredBox(
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 228, child: navigation),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.desktop,
    required this.onNotifications,
    required this.onLogout,
  });

  final AppUser user;
  final bool desktop;
  final VoidCallback? onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      bottom: false,
      child: Container(
        height: 66,
        padding: EdgeInsets.symmetric(horizontal: desktop ? 24 : 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            if (!desktop)
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Open navigation',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            if (!desktop) ...[
              const SizedBox(width: 4),
              const _CompactBrand(),
            ],
            if (desktop) const Spacer(),
            if (desktop)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SizedBox(
                  width: 340,
                  height: 42,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      hintText: 'Search students, documents, institutions',
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(7),
                        alignment: Alignment.center,
                        width: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Text(
                          '⌘K',
                          style: TextStyle(fontSize: 9.5, color: AppTheme.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Account menu',
              onSelected: (value) {
                if (value == 'logout') onLogout();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
              child: Container(
                constraints: BoxConstraints(maxWidth: desktop ? 210 : 48),
                padding: EdgeInsets.fromLTRB(
                  desktop ? 7 : 5,
                  5,
                  desktop ? 10 : 5,
                  5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.sky,
                      foregroundColor: AppTheme.deepBlue,
                      child: Text(
                        _initials(user.displayName),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (desktop) ...[
                      const SizedBox(width: 9),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            Text(
                              user.role.longLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.blue,
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.hub_outlined, color: Colors.white, size: 17),
        ),
      ),
      SizedBox(width: 8),
      Text(
        'Practicum Connect',
        style: TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.features,
    required this.selected,
    required this.user,
    required this.onSelected,
    required this.onLogout,
  });

  final List<AppFeature> features;
  final AppFeature selected;
  final AppUser user;
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
            padding: EdgeInsets.fromLTRB(18, 20, 14, 18),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.blue,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.hub_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practicum Connect',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'CAS Internship Management',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: AppTheme.subtle,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(9, 2, 9, 10),
              children: features.map((feature) {
                final active = selected == feature;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => onSelected(feature),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.surfaceBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: active
                            ? Border.all(color: const Color(0xFFDCE9FF))
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 31,
                            height: 31,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppTheme.sky
                                  : AppTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              feature.icon,
                              size: 17,
                              color: active ? AppTheme.blue : AppTheme.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature.labelForRole(user.role),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? AppTheme.deepBlue : AppTheme.text,
                                fontSize: 11.6,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (active)
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppTheme.blue,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Practicum Connect',
                    applicationVersion: '0.1.0',
                    applicationLegalese: 'CAS Internship Management System',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.help_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Help & Support', style: TextStyle(fontSize: 11.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
    .join();
