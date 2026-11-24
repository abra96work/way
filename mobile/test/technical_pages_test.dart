import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/technical/presentation/technical_pages.dart';

void main() {
  testWidgets('technical loading screen shows the green progress indicator', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: TechnicalLoadingPage()));

    expect(
      find.byKey(const ValueKey('technical-loading-page')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('offline screen retries the failed action', (tester) async {
    _setViewport(tester);
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(home: TechnicalOfflinePage(onRetry: () => retries++)),
    );

    expect(find.text('Нет интернет-соединения'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('technical-retry')));
    expect(retries, 1);
  });

  testWidgets('generic error screen has the designed copy', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: TechnicalErrorPage(onRetry: () {})),
    );

    expect(find.text('Не удалось выполнить действие'), findsOneWidget);
    expect(find.textContaining('Если ошибка останется'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
  });

  testWidgets('blocked account screen uses the branded composition', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: TechnicalAccountBlockedPage()),
    );

    expect(
      find.byKey(const ValueKey('technical-account-blocked-page')),
      findsOneWidget,
    );
    expect(find.text('Путь'), findsOneWidget);
    expect(find.text('Ваш аккаунт заблокирован'), findsOneWidget);
    expect(find.textContaining('нарушений условий'), findsOneWidget);
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
