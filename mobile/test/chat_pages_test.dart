import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/chat/domain/chat_models.dart';
import 'package:put/src/features/chat/presentation/chat_list_page.dart';
import 'package:put/src/features/chat/presentation/chat_page.dart';

void main() {
  const chat = AppChat(
    id: 'chat-1',
    counterpartName: 'Виктор Орлов',
    counterpartAvatarUrl: null,
    origin: 'Москва',
    destination: 'Тверь',
    departureAt: null,
    unreadCount: 2,
    canWrite: true,
    lastMessage: AppChatMessage(
      id: 1,
      text: 'До встречи',
      createdAt: null,
      isMine: false,
    ),
  );

  testWidgets('chat list shows unread conversations and opens one', (
    tester,
  ) async {
    AppChat? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatListPage(
          loadChats: () async => [chat],
          onOpenChat: (value) => opened = value,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Виктор Орлов'), findsOneWidget);
    expect(find.text('До встречи'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-chat-1')));
    expect(opened, same(chat));
  });

  testWidgets('chat loads, marks read and sends a message', (tester) async {
    var markedRead = 0;
    String? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          loadChat: () async => chat,
          loadMessages: () async => [chat.lastMessage!],
          sendMessage: (text) async {
            sent = text;
            return const AppChatMessage(
              id: 2,
              text: 'Спасибо',
              createdAt: null,
              isMine: true,
            );
          },
          markRead: () async => markedRead++,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(markedRead, 1);
    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Спасибо');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();
    expect(sent, 'Спасибо');
    expect(find.text('Спасибо'), findsOneWidget);
  });
}
