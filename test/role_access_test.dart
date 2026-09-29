import 'package:flutter_test/flutter_test.dart';
import 'package:practicum_connect/models/app_feature.dart';
import 'package:practicum_connect/models/app_user.dart';

void main() {
  test('admin retains the existing administrative modules', () {
    expect(RoleAccess.forRole(UserRole.admin), {
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
    });
  });

  test('coordinator retains the existing operational modules', () {
    expect(RoleAccess.forRole(UserRole.coordinator), {
      AppFeature.dashboard,
      AppFeature.students,
      AppFeature.documentReview,
      AppFeature.dtr,
      AppFeature.evaluations,
      AppFeature.notifications,
      AppFeature.archivedRecords,
      AppFeature.settings,
    });
  });

  test(
    'student uses Requirements Checklist without a duplicate repository tab',
    () {
      expect(RoleAccess.forRole(UserRole.student), {
        AppFeature.dashboard,
        AppFeature.statusTracker,
        AppFeature.requirements,
        AppFeature.dtr,
        AppFeature.notifications,
        AppFeature.settings,
      });

      expect(
        RoleAccess.canAccess(UserRole.student, AppFeature.repository),
        isFalse,
      );

      expect(
        RoleAccess.canAccess(UserRole.student, AppFeature.requirements),
        isTrue,
      );
    },
  );
}
