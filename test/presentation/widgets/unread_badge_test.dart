import 'package:cerqle_chat/src/presentation/widgets/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single and two-digit count badges are circular', (tester) async {
    for (final count in <int>[1, 10]) {
      const indicatorKey = ValueKey<String>('indicator');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: CerqleUnreadBadgeView(
              unreadCount: count,
              showCount: true,
              largeSize: 14,
              indicatorKey: indicatorKey,
              child: const Icon(Icons.chat),
            ),
          ),
        ),
      );

      final indicator = find.byKey(indicatorKey);
      expect(tester.getSize(indicator), const Size.square(14));
      expect(
        (tester.widget<Container>(indicator).decoration! as ShapeDecoration)
            .shape,
        isA<CircleBorder>(),
      );
    }
  });

  testWidgets('overflow count badge expands as a pill', (tester) async {
    const indicatorKey = ValueKey<String>('indicator');
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CerqleUnreadBadgeView(
            unreadCount: 100,
            showCount: true,
            maxCount: 99,
            largeSize: 14,
            indicatorKey: indicatorKey,
            child: Icon(Icons.chat),
          ),
        ),
      ),
    );

    final indicator = find.byKey(indicatorKey);
    final size = tester.getSize(indicator);
    expect(size.height, 14);
    expect(size.width, greaterThan(size.height));
    expect(
      (tester.widget<Container>(indicator).decoration! as ShapeDecoration)
          .shape,
      isA<StadiumBorder>(),
    );
  });
}
