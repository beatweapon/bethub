import 'package:bet_hub/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entry page renders join form', (tester) async {
    await tester.pumpWidget(const BetHubApp());

    expect(find.text('Bet Hub'), findsOneWidget);
    expect(find.text('ユーザー名'), findsOneWidget);
    expect(find.text('入室する'), findsOneWidget);
  });
}
