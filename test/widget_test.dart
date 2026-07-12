import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/app/app.dart';

void main() {
  testWidgets('TCK YÖSİ uygulaması açılır', (WidgetTester tester) async {
    await tester.pumpWidget(const TckYosiApp());

    expect(find.text('TCK YÖSİ'), findsWidgets);
  });
}
