import 'package:flutter_test/flutter_test.dart';
import 'package:skul_like/main.dart';
import 'package:skul_like/game/meta.dart';

void main() {
  testWidgets('town screen builds', (WidgetTester tester) async {
    final meta = MetaState();
    await tester.pumpWidget(SkulLikeApp(meta: meta));
    expect(find.byType(RootScreen), findsOneWidget);
  });
}
