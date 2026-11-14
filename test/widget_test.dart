import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcela_a/widgets/brand_mark.dart';

void main() {
  testWidgets('BrandMark é exibido', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark())),
    );
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
