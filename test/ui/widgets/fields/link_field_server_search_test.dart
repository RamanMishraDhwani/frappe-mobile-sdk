import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/frappe_mobile_sdk.dart';

LinkOptionEntity _opt(String name, String label) => LinkOptionEntity(
  doctype: 'Product Code',
  name: name,
  label: label,
  lastUpdated: 0,
);

/// A service in server-search mode that records every call.
class _ServerSearchService extends LinkOptionService {
  _ServerSearchService({required this.firstPage, this.results = const []})
    : super.withoutResolver();

  final List<LinkOptionEntity> firstPage;
  final List<LinkOptionEntity> results;
  final List<String> searches = [];
  final List<int> pageLengths = [];
  int prefetches = 0;
  final Map<String, String> titles = {};

  @override
  LinkSearchPolicy get searchPolicy =>
      const LinkSearchPolicy(debounce: Duration(milliseconds: 100));

  @override
  bool usesServerSearch(String doctype) => true;

  @override
  Future<List<LinkOptionEntity>> getLinkOptions(
    String doctype, {
    List<List<dynamic>>? filters,
  }) async {
    prefetches++;
    return const [];
  }

  @override
  Future<List<LinkOptionEntity>> searchLinkOptions(
    String doctype, {
    required String txt,
    required int pageLength,
    List<List<dynamic>>? filters,
  }) async {
    searches.add(txt);
    pageLengths.add(pageLength);
    return txt.isEmpty ? firstPage : results;
  }

  @override
  Future<String?> getLinkTitle(String doctype, String name) async =>
      titles[name];
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: FormBuilder(child: child)),
);

DocField _field() => DocField(
  fieldname: 'product_code',
  fieldtype: 'Link',
  label: 'Code',
  options: 'Product Code',
);

final List<LinkOptionEntity> _tenRows = [
  for (var i = 0; i < 10; i++) _opt('$i', 'SBIN000000$i'),
];

void main() {
  testWidgets('loads a 10-row first page via searchLinkOptions, never the '
      'full prefetch', (tester) async {
    final svc = _ServerSearchService(firstPage: _tenRows);
    await tester.pumpWidget(
      _wrap(LinkField(field: _field(), linkOptionService: svc)),
    );
    await tester.pumpAndSettle();
    expect(svc.searches, ['']);
    expect(svc.pageLengths, [10]);
    expect(svc.prefetches, 0);
  });

  testWidgets('typing past the first page finds the row and picks it', (
    tester,
  ) async {
    final svc = _ServerSearchService(
      firstPage: _tenRows,
      results: [_opt('4205', 'ACME0WIDGET')],
    );
    final picked = <dynamic>[];
    await tester.pumpWidget(
      _wrap(
        LinkField(
          field: _field(),
          linkOptionService: svc,
          onChanged: picked.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    // A prefix, so the only "ACME0WIDGET" on screen is the result row.
    await tester.enterText(find.byType(TextField), 'ACME0WID');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(svc.searches, ['', 'ACME0WID']);
    expect(svc.pageLengths.last, 20);
    await tester.tap(find.text('ACME0WIDGET'));
    await tester.pumpAndSettle();
    expect(picked, ['4205']);
    // The picked row is not on the first page; its label must still show.
    expect(find.text('ACME0WIDGET'), findsOneWidget);
    expect(find.text('4205'), findsNothing);
  });

  testWidgets('an empty first page still offers a search box', (tester) async {
    final svc = _ServerSearchService(firstPage: const []);
    await tester.pumpWidget(
      _wrap(LinkField(field: _field(), linkOptionService: svc)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No options available'), findsNothing);
  });

  testWidgets('a single-row first page (complete) still auto-selects', (
    tester,
  ) async {
    final svc = _ServerSearchService(firstPage: [_opt('PC-1', 'Only Centre')]);
    final picked = <dynamic>[];
    await tester.pumpWidget(
      _wrap(
        LinkField(
          field: _field(),
          linkOptionService: svc,
          onChanged: picked.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(picked, ['PC-1']);
  });

  testWidgets('a single search result is not auto-selected', (tester) async {
    final svc = _ServerSearchService(
      firstPage: _tenRows,
      results: [_opt('4205', 'ACME0WIDGET')],
    );
    final picked = <dynamic>[];
    await tester.pumpWidget(
      _wrap(
        LinkField(
          field: _field(),
          linkOptionService: svc,
          onChanged: picked.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ACME0WID');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
  });

  testWidgets('a held value past the first page shows its title, not the '
      'docname', (tester) async {
    final svc = _ServerSearchService(firstPage: _tenRows)
      ..titles['4205'] = 'ACME0WIDGET';
    await tester.pumpWidget(
      _wrap(LinkField(field: _field(), value: '4205', linkOptionService: svc)),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACME0WIDGET'), findsOneWidget);
    expect(find.text('4205'), findsNothing);
  });

  testWidgets('a subclass that only overrides getLinkOptions keeps the full '
      'prefetch', (tester) async {
    final svc = _LegacyService();
    await tester.pumpWidget(
      _wrap(LinkField(field: _field(), linkOptionService: svc)),
    );
    await tester.pumpAndSettle();
    expect(svc.prefetches, 1);
  });

  testWidgets('a service that cannot answer usesServerSearch keeps the '
      'prefetch instead of leaving the picker empty', (tester) async {
    final svc = _UnansweringService();
    await tester.pumpWidget(
      _wrap(LinkField(field: _field(), linkOptionService: svc)),
    );
    await tester.pumpAndSettle();
    expect(svc.prefetches, 1);
    expect(find.byType(TextField), findsOneWidget);
  });
}

/// A host double that cannot answer the new question, like an unstubbed
/// mocktail `implements LinkOptionService` (it returns null, which throws).
class _UnansweringService extends _LegacyService {
  @override
  bool usesServerSearch(String doctype) => throw TypeError(); // what `null as bool` raises
}

class _LegacyService extends LinkOptionService {
  _LegacyService() : super.withoutResolver();
  int prefetches = 0;

  @override
  Future<List<LinkOptionEntity>> getLinkOptions(
    String doctype, {
    List<List<dynamic>>? filters,
  }) async {
    prefetches++;
    return _tenRows;
  }
}
