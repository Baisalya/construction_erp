import 'package:flutter/foundation.dart';

@immutable
class Money implements Comparable<Money> {
  const Money.fromPaise(this.paise);

  factory Money.rupees(int rupees) => Money.fromPaise(rupees * 100);

  factory Money.parseRupees(String value) {
    final trimmed = value.trim().replaceAll(',', '');
    if (trimmed.isEmpty) {
      return Money.zero;
    }

    final isNegative = trimmed.startsWith('-');
    final unsigned = isNegative ? trimmed.substring(1) : trimmed;
    final parts = unsigned.split('.');
    if (parts.length > 2 || parts.first.isEmpty) {
      throw FormatException('Invalid money amount', value);
    }

    final rupees = int.parse(parts.first);
    final paiseText = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    if (paiseText.length > 2) {
      throw FormatException('Money supports up to 2 decimal places', value);
    }

    final parsed = (rupees * 100) + int.parse(paiseText);
    return Money.fromPaise(isNegative ? -parsed : parsed);
  }

  static const zero = Money.fromPaise(0);

  final int paise;

  Money operator +(Money other) => Money.fromPaise(paise + other.paise);
  Money operator -(Money other) => Money.fromPaise(paise - other.paise);
  Money operator -() => Money.fromPaise(-paise);

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;
  bool get isPositive => paise > 0;

  String format({String symbol = '₹'}) {
    final absolute = paise.abs();
    final rupees = absolute ~/ 100;
    final paisePart = absolute % 100;
    final sign = paise < 0 ? '-' : '';
    return '$sign$symbol${_indianDigits(rupees)}.${paisePart.toString().padLeft(2, '0')}';
  }

  static String _indianDigits(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    final leading = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    for (var end = leading.length; end > 0; end -= 2) {
      groups.insert(0, leading.substring(end < 2 ? 0 : end - 2, end));
    }
    return '${groups.join(',')},$lastThree';
  }

  String get inputText {
    final rupees = paise ~/ 100;
    final remainder = paise.abs() % 100;
    return remainder == 0
        ? rupees.toString()
        : '$rupees.${remainder.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) {
    return other is Money && other.paise == paise;
  }

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => format();
}
