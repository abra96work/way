String formatRubles(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    chunks.add(digits.substring((end - 3).clamp(0, end), end));
  }
  final amount = chunks.reversed.join('\u00A0');
  return '${negative ? '−' : ''}$amount\u00A0₽';
}
