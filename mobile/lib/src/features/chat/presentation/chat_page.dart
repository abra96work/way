import 'dart:async';

import 'package:flutter/material.dart';

import '../../trips/domain/passenger_api_exception.dart';
import '../domain/chat_models.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.loadChat,
    required this.loadMessages,
    required this.sendMessage,
    required this.markRead,
    required this.onBack,
  });

  final Future<AppChat> Function() loadChat;
  final Future<List<AppChatMessage>> Function() loadMessages;
  final Future<AppChatMessage> Function(String text) sendMessage;
  final Future<void> Function() markRead;
  final VoidCallback onBack;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  AppChat? _chat;
  List<AppChatMessage> _messages = const [];
  String? _error;
  bool _sending = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: widget.onBack,
        icon: const Icon(Icons.chevron_left),
      ),
      title: Text(
        _chat?.counterpartName ?? 'Чат',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: Column(
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        Expanded(
          child: _messages.isEmpty && _error == null
              ? const Center(child: Text('Сообщений пока нет'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Align(
                      alignment: message.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        key: ValueKey('chat-message-${message.id}'),
                        constraints: const BoxConstraints(maxWidth: 280),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: message.isMine ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.isMine ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-input'),
                    controller: _controller,
                    enabled: _chat?.canWrite ?? false,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _chat?.canWrite == false
                          ? 'Поездка завершена'
                          : 'Сообщение',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('chat-send'),
                  onPressed: _sending || !(_chat?.canWrite ?? false)
                      ? null
                      : _send,
                  style: IconButton.styleFrom(backgroundColor: _primary),
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        widget.loadChat(),
        widget.loadMessages(),
      ]);
      if (!mounted) return;
      setState(() {
        _chat = values[0] as AppChat;
        _messages = values[1] as List<AppChatMessage>;
        _error = null;
      });
      await widget.markRead();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is PassengerApiException
            ? error.message
            : 'Не удалось загрузить чат',
      );
    }
  }

  Future<void> _refresh() async {
    try {
      final messages = await widget.loadMessages();
      if (!mounted) return;
      final changed =
          messages.length != _messages.length ||
          (messages.isNotEmpty &&
              (_messages.isEmpty || messages.last.id != _messages.last.id));
      if (changed) {
        setState(() => _messages = messages);
        await widget.markRead();
        _scrollToBottom();
      }
    } catch (_) {
      // A transient polling error must not replace an already open chat.
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final message = await widget.sendMessage(text);
      if (!mounted) return;
      _controller.clear();
      setState(() => _messages = [..._messages, message]);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PassengerApiException
                ? error.message
                : 'Не удалось отправить сообщение',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}
