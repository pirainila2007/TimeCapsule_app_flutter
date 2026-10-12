
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_capsule/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TimeCapsule app starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TimeCapsuleApp());

    // Allow the initial local-storage load to finish.
    await tester.pumpAndSettle();

    expect(find.text('TimeCapsule'), findsOneWidget);
    expect(find.text('Your collection'), findsOneWidget);
  });
}