import 'package:flutter_test/flutter_test.dart';
import 'package:practicum_connect/models/app_feature.dart';
import 'package:practicum_connect/models/app_user.dart';

void main() {
  test('admin can access every feature', () {
    expect(RoleAccess.forRole(UserRole.admin), AppFeature.values.toSet());
  });

  test('coordinator receives the agreed operational modules', () {
    final access = RoleAccess.forRole(UserRole.coordinator);
    expect(
      access,
      containsAll([
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
      ]),
    );
    expect(access, isNot(contains(AppFeature.users)));
  });

  test(
    'student access includes tracking, submissions, repository, and notices',
    () {
      expect(RoleAccess.forRole(UserRole.student), {
        AppFeature.dashboard,
        AppFeature.statusTracker,
        AppFeature.requirements,
        AppFeature.repository,
        AppFeature.notifications,
      });
    },
  );
}
