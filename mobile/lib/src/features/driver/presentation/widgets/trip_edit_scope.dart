import 'package:flutter/material.dart';

import '../../domain/driver_api_exception.dart';
import 'driver_style.dart';

/// Puts the "Новый заказ" steps into "Изменение заказа" mode: another title,
/// "Шаг N из 4" and "Сохранить" next to "Далее". Wizard pages read it
/// through [NewTripScaffold], so they need no edit-specific code.
class TripEditScope extends InheritedWidget {
  const TripEditScope({
    super.key,
    required this.canSave,
    required this.onSave,
    this.onEditPrices,
    required super.child,
  });

  /// Wizard step → step shown while editing. The prices step (3) is not a
  /// step here: it opens from "Изменить стоимость" on the route step.
  static const steps = {1: 1, 2: 2, 4: 3, 5: 4};
  static const totalSteps = 4;
  static const routeStep = 2;
  static const pricesStep = 3;

  /// Evaluated on every rebuild of the page: changed and still valid.
  final bool Function() canSave;

  /// Saves the trip; throws [DriverApiException] with the reason.
  final Future<void> Function() onSave;

  /// "Изменить стоимость" on the route step.
  final VoidCallback? onEditPrices;

  static TripEditScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripEditScope>();

  @override
  bool updateShouldNotify(TripEditScope oldWidget) =>
      oldWidget.onSave != onSave || oldWidget.onEditPrices != onEditPrices;
}

/// Bottom of an editing step: "Изменить стоимость" (route step),
/// then "Сохранить" + "Далее", or only "Сохранить" on the last step.
class TripEditButtons extends StatefulWidget {
  const TripEditButtons({
    super.key,
    required this.scope,
    required this.wizardStep,
    required this.onNext,
  });

  final TripEditScope scope;
  final int wizardStep;
  final VoidCallback? onNext;

  @override
  State<TripEditButtons> createState() => _TripEditButtonsState();
}

class _TripEditButtonsState extends State<TripEditButtons> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.scope.onSave();
    } on DriverApiException catch (e) {
      _error(e.message);
    } catch (_) {
      _error('Не удалось сохранить. Проверьте интернет и повторите.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final shown = TripEditScope.steps[widget.wizardStep];
    const text = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.38,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    // The prices screen: just "Готово" back to the route step.
    if (shown == null) {
      return SizedBox(
        height: 48,
        child: FilledButton(
          key: const ValueKey('new-trip-next'),
          onPressed: widget.onNext,
          style: FilledButton.styleFrom(
            backgroundColor: DriverColors.primary,
            disabledBackgroundColor: DriverColors.divider,
            shape: shape,
            textStyle: DriverText.label,
          ),
          child: const Text('Готово'),
        ),
      );
    }

    final canSave = scope.canSave() && !_saving;
    final last = shown == TripEditScope.totalSteps;
    final save = SizedBox(
      height: 48,
      child: last
          ? FilledButton(
              key: const ValueKey('edit-save'),
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: DriverColors.primary,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: const Color(0xFF95969C),
                side: canSave
                    ? null
                    : const BorderSide(color: DriverColors.divider),
                shape: shape,
                textStyle: text,
              ),
              child: _label('Сохранить', Colors.white),
            )
          : OutlinedButton(
              key: const ValueKey('edit-save'),
              onPressed: canSave ? _save : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: DriverColors.primary,
                disabledForegroundColor: const Color(0xFF95969C),
                side: BorderSide(
                  color: canSave ? DriverColors.primary : DriverColors.divider,
                ),
                shape: shape,
                textStyle: text,
              ),
              child: _label('Сохранить', DriverColors.primary),
            ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown == TripEditScope.routeStep && scope.onEditPrices != null) ...[
          SizedBox(
            height: 44,
            child: OutlinedButton(
              key: const ValueKey('edit-prices'),
              onPressed: scope.onEditPrices,
              style: OutlinedButton.styleFrom(
                foregroundColor: DriverColors.primary,
                side: const BorderSide(color: DriverColors.primary),
                shape: shape,
                textStyle: text,
              ),
              child: const Text('Изменить стоимость'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (last)
          save
        else
          Row(
            children: [
              Expanded(child: save),
              const SizedBox(width: 9),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('new-trip-next'),
                    onPressed: _saving ? null : widget.onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: DriverColors.primary,
                      disabledBackgroundColor: DriverColors.divider,
                      shape: shape,
                      textStyle: text,
                    ),
                    child: const Text('Далее'),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _label(String text, Color spinner) => _saving
      ? SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: spinner),
        )
      : Text(text);
}
