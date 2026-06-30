import 'package:flutter/services.dart';

class PositiveDecimalInputFormatter extends TextInputFormatter {
  const PositiveDecimalInputFormatter({this.decimalPlaces = 2});

  final int decimalPlaces;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pattern = RegExp('^\\d*(?:\\.\\d{0,$decimalPlaces})?\$');
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
