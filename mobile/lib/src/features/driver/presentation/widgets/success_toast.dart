import 'package:flutter/material.dart';

import 'driver_style.dart';

/// Green "Изменения сохранены" note from the design: check icon, text and ×.
SnackBar successToast(String text) => SnackBar(
  key: const ValueKey('success-toast'),
  behavior: SnackBarBehavior.floating,
  backgroundColor: DriverColors.primary,
  elevation: 8,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  content: Row(
    children: [
      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.38,
          ),
        ),
      ),
    ],
  ),
  showCloseIcon: true,
  closeIconColor: Colors.white,
);

void showSuccessToast(ScaffoldMessengerState? messenger, String text) {
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(successToast(text));
}
