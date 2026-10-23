import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/frappe_mobile_sdk.dart';
import 'package:frappe_mobile_sdk/src/ui/widgets/fields/searchable_select.dart';

LinkOptionEntity _opt(String name, [String? label]) => LinkOptionEntity(
  doctype: 'Product Code',
  name: name,
  label: label ?? name,
  lastUpdated: 0,
);

/// Ten first-page options; the wanted row is not among them.
final List<LinkOptionEntity> _page = [
  for (var i = 0; i < 10; i++) _opt('$i', 'SBIN000000$i'),
];

class _Search {
  final List<String> calls = [];
  final Map<String, Completer<List<LinkOptionEntity>>> pending = {};
  Future<List<LinkOptionEntity>> call(String text) {
    calls.add(text);
    return (pending[text] = Completer<List<LinkOptionEntity>>()).future;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _Search search,
  List<LinkOptionEntity>? options,
  bool complete = false,
  List<String> picked = const [],
  void Function(List<String>)? onChanged,
  void Function(LinkOptionEntity)? onPickOption,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SearchableSelect(
        options: options ?? _page,
        selected: picked,
        onChanged: onChanged ?? (_) {},
        onSearch: search.call,
        searchDebounce: const Duration(milliseconds: 500),
        searchMinChars: 2,
        optionsComplete: complete,
        onPickOption: onPickOption,
      ),
    ),
  ),
);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  testWidgets('one request after the pause, not one per keystroke', (
    tester,
  ) async {
    final search = _Search();
    await _pump(tester, search: search);
    for (final t in ['BA', 'BAR', 'ACME', 'ACME0', 'ACME0W']) {
      await _type(tester, t);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(search.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(search.calls, ['ACME0W']);
    expect(find.text('Searching...'), findsOneWidget);
    search.pending['ACME0W']!.complete([_opt('4205', 'ACME0WIDGET')]);
    await tester.pump();
    expect(find.text('ACME0WIDGET'), findsOneWidget);
    expect(find.text('No matching options'), findsNothing);
  });

  testWidgets('below minChars: no request', (tester) async {
    final search = _Search();
    await _pump(tester, search: search);
    await _type(tester, 'B');
    await tester.pump(const Duration(seconds: 1));
    expect(search.calls, isEmpty);
  });

  testWidgets('an exact match on the first page: no request', (tester) async {
    final search = _Search();
    await _pump(tester, search: search);
    await _type(tester, 'sbin0000003');
    await tester.pump(const Duration(seconds: 1));
    expect(search.calls, isEmpty);
    expect(find.text('SBIN0000003'), findsOneWidget);
  });

  testWidgets('a complete first page: no request, and the old empty state', (
    tester,
  ) async {
    final search = _Search();
    await _pump(tester, search: search, complete: true);
    await _type(tester, 'ACME0WIDGET');
    await tester.pump(const Duration(seconds: 1));
    expect(search.calls, isEmpty);
    expect(find.text('No matching options'), findsOneWidget);
  });

  testWidgets('a partial match on a truncated page still searches, and the '
      'local rows show meanwhile', (tester) async {
    final search = _Search();
    await _pump(tester, search: search);
    await _type(tester, 'SBIN');
    expect(find.text('SBIN0000001'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(search.calls, ['SBIN']);
    search.pending['SBIN']!.complete([_opt('77', 'SBIN0099999')]);
    await tester.pump();
    expect(find.text('SBIN0099999'), findsOneWidget);
    expect(find.text('SBIN0000001'), findsNothing);
  });

  testWidgets('a slow reply to an older text never replaces a newer one', (
    tester,
  ) async {
    final search = _Search();
    await _pump(tester, search: search);
    await _type(tester, 'ACME');
    await tester.pump(const Duration(milliseconds: 500));
    await _type(tester, 'ACME0WID');
    await tester.pump(const Duration(milliseconds: 500));
    expect(search.calls, ['ACME', 'ACME0WID']);
    search.pending['ACME0WID']!.complete([_opt('4205', 'ACME0WIDGET')]);
    await tester.pump();
    search.pending['ACME']!.complete([_opt('2', 'ACME0OLDROW')]);
    await tester.pump();
    expect(find.text('ACME0WIDGET'), findsOneWidget);
    expect(find.text('ACME0OLDROW'), findsNothing);
  });

  testWidgets('a failed search says so and keeps the text; retry searches', (
    tester,
  ) async {
    final search = _Search();
    await _pump(tester, search: search);
    await _type(tester, 'ACME0WID');
    await tester.pump(const Duration(milliseconds: 500));
    search.pending['ACME0WID']!.completeError(Exception('offline'));
    await tester.pump();
    expect(find.text('Search failed. Tap to retry'), findsOneWidget);
    expect(find.text('No matching options'), findsNothing);
    expect(find.text('ACME0WID'), findsOneWidget); // the typed text
    await tester.tap(find.text('Search failed. Tap to retry'));
    await tester.pump();
    expect(search.calls, ['ACME0WID', 'ACME0WID']);
  });

  testWidgets('picking a searched row reports the option, then its name', (
    tester,
  ) async {
    final search = _Search();
    final events = <String>[];
    await _pump(
      tester,
      search: search,
      onPickOption: (o) => events.add('option:${o.name}'),
      onChanged: (v) => events.add('changed:${v.join()}'),
    );
    await _type(tester, 'ACME0WID');
    await tester.pump(const Duration(milliseconds: 500));
    search.pending['ACME0WID']!.complete([_opt('4205', 'ACME0WIDGET')]);
    await tester.pump();
    await tester.tap(find.text('ACME0WIDGET'));
    await tester.pump();
    expect(events, ['option:4205', 'changed:4205']);
  });

  testWidgets('no onSearch: behaves as before (in-memory only)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableSelect(
            options: _page,
            selected: const [],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await _type(tester, 'ACME0WIDGET');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No matching options'), findsOneWidget);
    expect(find.text('Searching...'), findsNothing);
  });
}
