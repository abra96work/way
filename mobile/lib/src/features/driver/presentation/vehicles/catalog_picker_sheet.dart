import 'package:flutter/material.dart';

import '../../domain/trip_draft.dart' show foldName;
import '../widgets/driver_style.dart';

/// A car brand or model from `GET /cars/brands[/{id}/models]`.
@immutable
class CatalogItem {
  const CatalogItem({required this.id, required this.name});

  factory CatalogItem.fromJson(Map<String, dynamic> json) =>
      CatalogItem(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CatalogItem && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// "Выбрать марку автомобиля" / "Выбрать модель …": a searchable list.
/// Resolves to the picked item, `null` when closed.
Future<CatalogItem?> showCatalogPicker(
  BuildContext context, {
  required String title,
  required String hint,
  required Future<List<CatalogItem>> Function() load,
  bool grouped = false,
  bool carIcons = false,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<CatalogItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: DriverColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: CatalogPickerSheet(
        title: title,
        hint: hint,
        load: load,
        grouped: grouped,
        carIcons: carIcons,
      ),
    ),
  );
}

class CatalogPickerSheet extends StatefulWidget {
  const CatalogPickerSheet({
    super.key,
    required this.title,
    required this.hint,
    required this.load,
    this.grouped = false,
    this.carIcons = false,
  });

  final String title;
  final String hint;
  final Future<List<CatalogItem>> Function() load;

  /// Letter headers ("A", "B", …) — the brand list in the design.
  final bool grouped;
  final bool carIcons;

  @override
  State<CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<CatalogPickerSheet> {
  late Future<List<CatalogItem>> _items = widget.load();
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<CatalogItem> _filter(List<CatalogItem> all) {
    final q = foldName(_query.text.trim());
    if (q.isEmpty) return all;
    return [
      for (final item in all)
        if (foldName(item.name).contains(q)) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final active = _focus.hasFocus || _query.text.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: DriverColors.divider,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(widget.title, style: DriverText.cardTitle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('catalog-search'),
              controller: _query,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              style: DriverText.body.copyWith(color: DriverColors.text),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: DriverText.body,
                isDense: true,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: active
                      ? DriverColors.primary
                      : DriverColors.secondaryText,
                ),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('catalog-clear'),
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        color: DriverColors.text,
                        onPressed: _query.clear,
                      ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: DriverColors.divider),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: DriverColors.primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CatalogItem>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: DriverColors.primary,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Не удалось загрузить список',
                          style: DriverText.body,
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _items = widget.load();
                          }),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                final items = _filter(snapshot.data!);
                if (items.isEmpty) {
                  return Center(
                    child: Text('Ничего не нашлось', style: DriverText.body),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _rows(items),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(List<CatalogItem> items) {
    final rows = <Widget>[];
    String? letter;
    for (final item in items) {
      if (widget.grouped) {
        final first = item.name.isEmpty ? '' : item.name[0].toUpperCase();
        if (first != letter) {
          letter = first;
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(first, style: DriverText.label),
            ),
          );
        }
      }
      rows.add(
        InkWell(
          key: ValueKey('catalog-item-${item.id}'),
          onTap: () => Navigator.pop(context, item),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DriverColors.divider)),
            ),
            child: Row(
              children: [
                if (widget.carIcons) ...[
                  const Icon(
                    Icons.directions_car_filled_rounded,
                    size: 18,
                    color: DriverColors.text,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: DriverColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return rows;
  }
}
