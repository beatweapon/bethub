import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bet_hub/main.dart';

void main() {
  testWidgets('join button opens bet page and then result page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BetHubApp());

    expect(find.text('ユーザー名'), findsOneWidget);
    expect(find.text('入室する'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Ken');
    await tester.tap(find.text('入室する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ベット画面'), findsOneWidget);
    expect(find.text('Kenの所持コイン'), findsOneWidget);
    expect(find.text('Red Phoenix'), findsOneWidget);
    expect(find.text('プレイヤーのベット状況'), findsOneWidget);
    expect(find.text('Saki'), findsOneWidget);
    expect(find.text('Red Phoenixに120枚'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '120');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('120枚'), findsOneWidget);

    await tester.tap(find.text('結果画面へ進む'));
    await tester.pumpAndSettle();

    expect(find.text('結果画面'), findsOneWidget);
    expect(find.text('Mock Room'), findsOneWidget);
    expect(find.text('Ken'), findsOneWidget);
    expect(find.text('500枚'), findsOneWidget);
  });
}
