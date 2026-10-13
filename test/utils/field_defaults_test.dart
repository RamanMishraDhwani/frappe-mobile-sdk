import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/src/models/doc_field.dart';
import 'package:frappe_mobile_sdk/src/utils/field_defaults.dart';

/// A new document's defaults, typed the way Desk types them
/// (`frappe.model.set_default_values`): Int and Check through `cint`,
/// Float and Currency through `flt`. A Check whose default is `"0"` must start
/// as the number 0, or `eval:doc.flag` reads the string `"0"` as true.
void main() {
  Object? d(String fieldtype, String? def) => typedDefaultValue(
    DocField(fieldname: 'f', fieldtype: fieldtype, defaultValue: def),
  );

  test('Check and Int defaults become integers (cint)', () {
    expect(d('Check', '0'), 0);
    expect(d('Check', '1'), 1);
    expect(d('Int', '5'), 5);
    expect(d('Int', '-3'), -3);
    // parseInt semantics: leading integer, else 0.
    expect(d('Int', '1.9'), 1);
    expect(d('Int', 'abc'), 0);
  });

  test('Float and Currency defaults become numbers (flt)', () {
    expect(d('Float', '2.5'), 2.5);
    expect(d('Currency', '100'), 100);
    expect(d('Currency', '1,250.75'), 1250.75);
    expect(d('Float', 'x'), 0);
  });

  test('an empty or missing default stays unset, as in Desk', () {
    // Desk assigns only when the default string is truthy (`if (v)`).
    expect(d('Check', null), isNull);
    expect(d('Check', ''), isNull);
    expect(d('Int', ''), isNull);
    expect(d('Float', ''), isNull);
  });

  test('other field types keep the default text unchanged', () {
    expect(d('Data', '0'), '0');
    expect(d('Select', 'A'), 'A');
    // Desk does not cast Percent in set_default_values.
    expect(d('Percent', '10'), '10');
    expect(d('Data', null), isNull);
  });
}
