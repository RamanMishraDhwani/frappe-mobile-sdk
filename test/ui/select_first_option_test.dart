import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/frappe_mobile_sdk.dart';
import 'package:frappe_mobile_sdk/src/utils/field_defaults.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// On a new document Desk gives a Select with no default its first option
/// (`frappe.model.set_default_values`). Left empty instead, fields gated on
/// that value (`eval:doc.phase=='Existing'`) stay hidden on a new form, and
/// the save sends an empty value Desk would never send.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Object? d(String? options, {String? def}) => typedDefaultValue(
    DocField(
      fieldname: 'f',
      fieldtype: 'Select',
      options: options,
      defaultValue: def,
    ),
  );

  test('a Select with no default starts on its first option', () {
    expect(d('Existing\nNew'), 'Existing');
    expect(d('Existing\nNew', def: 'New'), 'New');
  });

  test('a list that starts blank, or no options, stays empty', () {
    expect(d('\nA\nB'), isNull);
    expect(d(null), isNull);
    expect(d(''), isNull);
  });

  DocTypeMeta meta() => DocTypeMeta(
    name: 'Promotion Entry',
    fields: <DocField>[
      DocField(
        fieldname: 'phase',
        fieldtype: 'Select',
        label: 'Phase',
        options: 'Existing\nNew',
      ),
      DocField(
        fieldname: 'existing_channel',
        fieldtype: 'Data',
        label: 'Existing Channel',
        dependsOn: "eval:doc.phase=='Existing'",
      ),
    ],
  );

  for (final mode in FormBuilderMode.values) {
    testWidgets('$mode: a new form starts on the first option', (tester) async {
      Map<String, dynamic>? out;
      void Function()? submit;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrappeFormBuilder(
              meta: meta(),
              mode: mode,
              onSubmit: (d) => out = d,
              registerSubmit: (fn) => submit = fn,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Existing Channel'), findsOneWidget);
      submit!();
      await tester.pumpAndSettle();
      expect(out!['phase'], 'Existing');
    });
  }

  testWidgets('a saved document keeps its own value', (tester) async {
    Map<String, dynamic>? out;
    void Function()? submit;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FrappeFormBuilder(
            meta: meta(),
            initialData: const {'name': 'PE-1', 'phase': 'New'},
            onSubmit: (d) => out = d,
            registerSubmit: (fn) => submit = fn,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    submit!();
    await tester.pumpAndSettle();
    expect(out!['phase'], 'New');
  });
}
