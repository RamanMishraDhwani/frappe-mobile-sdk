import 'dart:math' as math;

import '../models/doc_field.dart';
import 'date_helpers.dart';

/// [value] the way Desk would hold [field]'s value when the document is saved:
/// - Date, Datetime and Time in Frappe's text format, empty as null
///   ([frappeTemporalValue]);
/// - Float, Currency and Percent with a `precision` rounded to it, as
///   `ControlFloat.parse` does with `flt(value, precision)`. The server stores
///   what it receives without rounding, so the form has to.
/// Any other value is returned unchanged.
Object? frappeSaveValue(DocField field, Object? value) {
  final type = field.fieldtype;
  if (temporalFieldtypes.contains(type)) {
    return frappeTemporalValue(type, value);
  }
  final precision = field.precision;
  if (precision != null &&
      precision >= 0 &&
      value is num &&
      (type == 'Float' || type == 'Currency' || type == 'Percent')) {
    return frappeRound(value, precision);
  }
  return value;
}

/// Frappe's `_round` with its default method ("Banker's Rounding (legacy)")
/// and an explicit precision: the magnitude, first fixed to 8 decimals to drop
/// float noise, rounded half up, sign restored.
num frappeRound(num value, int precision) {
  final m = math.pow(10, precision);
  final n = double.parse((value.abs() * m).toStringAsFixed(8));
  final r = n.round() / m;
  return value < 0 ? -r : r;
}
