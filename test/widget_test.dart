import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteri_app/main.dart';

void main() {
  testWidgets('QordyMusteriApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QordyMusteriApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(QordyMusteriApp), findsOneWidget);

    // Unmount ProviderScope so periodic sync timers dispose cleanly
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

