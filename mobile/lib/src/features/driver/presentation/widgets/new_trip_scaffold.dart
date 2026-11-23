import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'driver_style.dart';

/// Shared frame of the six "Новый заказ" steps: header with a back button,
/// "Шаг N из 6", scrollable content, the bottom "Далее" button and an
/// optional outlined button under it.
class NewTripScaffold extends StatelessWidget {
  const NewTripScaffold({
    super.key,
    required this.step,
    required this.child,
    this.title = 'Новый заказ',
    this.outlinedWhenDisabled = false,
    required this.onNext,
    this.onBack,
    this.totalSteps = 6,
    this.nextLabel = 'Далее',
    this.isSubmitting = false,
    this.secondaryLabel,
    this.onSecondary,
    this.isSecondarySubmitting = false,
  });

  /// `null` hides "Шаг N из 6" (screens outside the wizard).
  final int? step;
  final String title;

  /// Disabled main button drawn as an outline (the "Обратное направление" look).
  final bool outlinedWhenDisabled;
  final int totalSteps;
  final Widget child;

  /// `null` disables the button (the step is not filled in yet).
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String nextLabel;
  final bool isSubmitting;

  /// Outlined button under the main one (shown when [secondaryLabel] is set).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isSecondarySubmitting;

  bool get _busy => isSubmitting || isSecondarySubmitting;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: DriverColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DriverColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: title, onBack: onBack),
              const Divider(
                height: 1,
                thickness: 1,
                color: DriverColors.divider,
              ),
              if (step != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(
                    'Шаг $step из $totalSteps',
                    key: const ValueKey('new-trip-step'),
                    textAlign: TextAlign.right,
                    style: DriverText.label,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    step == null ? 20 : 12,
                    16,
                    16,
                  ),
                  child: child,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('new-trip-next'),
                        onPressed: _busy ? null : onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: DriverColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: outlinedWhenDisabled
                              ? Colors.transparent
                              : DriverColors.divider,
                          disabledForegroundColor: outlinedWhenDisabled
                              ? const Color(0xFF95969C)
                              : DriverColors.secondaryText,
                          side: outlinedWhenDisabled && onNext == null
                              ? const BorderSide(color: DriverColors.divider)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.33,
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(nextLabel),
                      ),
                    ),
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const ValueKey('new-trip-secondary'),
                          onPressed: _busy ? null : onSecondary,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DriverColors.primary,
                            side: const BorderSide(color: DriverColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.33,
                            ),
                          ),
                          child: isSecondarySubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DriverColors.primary,
                                  ),
                                )
                              : Text(secondaryLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DriverText.title,
            ),
          ),
          Positioned(
            left: 8,
            child: Material(
              color: DriverColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey('new-trip-back'),
                customBorder: const CircleBorder(),
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: DriverColors.text,
                    semanticLabel: 'Назад',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
