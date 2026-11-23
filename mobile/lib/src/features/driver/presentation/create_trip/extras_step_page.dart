import 'package:flutter/material.dart';

import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';
import '../widgets/price_summary.dart';

/// "Новый заказ", step 5 of 6: extras for passengers and parcels.
/// Everything here is optional, so "Далее" is always enabled.
class ExtrasStepPage extends StatelessWidget {
  const ExtrasStepPage({
    super.key,
    required this.draft,
    required this.onNext,
    this.onBack,
  });

  final TripDraft draft;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  static const _extraIcons = {
    TripExtraKind.childSeat: Icons.child_friendly_outlined,
    TripExtraKind.luggage: Icons.work_outline_rounded,
    TripExtraKind.pets: Icons.pets_outlined,
  };

  Future<void> _openParcels(BuildContext context) async {
    final result = await showModalBottomSheet<Set<ParcelSize>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DriverColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ParcelSheet(initial: draft.parcelSizes),
    );
    if (result != null) draft.parcelSizes = result;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => NewTripScaffold(
        step: 5,
        onBack: onBack,
        onNext: onNext,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Дополнительные услуги', style: DriverText.label),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: DriverColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final kind in TripExtraKind.values)
                    _ServiceRow(
                      key: ValueKey('extra-${kind.value}'),
                      icon: _extraIcons[kind]!,
                      title: kind.title,
                      price: draft.extras.contains(kind)
                          ? '+${formatRubles(kind.price)}'
                          : null,
                      trailing: DriverToggle(
                        value: draft.extras.contains(kind),
                        onChanged: (v) => draft.setExtra(kind, v),
                      ),
                      onTap: () =>
                          draft.setExtra(kind, !draft.extras.contains(kind)),
                    ),
                  _ServiceRow(
                    key: const ValueKey('extra-parcel'),
                    icon: Icons.inventory_2_outlined,
                    title: 'Посылка',
                    price: _parcelPrice(draft.parcelSizes),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: DriverColors.text,
                    ),
                    divider: false,
                    onTap: () => _openParcels(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "до 350 ₽" while nothing is chosen, else the chosen price or range.
  static String _parcelPrice(Set<ParcelSize> sizes) {
    if (sizes.isEmpty) {
      return 'до ${formatRubles(ParcelSize.values.last.price)}';
    }
    final prices = [for (final s in sizes) s.price]..sort();
    if (prices.first == prices.last) return formatRubles(prices.first);
    return '${prices.first}–${formatRubles(prices.last)}';
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.price,
    this.divider = true,
  });

  final IconData icon;
  final String title;
  final String? price;
  final Widget trailing;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: DriverColors.divider)),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 18, color: DriverColors.secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: DriverColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.38,
                ),
              ),
            ),
            if (price != null) ...[
              Text(
                price!,
                style: DriverText.body.copyWith(color: DriverColors.primary),
              ),
              const SizedBox(width: 16),
            ],
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Switch from the design: off — light track with a green rim and a green
/// knob on the left; on — green track with a white knob on the right.
class DriverToggle extends StatelessWidget {
  const DriverToggle({super.key, required this.value, this.onChanged});

  final bool value;

  /// `null` makes the switch read-only.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 150);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: duration,
          width: 39,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: value ? DriverColors.primary : const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(75),
            border: Border.all(color: DriverColors.primary, width: 1.5),
          ),
          child: AnimatedAlign(
            duration: duration,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? Colors.white : DriverColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet "Посылка": which parcel sizes the driver takes.
/// Pops with the chosen set ("Добавить") or `null` ("Отмена").
class ParcelSheet extends StatefulWidget {
  const ParcelSheet({super.key, required this.initial});

  final Set<ParcelSize> initial;

  @override
  State<ParcelSheet> createState() => _ParcelSheetState();
}

class _ParcelSheetState extends State<ParcelSheet> {
  late final Set<ParcelSize> _chosen = {...widget.initial};

  void _toggle(ParcelSize size) => setState(() {
    if (!_chosen.remove(size)) _chosen.add(size);
  });

  // Saving an empty set is how the driver stops taking parcels.
  bool get _canSave => _chosen.isNotEmpty || widget.initial.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final secondary = DriverText.body.copyWith(fontSize: 13, height: 1.38);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 16),
            const Text('Посылка', style: DriverText.cardTitle),
            const SizedBox(height: 4),
            Text(
              'Выберите, какие посылки готовы взять',
              style: DriverText.body,
            ),
            const SizedBox(height: 16),
            for (final size in ParcelSize.values) ...[
              _ParcelTile(
                key: ValueKey('parcel-${size.value}'),
                size: size,
                selected: _chosen.contains(size),
                onTap: () => _toggle(size),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: DriverColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Без проезда пассажира',
                        style: TextStyle(
                          color: DriverColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.38,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Можно отправить только посылку, без места в авто',
                        style: secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Parcels always travel without a passenger on the backend
                // (booking kind "parcel"), so this is shown as a fact.
                const DriverToggle(value: true),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const ValueKey('parcel-cancel'),
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DriverColors.primary,
                        side: const BorderSide(color: DriverColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: DriverText.label,
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('parcel-save'),
                      onPressed: _canSave
                          ? () => Navigator.pop(context, {..._chosen})
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: DriverColors.primary,
                        disabledBackgroundColor: DriverColors.background,
                        disabledForegroundColor: DriverColors.secondaryText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: DriverText.label,
                      ),
                      child: Text(
                        widget.initial.isNotEmpty && _chosen.isEmpty
                            ? 'Сохранить'
                            : 'Добавить',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelTile extends StatelessWidget {
  const _ParcelTile({
    super.key,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final ParcelSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      label: '${size.title}, ${size.hint}, ${formatRubles(size.price)}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? const Color(0xFFE6F6EB) : DriverColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? DriverColors.primary : DriverColors.divider,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/driver/parcel_${size.value.toLowerCase()}.png',
                    // Exported at x3: 114×126 px.
                    width: 38,
                    height: 42,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 38,
                      height: 42,
                      child: ColoredBox(
                        color: DriverColors.background,
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: DriverColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(size.title, style: DriverText.label),
                      const SizedBox(height: 2),
                      Text(
                        size.hint,
                        style: DriverText.body.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${formatRubles(size.price)}',
                  style: DriverText.body.copyWith(color: DriverColors.primary),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? DriverColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: DriverColors.primary, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
