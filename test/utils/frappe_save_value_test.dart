import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/frappe_mobile_sdk.dart';
import 'package:frappe_mobile_sdk/src/utils/frappe_save_value.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Float, Currency and Percent fields with a precision are rounded to it, as
/// Desk's `ControlFloat.parse` does (`flt(value, precision)`); the server
/// stores what it receives without rounding.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Frappe rounding with an explicit precision', () {
    expect(frappeRound(12.3456, 2), 12.35);
    expect(frappeRound(0.15, 1), 0.2);
    expect(frappeRound(33.3333, 2), 33.33);
    expect(frappeRound(-2.345, 2), -2.35);
    expect(frappeRound(2.5, 0), 3);
  });

  test('only numbers in fields with a precision are rounded', () {
    DocField f(String type, int? p) =>
        DocField(fieldname: 'x', fieldtype: type, precision: p);
    expect(frappeSaveValue(f('Currency', 2), 12.3456), 12.35);
    expect(frappeSaveValue(f('Percent', 2), 33.3333), 33.33);
    expect(frappeSaveValue(f('Float', null), 12.3456), 12.3456);
    expect(frappeSaveValue(f('Int', 2), 7), 7);
    expect(frappeSaveValue(f('Data', 2), 'x'), 'x');
  });

  for (final mode in FormBuilderMode.values) {
    testWidgets('$mode: the save carries the rounded amount', (tester) async {
      Map<String, dynamic>? out;
      void Function()? submit;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrappeFormBuilder(
              meta: DocTypeMeta(
                name: 'Price Entry',
                fields: [
                  DocField(
                    fieldname: 'price',
                    fieldtype: 'Currency',
                    label: 'Price',
                    precision: 2,
                  ),
                ],
              ),
              mode: mode,
              initialData: const {'price': 12.3456},
              onSubmit: (d) => out = d,
              registerSubmit: (fn) => submit = fn,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      submit!();
      await tester.pumpAndSettle();
      expect(out!['price'], 12.35);
    });
  }
}
