import 'package:flutter/material.dart';

import 'app_user.dart';

enum AppFeature {
  dashboard('Dashboard', Icons.dashboard_outlined),
  statusTracker('Status Tracker', Icons.track_changes_outlined),
  students('Internship Records', Icons.groups_outlined),
  requirements('Requirements', Icons.fact_check_outlined),
  repository('Document Repository', Icons.folder_copy_outlined),
  documentReview('Document Review', Icons.rate_review_outlined),
  dtr('DTR & Hours', Icons.punch_clock_outlined),
  evaluations('Evaluations', Icons.assignment_turned_in_outlined),
  moa('Partner Institutions & MOA', Icons.handshake_outlined),
  notifications('Notifications', Icons.notifications_outlined),
  reports('Reports & Analytics', Icons.analytics_outlined),
  archivedRecords('Archived Records', Icons.inventory_2_outlined),
  users('User Management', Icons.manage_accounts_outlined),
  audit('Audit Logs', Icons.history_outlined),
  settings('Settings', Icons.settings_outlined),

  // Legacy route identifiers retained for backward compatibility with older
  // saved builds. They are intentionally not included in any current role menu.
  tor('TOR', Icons.school_outlined),
  hours('Rendered Hours', Icons.timelapse_outlined);

  const AppFeature(this.label, this.icon);
  final String label;
  final IconData icon;

  String labelForRole(UserRole role) {
    if (role == UserRole.student) {
      return switch (this) {
        AppFeature.dashboard => 'Dashboard',
        AppFeature.statusTracker => 'My Internship',
        AppFeature.requirements => 'Requirements Checklist',
        AppFeature.repository => 'Document Submission',
        AppFeature.dtr => 'DTR & Hours',
        AppFeature.notifications => 'Notifications',
        AppFeature.archivedRecords => 'Archived Records',
        AppFeature.settings => 'Settings',
        _ => label,
      };
    }
    if (role == UserRole.coordinator) {
      return switch (this) {
        AppFeature.dashboard => 'Coordinator Dashboard',
        AppFeature.students => 'Assigned Interns',
        AppFeature.documentReview => 'Document Review',
        AppFeature.dtr => 'DTR & Hours',
        AppFeature.evaluations => 'Supervisor Evaluations',
        AppFeature.notifications => 'Notifications',
        AppFeature.archivedRecords => 'Archived Records',
        AppFeature.settings => 'Settings',
        _ => label,
      };
    }
    return switch (this) {
      AppFeature.dashboard => 'CAS Dashboard',
      AppFeature.students => 'Internship Records',
      AppFeature.requirements => 'Requirement Setup',
      AppFeature.repository => 'Document Repository',
      AppFeature.documentReview => 'Document Review',
      AppFeature.dtr => 'DTR & Hours',
      AppFeature.evaluations => 'Evaluations',
      AppFeature.moa => 'Partner Institutions & MOA',
      AppFeature.notifications => 'Notification Management',
      AppFeature.reports => 'Reports & Analytics',
      AppFeature.archivedRecords => 'Archived Records',
      AppFeature.users => 'Users & Access',
      AppFeature.audit => 'Audit Logs',
      AppFeature.settings => 'Settings',
      _ => label,
    };
  }
}

class RoleAccess {
  /// Program Coordinators work only with interns assigned to them. College-wide
  /// configuration, MOA administration, users, and analytics remain CAS College
  /// Coordinator / SIP Admin responsibilities. Archived retrieval is scoped to
  /// the Program Coordinator's assigned interns.
  static const coordinatorFeatures = <AppFeature>{
    AppFeature.dashboard,
    AppFeature.students,
    AppFeature.documentReview,
    AppFeature.dtr,
    AppFeature.evaluations,
    AppFeature.notifications,
    AppFeature.archivedRecords,
    AppFeature.settings,
  };

  static const studentFeatures = <AppFeature>{
    AppFeature.dashboard,
    AppFeature.statusTracker,
    AppFeature.requirements,
    AppFeature.repository,
    AppFeature.dtr,
    AppFeature.notifications,
    AppFeature.settings,
  };

  static const adminFeatures = <AppFeature>{
    AppFeature.dashboard,
    AppFeature.students,
    AppFeature.requirements,
    AppFeature.repository,
    AppFeature.documentReview,
    AppFeature.dtr,
    AppFeature.evaluations,
    AppFeature.moa,
    AppFeature.notifications,
    AppFeature.reports,
    AppFeature.archivedRecords,
    AppFeature.users,
    AppFeature.audit,
    AppFeature.settings,
  };

  static Set<AppFeature> forRole(UserRole role) => switch (role) {
    UserRole.admin => adminFeatures,
    UserRole.coordinator => coordinatorFeatures,
    UserRole.student => studentFeatures,
  };

  static bool canAccess(UserRole role, AppFeature feature) =>
      forRole(role).contains(feature);
}
