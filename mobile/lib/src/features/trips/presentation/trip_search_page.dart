import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class TripSearchPage extends ConsumerStatefulWidget {
  const TripSearchPage({super.key});

  @override
  ConsumerState<TripSearchPage> createState() => _TripSearchPageState();
}

class _TripSearchPageState extends ConsumerState<TripSearchPage> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _passengers = 1;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(apiHealthProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.route_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Путь',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
                _ApiStatus(health: health),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              'Куда едем?',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Найдите попутчиков и разделите стоимость поездки',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextField(
                      controller: _fromController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Откуда',
                        prefixIcon: Icon(Icons.trip_origin_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _toController,
                      decoration: const InputDecoration(
                        labelText: 'Куда',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.calendar_today_outlined,
                            label: _formatDate(_date),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.people_alt_outlined,
                            label:
                                '$_passengers ${_passengerWord(_passengers)}',
                            onTap: _pickPassengers,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _search,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Найти поездку'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _FeatureRow(
              icon: Icons.verified_user_outlined,
              title: 'Надёжные попутчики',
              subtitle: 'Профили, рейтинги и отзывы после поездки',
            ),
            const SizedBox(height: 12),
            const _FeatureRow(
              icon: Icons.payments_outlined,
              title: 'Честная цена',
              subtitle: 'Стоимость известна заранее, без скрытых условий',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickPassengers() async {
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Количество пассажиров',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (var count = 1; count <= 4; count++)
              ListTile(
                title: Text('$count ${_passengerWord(count)}'),
                trailing: count == _passengers ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, count),
              ),
          ],
        ),
      ),
    );
    if (value != null) setState(() => _passengers = value);
  }

  void _search() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поиск поездок подключим на следующем этапе'),
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}';

  static String _passengerWord(int value) =>
      value == 1 ? 'пассажир' : 'пассажира';
}

class _ApiStatus extends StatelessWidget {
  const _ApiStatus({required this.health});

  final AsyncValue<bool> health;

  @override
  Widget build(BuildContext context) {
    final online = health.value ?? false;
    return Tooltip(
      message: online ? 'API подключён' : 'API недоступен',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: online ? Colors.green : Colors.orange,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(label, maxLines: 1)),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 23, child: Icon(icon)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
