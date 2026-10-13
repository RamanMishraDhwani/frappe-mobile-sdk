import '../models/doc_field.dart';
import '../models/session_user.dart';
import 'date_helpers.dart';

/// The value a new document starts with for [field], the way Desk sets it
/// (`frappe.model.get_default_value`, then `set_default_values`).
///
/// Tokens are resolved first:
/// - `__user` / `user` -> the signed-in [user]'s id, `user_fullname` -> their
///   full name;
/// - `now` -> the current time in the field type's format, `Today` on a Date
///   -> today's date (from [now], default [DateTime.now]);
/// - a token the SDK cannot resolve (no [user], or `:Doctype`, which reads
///   Desk's boot defaults) gives null, so the field starts unset and the server
///   fills it on insert instead of receiving the token's text.
///
/// The value is then typed: Int and Check go through `cint`, Float and
/// Currency through `flt`, every other type keeps the text. Desk assigns a
/// default only when its text is non-empty (`if (v)`), so an empty default on
/// a numeric field returns null.
///
/// Without the typing a Check whose default is `"0"` starts as the string
/// `"0"`, which `eval:doc.flag` reads as true (a non-empty string): every
/// field gated on a switch that is off is shown until the user flips it.
Object? typedDefaultValue(
  DocField field, {
  SessionUser? user,
  DateTime Function()? now,
}) {
  final raw = field.defaultValue;
  if (raw != null && raw.isNotEmpty) {
    final token = raw.toLowerCase();
    if (raw == '__user' || token == 'user') return user?.name;
    if (raw == 'user_fullname') return user?.fullName;
    if (raw.startsWith(':')) return null;
    if (token == 'now') {
      final t = (now ?? DateTime.now)();
      return switch (field.fieldtype) {
        'Time' => frappeTime(t),
        'Date' => frappeDate(t),
        _ => frappeDatetime(t),
      };
    }
    if (token == 'today' && field.fieldtype == 'Date') {
      return frappeDate((now ?? DateTime.now)());
    }
  }
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
