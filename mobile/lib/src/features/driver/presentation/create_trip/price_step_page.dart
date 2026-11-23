import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';
import '../widgets/price_summary.dart';

const _errorColor = Color(0xFFD92D20);

/// "Новый заказ", step 3 of 4: prices. The driver enters what they get;
/// the service commission is shown on top. Edits [draft] in place.
class PriceStepPage extends StatelessWidget {
  const PriceStepPage({
    super.key,
    required this.draft,
    required this.onNext,
    this.onBack,
  });

  final TripDraft draft;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final stops = draft.stops;
        return NewTripScaffold(
          step: 3,
          onBack: onBack,
          onNext: draft.isPriceStepComplete ? onNext : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((draft.fullPrice ?? 0) > 0) ...[
                PriceSummary(driverPrice: draft.fullPrice!),
                const SizedBox(height: 20),
              ],
              const Text(
                'Стоимость',
                key: ValueKey('price-title'),
                style: DriverText.label,
              ),
              const SizedBox(height: 12),
              // Keys keep the focused field alive when the summary appears above.
              _PriceCard(
                key: const ValueKey('card-full'),
                title: 'Весь маршрут',
                children: [
                  _Leg(from: stops.first, to: stops.last),
                  _PriceField(
                    key: const ValueKey('price-full'),
                    value: draft.fullPrice,
                    onChanged: (v) => draft.fullPrice = v,
                  ),
                ],
              ),
              if (draft.needsSegmentPrices) ...[
                const SizedBox(height: 12),
                _PriceCard(
                  key: const ValueKey('card-segments'),
                  title: 'Между остановками',
                  children: [
                    for (final (from, to) in draft.segments) ...[
                      _Leg(from: from, to: to),
                      _PriceField(
                        key: ValueKey('price-segment-${from.id}-${to.id}'),
                        value: draft.segmentPrice(from, to),
                        onChanged: (v) => draft.setSegmentPrice(from, to, v),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _PriceCard(
                key: const ValueKey('card-min'),
                title: 'Стоимость посадки',
                children: [
                  _PriceField(
                    key: const ValueKey('price-min'),
                    value: draft.minPrice,
                    onChanged: (v) => draft.minPrice = v,
                    errorText: draft.minPriceTooHigh
                        ? 'Не больше цены всего маршрута'
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DriverColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: DriverText.label.copyWith(fontSize: 13, height: 1.38),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// "Победителей 1, Минск → Рынок местный, Могилев"
class _Leg extends StatelessWidget {
  const _Leg({required this.from, required this.to});

  final RouteStop from;
  final RouteStop to;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: DriverColors.secondaryText,
      fontSize: 13,
      height: 1.38,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: from.text.trim()),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_right_alt_rounded,
                  size: 18,
                  color: DriverColors.text,
                ),
              ),
            ),
            TextSpan(text: to.text.trim()),
          ],
        ),
        style: style,
      ),
    );
  }
}

/// Underlined rubles input: "Цена" hint, "₽" suffix, digits only.
class _PriceField extends StatefulWidget {
  const _PriceField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final String? errorText;

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late final _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: DriverColors.divider),
    );
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      // Backend allows up to 100 000 ₽ per price.
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
        _MaxValueFormatter(100000),
      ],
      onChanged: (text) => widget.onChanged(int.tryParse(text)),
      style: DriverText.body.copyWith(color: DriverColors.text),
      decoration: InputDecoration(
        hintText: 'Цена',
        hintStyle: DriverText.body,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        suffixText: '₽',
        suffixStyle: const TextStyle(
          color: DriverColors.secondaryText,
          fontSize: 13,
        ),
        errorText: widget.errorText,
        errorStyle: const TextStyle(color: _errorColor, fontSize: 12),
        border: underline,
        enabledBorder: underline,
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: DriverColors.text),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _errorColor),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _errorColor),
        ),
      ),
    );
  }
}

class _MaxValueFormatter extends TextInputFormatter {
  const _MaxValueFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = int.tryParse(newValue.text);
    return value != null && value > max ? oldValue : newValue;
  }
}
