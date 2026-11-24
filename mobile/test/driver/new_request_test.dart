import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/presentation/trips/new_request_dialog.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('"Новый отклик" dialog opens the request', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showNewRequestDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Новый отклик'), findsOneWidget);
    expect(
      find.text(
        'Пассажир хочет присоединиться к вашей поездке. '
        'Ожидается ваше решение.',
      ),
      findsOneWidget,
    );
    await tester.tap(_key('event-dialog-open'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  test('watcher shows each request once and marks it read', () async {
    var unread = <RequestNotice>[
      const RequestNotice(id: 'n2', tripId: 't2'),
      const RequestNotice(id: 'n1', tripId: 't1'),
    ];
    final read = <String>[];
    final shown = <String>[];
    final watcher = RequestWatcher(
      fetchUnread: () async => unread,
      markRead: (id) async => read.add(id),
      present: (n) async => shown.add(n.tripId!),
    );

    await watcher.check();
    expect(read, ['n2', 'n1']);
    expect(shown, ['t2'], reason: 'one dialog for the newest');

    // The same notices again (read flag not synced yet): nothing new.
    await watcher.check();
    expect(shown, ['t2']);

    unread = [const RequestNotice(id: 'n3', tripId: 't3')];
    await watcher.check();
    expect(shown, ['t2', 't3']);
  });

  test('a failed poll is retried on the next tick', () async {
    var fail = true;
    final shown = <String>[];
    final watcher = RequestWatcher(
      fetchUnread: () async {
        if (fail) throw Exception('offline');
        return const [RequestNotice(id: 'n1', tripId: 't1')];
      },
      markRead: (_) async {},
      present: (n) async => shown.add(n.id),
    );

    await watcher.check();
    expect(shown, isEmpty);
    fail = false;
    await watcher.check();
    expect(shown, ['n1']);
  });

  testWidgets('"Пассажир оплатил поездку" dialog', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showPaidDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Пассажир оплатил поездку'), findsOneWidget);
    expect(
      find.text(
        'Пассажир успешно оплатил поездку. '
        'Место в вашей поездке забронировано.',
      ),
      findsOneWidget,
    );
    expect(find.text('Перейти к поездке'), findsOneWidget);
    await tester.tap(_key('event-dialog-open'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  test('event types map to dialogs', () {
    expect(DriverEvent.parse('booking_requested'), DriverEvent.request);
    expect(DriverEvent.parse('booking_paid'), DriverEvent.paid);
    expect(DriverEvent.parse('booking_cancelled'), isNull);
  });
}
