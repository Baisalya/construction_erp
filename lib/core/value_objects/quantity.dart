import 'package:flutter/foundation.dart';

import 'money.dart';

@immutable
class DecimalQuantity implements Comparable<DecimalQuantity> {
  const DecimalQuantity._(this._scaled);

  factory DecimalQuantity.parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return zero;
    }
    final isNegative = trimmed.startsWith('-');
    final unsigned = isNegative ? trimmed.substring(1) : trimmed;
    final parts = unsigned.split('.');
    if (parts.length > 2 || parts.first.isEmpty) {
      throw FormatException('Invalid quantity', value);
    }
    final whole = int.parse(parts.first);
    final fraction = parts.length == 2
        ? parts[1].padRight(scaleDigits, '0')
        : ''.padRight(scaleDigits, '0');
    if (fraction.length > scaleDigits) {
      throw FormatException(
          'Quantity supports up to $scaleDigits decimal places', value);
    }
    final parsed = (whole * scale) + int.parse(fraction);
    return DecimalQuantity._(isNegative ? -parsed : parsed);
  }

  factory DecimalQuantity.whole(int value) => DecimalQuantity._(value * scale);

  static const int scale = 1000;
  static const int scaleDigits = 3;
  static const zero = DecimalQuantity._(0);

  final int _scaled;

  int get scaledValue => _scaled;
  bool get isZero => _scaled == 0;
  bool get isNegative => _scaled < 0;

  Money multiplyMoney(Money rate) {
    final raw = BigInt.from(rate.paise) * BigInt.from(_scaled);
    final quotient = raw ~/ BigInt.from(scale);
    final remainder = raw.remainder(BigInt.from(scale)).abs();
    final rounded = remainder >= BigInt.from(scale ~/ 2)
        ? quotient + BigInt.from(raw.isNegative ? -1 : 1)
        : quotient;
    return Money.fromPaise(rounded.toInt());
  }

  String toStorageString() => toString();

  @override
  int compareTo(DecimalQuantity other) => _scaled.compareTo(other._scaled);

  @override
  String toString() {
    final absolute = _scaled.abs();
    final whole = absolute ~/ scale;
    final fraction = absolute % scale;
    final sign = _scaled < 0 ? '-' : '';
    if (fraction == 0) {
      return '$sign$whole';
    }
    final fractionText = fraction
        .toString()
        .padLeft(scaleDigits, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '$sign$whole.$fractionText';
  }

  @override
  bool operator ==(Object other) =>
      other is DecimalQuantity && other._scaled == _scaled;

  @override
  int get hashCode => _scaled.hashCode;
}
