import '../models/doc_field.dart';

/// The value a new document starts with for [field], typed the way Desk types
/// it in `frappe.model.set_default_values`: Int and Check go through `cint`,
/// Float and Currency through `flt`, and every other type keeps the default
/// text as it is.
///
/// Desk assigns a default only when its text is non-empty (`if (v)`), so an
/// empty default on a numeric field returns null and the field starts unset.
///
/// Without this a Check whose default is `"0"` starts as the string `"0"`,
/// which `eval:doc.flag` reads as true (a non-empty string): every field gated
/// on a switch that is off is shown until the user flips the switch.
Object? typedDefaultValue(DocField field) {
  final raw = field.defaultValue;
  switch (field.fieldtype) {
    case 'Int':
    case 'Check':
      return (raw == null || raw.isEmpty) ? null : _cint(raw);
    case 'Float':
    case 'Currency':
      return (raw == null || raw.isEmpty) ? null : _flt(raw);
    default:
      return raw;
  }
}

final RegExp _leadingInt = RegExp(r'^\s*[+-]?\d+');
final RegExp _leadingNumber = RegExp(
  r'^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?',
);

/// Frappe's `cint`: the leading integer (`parseInt`), or 0.
int _cint(String v) {
  final m = _leadingInt.firstMatch(v);
  return m == null ? 0 : int.parse(m.group(0)!.trim());
}

/// Frappe's `flt` without a precision: digit-group commas removed, then the
/// leading number (`parseFloat`), or 0. A whole number stays an int, as
/// JavaScript prints it.
num _flt(String v) {
  final m = _leadingNumber.firstMatch(v.replaceAll(',', ''));
  return m == null ? 0 : num.parse(m.group(0)!.trim());
}
