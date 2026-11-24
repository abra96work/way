import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/passenger_api_exception.dart';

class PassengerInfoItem {
  const PassengerInfoItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = true,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool isRead;
}

class PassengerInfoListPage extends StatefulWidget {
  const PassengerInfoListPage({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.loadItems,
    required this.onBack,
  });

  final String title;
  final String emptyMessage;
  final Future<List<PassengerInfoItem>> Function() loadItems;
  final VoidCallback onBack;

  @override
  State<PassengerInfoListPage> createState() => _PassengerInfoListPageState();
}

class _PassengerInfoListPageState extends State<PassengerInfoListPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _secondary = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);

  List<PassengerInfoItem> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: _background,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  IconButton(
                    key: const ValueKey('passenger-info-back'),
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),
            const Divider(height: 1, color: _divider),
            Expanded(child: _content()),
          ],
        ),
      ),
    ),
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
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: const TextStyle(color: _secondary),
        ),
      );
    }
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            key: ValueKey('passenger-info-${item.id}'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: item.isRead ? null : Border.all(color: _primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.body),
                ],
                if (item.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _date(item.createdAt!),
                    style: const TextStyle(color: _secondary, fontSize: 12),
                  ),
                ],
              ],
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
      final items = await widget.loadItems();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is PassengerApiException
            ? error.message
            : 'Не удалось загрузить данные',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
