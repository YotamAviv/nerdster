import 'package:flutter/services.dart';

class AlphaOnlyFormatter extends TextInputFormatter {
  final _regExp = RegExp(r'^[a-zA-Z\s]*$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (_regExp.hasMatch(newValue.text)) {
      return newValue; // Accept change
    }
    return oldValue; // Reject change
  }
}
