import 'package:flutter/material.dart';

import 'driver_style.dart';

/// Screen header: round back button on the left, title in the middle,
/// divider under it.
class DriverHeader extends StatelessWidget {
  const DriverHeader({super.key, required this.title, this.onBack});

  final String title;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
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
                  color: const Color(0xFFF7F7F8),
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('header-back'),
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
        ),
        const Divider(height: 1, thickness: 1, color: DriverColors.divider),
      ],
    );
  }
}
