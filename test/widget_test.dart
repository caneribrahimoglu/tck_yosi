import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/app/app.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';

void main() {
  testWidgets('oturum yoksa login ekranı açılır', (WidgetTester tester) async {
    await tester.pumpWidget(TckYosiApp(authService: FakeAuthService()));

    await tester.pumpAndSettle();

    expect(find.text('KAYNAŞLI BAKIM VE İŞLETME ŞEFLİĞİ'), findsOneWidget);
    expect(find.text('Operasyon Yönetim Platformu'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
