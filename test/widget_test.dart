import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BudgetTrackerApp()),
    );
    // Let timers settle (there's an onboard splash timer)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // App starts, just verify it doesn't crash
    expect(find.byType(ProviderScope), findsWidgets);
  });
}
