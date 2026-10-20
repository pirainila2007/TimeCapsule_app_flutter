import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_capsule/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TimeCapsule shows splash then home', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TimeCapsuleApp());

    expect(find.text('TimeCapsule'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Your collection'), findsOneWidget);
  });
}