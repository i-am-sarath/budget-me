import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BudgetTrackerApp()),
    );
    // App starts, just verify it doesn't crash
    expect(find.byType(ProviderScope), findsWidgets);
  });
}
