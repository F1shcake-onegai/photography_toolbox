import 'package:flutter/material.dart';

/// Always-on underline: thin line when unfocused, primary when focused.
/// Used for compact inline value fields (time, temperature, RGB).
InputDecoration underlineAlwaysDecoration(ColorScheme cs, {
  String? hintText,
  TextStyle? hintStyle,
  String? counterText,
  String? suffixText,
  TextStyle? suffixStyle,
}) {
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
    filled: false,
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: cs.outlineVariant),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
    hintText: hintText,
    hintStyle: hintStyle,
    counterText: counterText ?? '',
    suffixText: suffixText,
    suffixStyle: suffixStyle,
  );
}

/// Hover underline: no border when unfocused, primary underline on focus.
/// Used for coordinate fields that should look like plain text until tapped.
InputDecoration underlineHoverDecoration(ColorScheme cs) {
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
    filled: false,
    enabledBorder: InputBorder.none,
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
  );
}
