import 'package:flutter/material.dart';

import '../../trips/domain/passenger_api_exception.dart';
import '../domain/chat_models.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({
    super.key,
    required this.loadChats,
    required this.onOpenChat,
    required this.onBack,
    this.bottomNavigationBar,
  });

  final Future<List<AppChat>> Function() loadChats;
  final void Function(AppChat chat) onOpenChat;
  final VoidCallback onBack;
  final Widget? bottomNavigationBar;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  List<AppChat> _chats = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        key: const ValueKey('chats-back'),
        onPressed: widget.onBack,
        icon: const Icon(Icons.chevron_left),
      ),
      title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
    body: _content(),
    bottomNavigationBar: widget.bottomNavigationBar,
  );

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_chats.isEmpty) {
      return const Center(child: Text('У вас пока нет чатов'));
    }
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _chats.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              key: ValueKey('chat-${chat.id}'),
              onTap: () => widget.onOpenChat(chat),
              leading: CircleAvatar(
                backgroundImage: chat.counterpartAvatarUrl == null
                    ? null
                    : NetworkImage(chat.counterpartAvatarUrl!),
                child: chat.counterpartAvatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                chat.counterpartName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                chat.lastMessage?.text ??
                    '${chat.origin} — ${chat.destination}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: chat.unreadCount == 0
                  ? null
                  : CircleAvatar(
                      radius: 11,
                      backgroundColor: _primary,
                      child: Text(
                        '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await widget.loadChats();
      if (mounted) setState(() => _chats = chats);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is PassengerApiException
            ? error.message
            : 'Не удалось загрузить чаты',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
