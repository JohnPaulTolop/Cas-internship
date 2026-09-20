import 'package:flutter_test/flutter_test.dart';
import 'package:practicum_connect/models/records.dart';

void main() {
  test('rendered hours subtract break time', () {
    final record = DtrRecord(
      id: '1',
      studentId: 'student',
      studentName: 'Student',
      date: DateTime(2026, 9, 20),
      timeIn: DateTime(2026, 9, 20, 8),
      timeOut: DateTime(2026, 9, 20, 17),
      breakMinutes: 60,
      status: ReviewStatus.pending,
    );

    expect(record.renderedHours, 8);
  });
}
