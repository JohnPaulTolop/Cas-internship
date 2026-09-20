import 'package:flutter/material.dart';

import 'app_user.dart';

enum AppFeature {
  dashboard('Dashboard', Icons.dashboard_outlined),
  statusTracker('Status Tracker', Icons.track_changes_outlined),
  students('Internship Records', Icons.groups_outlined),
  requirements('Requirements', Icons.fact_check_outlined),
  repository('Document Repository', Icons.folder_copy_outlined),
  documentReview('Document Review', Icons.rate_review_outlined),
  dtr('Daily Time Record', Icons.punch_clock_outlined),
  tor('TOR', Icons.school_outlined),
  hours('Rendered Hours', Icons.timelapse_outlined),
  moa('MOA Management', Icons.handshake_outlined),
  notifications('Messages & Notifications', Icons.notifications_outlined),
  reports('Reports', Icons.analytics_outlined),
  users('User Management', Icons.manage_accounts_outlined),
  audit('Audit Logs', Icons.history_outlined);

  const AppFeature(this.label, this.icon);
  final String label;
  final IconData icon;
}

class RoleAccess {
  static const coordinatorFeatures = <AppFeature>{
    AppFeature.dashboard,
    AppFeature.dtr,
    AppFeature.tor,
    AppFeature.hours,
    AppFeature.moa,
    AppFeature.students,
    AppFeature.requirements,
    AppFeature.documentReview,
    AppFeature.repository,
    AppFeature.notifications,
    AppFeature.reports,
  };

  static const studentFeatures = <AppFeature>{
    AppFeature.dashboard,
    AppFeature.statusTracker,
    AppFeature.requirements,
    AppFeature.repository,
    AppFeature.notifications,
  };

  static Set<AppFeature> forRole(UserRole role) => switch (role) {
    UserRole.admin => AppFeature.values.toSet(),
    UserRole.coordinator => coordinatorFeatures,
    UserRole.student => studentFeatures,
  };

  static bool canAccess(UserRole role, AppFeature feature) =>
      forRole(role).contains(feature);
}
