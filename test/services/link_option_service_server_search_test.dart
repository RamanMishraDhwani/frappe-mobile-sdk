import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/src/api/client.dart';
import 'package:frappe_mobile_sdk/src/database/daos/doctype_meta_dao.dart';
import 'package:frappe_mobile_sdk/src/models/doc_field.dart';
import 'package:frappe_mobile_sdk/src/models/doc_type_meta.dart';
import 'package:frappe_mobile_sdk/src/models/link_search_policy.dart';
import 'package:frappe_mobile_sdk/src/models/offline_mode.dart';
import 'package:frappe_mobile_sdk/src/query/unified_resolver.dart';
import 'package:frappe_mobile_sdk/src/services/link_option_service.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Answers every get_list with [rows] and records what reached the server.
class _Server extends http.BaseClient {
  _Server(this.rows);
  final List<Map<String, Object?>> rows;
  final List<Uri> seen = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request.url);
    return http.StreamedResponse(
      Stream.fromIterable([
        utf8.encode(jsonEncode({'message': rows})),
      ]),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

DocTypeMeta _codeMeta(String name) => DocTypeMeta(
  name: name,
  titleField: 'product_code',
  searchFields: const ['product_code', 'brand_name', 'category_name', 'ghost_field'],
  fields: [
    DocField(fieldname: 'product_code', fieldtype: 'Data'),
    DocField(fieldname: 'brand_name', fieldtype: 'Link'),
    DocField(fieldname: 'category_name', fieldtype: 'Data'),
    DocField(fieldname: 'is_active', fieldtype: 'Check'),
  ],
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late _Server server;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    server = _Server([
      {'name': '9009', 'product_code': 'XACM0WIDGIT'},
      {'name': '4205', 'product_code': 'ACME0WIDGET'},
    ]);
  });

  tearDown(() async => db.close());

  LinkOptionService service({
    bool offline = false,
    bool withClient = true,
    LinkSearchPolicy policy = const LinkSearchPolicy(),
  }) {
    final resolver = UnifiedResolver(
      db: db,
      metaDao: DoctypeMetaDao(db),
      isOnline: () => true,
      backgroundFetch: (_, _) async {},
      metaResolver: (n) async => _codeMeta(n),
      offlineMode: OfflineMode(enabled: offline, isPersisted: true),
      client: withClient
          ? FrappeClient('http://localhost', httpClient: server)
          : null,
    );
    return LinkOptionService(
      resolver,
      (n) async => _codeMeta(n),
      searchPolicy: policy,
    );
  }

  group('usesServerSearch', () {
    test('online-first with a client and the default policy: true', () {
      expect(service().usesServerSearch('Product Code'), isTrue);
    });

    test('offline-first: false, the local list is kept', () {
      expect(service(offline: true).usesServerSearch('Product Code'), isFalse);
    });

    test('policy disabled: false', () {
      expect(
        service(
          policy: LinkSearchPolicy.disabled,
        ).usesServerSearch('Product Code'),
        isFalse,
      );
    });

    test('doctype opted out: false for it, true for others', () {
      final svc = service(
        policy: const LinkSearchPolicy(prefetchOnlyDoctypes: {'Product Code'}),
      );
      expect(svc.usesServerSearch('Product Code'), isFalse);
      expect(svc.usesServerSearch('Regions'), isTrue);
    });

    test('withoutResolver (subclass that overrides getLinkOptions): false', () {
      expect(
        LinkOptionService.withoutResolver().usesServerSearch('Product Code'),
        isFalse,
      );
    });
  });

  group('searchLinkOptions', () {
    test('matches the text across name, title and real search fields, ANDed '
        'with the link filters, one page', () async {
      await service().searchLinkOptions(
        'Product Code',
        txt: 'ACME0WID',
        pageLength: 20,
        filters: [
          ['Product Code', 'is_active', '=', 1],
        ],
      );
      expect(server.seen, hasLength(1));
      final q = server.seen.single.queryParameters;
      expect(q['doctype'], 'Product Code');
      expect(q['limit_page_length'], '20');
      expect(jsonDecode(q['filters']!), [
        ['is_active', '=', 1],
      ]);
      // ghost_field is not a field of the doctype: sending it would make
      // Frappe refuse the whole query (417).
      expect(jsonDecode(q['or_filters']!), [
        ['name', 'like', '%ACME0WID%'],
        ['product_code', 'like', '%ACME0WID%'],
        ['brand_name', 'like', '%ACME0WID%'],
        ['category_name', 'like', '%ACME0WID%'],
      ]);
    });

    test('empty text is the first page: no or_filters', () async {
      await service().searchLinkOptions('Product Code', txt: '', pageLength: 10);
      final q = server.seen.single.queryParameters;
      expect(q['limit_page_length'], '10');
      expect(q.containsKey('or_filters'), isFalse);
    });

    test('labels come from the title field, as getLinkOptions builds them; '
        'docnames starting with the text come first', () async {
      server = _Server([
        {'name': '9009', 'product_code': 'X420'},
        {'name': '4205', 'product_code': 'ACME0WIDGET'},
      ]);
      final out = await service().searchLinkOptions(
        'Product Code',
        txt: '420',
        pageLength: 20,
      );
      expect(out.map((o) => o.name), ['4205', '9009']);
      expect(out.first.label, 'ACME0WIDGET');
    });
  });

  test('searchColumnsFor keeps name, then real searchable fields once', () {
    expect(LinkOptionService.searchColumnsFor(_codeMeta('Product Code')), [
      'name',
      'product_code',
      'brand_name',
      'category_name',
    ]);
  });
}
