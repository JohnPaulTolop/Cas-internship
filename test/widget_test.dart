import 'package:flutter_test/flutter_test.dart';
import 'package:practicum_connect/main.dart';
import 'package:practicum_connect/services/app_controller.dart';

void main() {
  testWidgets('shows the Practicum Connect login screen', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.busy = false;

    await tester.pumpWidget(PracticumConnectApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Practicum Connect'), findsOneWidget);
  });
}
