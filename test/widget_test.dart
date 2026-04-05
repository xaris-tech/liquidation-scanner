import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquidation_scanner/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LiquidationScannerApp()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets);
  });
}
