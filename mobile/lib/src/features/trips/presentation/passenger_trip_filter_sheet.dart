import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/passenger_trip.dart';

enum LocationAccessChoice { allow, skip }

Future<LocationAccessChoice?> showLocationAccessDialog(BuildContext context) {
  return showDialog<LocationAccessChoice>(
    context: context,
    barrierColor: const Color(0x660C0C0C),
    builder: (context) => Dialog(
      key: const ValueKey('location-access-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: const Color(0xFFF1F2F3),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: SizedBox(
                width: 90,
                height: 80,
                child: Transform.scale(
                  scale: 1.47,
                  child: Image.asset(
                    'assets/images/passenger/location_access.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Доступ к геолокации',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Разрешите доступ к геолокации — так\n'
              'будет проще найти подходящий вариант',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0x7F0C0C0C),
                fontSize: 15,
                height: 1.33,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                key: const ValueKey('location-access-allow'),
                onPressed: () =>
                    Navigator.pop(context, LocationAccessChoice.allow),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1EB74D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Разрешить'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                key: const ValueKey('location-access-skip'),
                onPressed: () =>
                    Navigator.pop(context, LocationAccessChoice.skip),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1EB74D),
                  side: const BorderSide(color: Color(0xFF1EB74D)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Пропустить'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<PassengerTripFilter?> showPassengerTripFilterSheet(
  BuildContext context, {
  required PassengerTripFilter initialFilter,
}) {
  return showModalBottomSheet<PassengerTripFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    barrierColor: const Color(0x660C0C0C),
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PassengerTripFilterSheet(initialFilter: initialFilter),
    ),
  );
}

class _PassengerTripFilterSheet extends StatefulWidget {
  const _PassengerTripFilterSheet({required this.initialFilter});

  final PassengerTripFilter initialFilter;

  @override
  State<_PassengerTripFilterSheet> createState() =>
      _PassengerTripFilterSheetState();
}

class _PassengerTripFilterSheetState extends State<_PassengerTripFilterSheet> {
  static const _primary = Color(0xFF1EB74D);
  static const _divider = Color(0xFFE4E5E6);
  late final TextEditingController _fromController;
  late final TextEditingController _toController;

  bool get _hasManualValue =>
      _fromController.text.trim().isNotEmpty ||
      _toController.text.trim().isNotEmpty;

  bool get _canClear => _hasManualValue || widget.initialFilter.isActive;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(
      text: widget.initialFilter.fromQuery ?? '',
    );
    _toController = TextEditingController(
      text: widget.initialFilter.toQuery ?? '',
    );
    _fromController.addListener(_refresh);
    _toController.addListener(_refresh);
  }

  @override
  void dispose() {
    _fromController
      ..removeListener(_refresh)
      ..dispose();
    _toController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('passenger-filter-sheet'),
      color: const Color(0xFFF1F2F3),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 298,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 29),
          child: Column(
            children: [
              Container(
                width: 43,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCACBCE),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Фильтры',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('passenger-filter-clear'),
                    onPressed: _canClear
                        ? () =>
                              Navigator.pop(context, PassengerTripFilter.empty)
                        : null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(57, 22),
                      foregroundColor: const Color(0xFFFF383C),
                      disabledForegroundColor: const Color(0xFFCACBCE),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Очистить',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Маршрут',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 10,
                    height: 112,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/passenger/filter_route.svg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        _RouteFilterField(
                          fieldKey: const ValueKey('passenger-filter-from'),
                          controller: _fromController,
                          label: 'Откуда',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 8),
                        _RouteFilterField(
                          fieldKey: const ValueKey('passenger-filter-to'),
                          controller: _toController,
                          label: 'Куда',
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  key: const ValueKey('passenger-filter-apply'),
                  onPressed: _hasManualValue
                      ? () => Navigator.pop(
                          context,
                          PassengerTripFilter.manual(
                            from: _fromController.text,
                            to: _toController.text,
                          ),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: const Color(0x7F0C0C0C),
                    side: const BorderSide(color: _divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Применить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteFilterField extends StatelessWidget {
  const _RouteFilterField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.textInputAction,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        key: fieldKey,
        controller: controller,
        textInputAction: textInputAction,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0x7F0C0C0C), fontSize: 15),
          floatingLabelStyle: const TextStyle(
            color: Color(0x7F0C0C0C),
            fontSize: 12,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE4E5E6)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF0C0C0C)),
          ),
        ),
      ),
    );
  }
}
