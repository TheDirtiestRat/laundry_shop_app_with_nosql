import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laundry_shop_app_with_nosql/data/couchdb_client.dart';

void main() {
  group('CouchDbConfig', () {
    test('requires HTTPS for non-local servers', () {
      expect(
        () => CouchDbConfig.validateEndpoint(
          baseUrl: 'http://couchdb.example.com',
          database: 'laundry_db',
        ),
        throwsA(isA<CouchDbException>()),
      );
      expect(
        () => CouchDbConfig.validateEndpoint(
          baseUrl: 'https://couchdb.example.com',
          database: 'laundry_db',
        ),
        returnsNormally,
      );
      expect(
        () => CouchDbConfig.validateEndpoint(
          baseUrl: 'http://localhost:5984',
          database: 'laundry_db',
        ),
        returnsNormally,
      );
    });

    test('rejects credentials embedded in the base URL', () {
      expect(
        () => CouchDbConfig.validateEndpoint(
          baseUrl: 'http://user:password@localhost:5984',
          database: 'laundry_db',
        ),
        throwsA(isA<CouchDbException>()),
      );
    });
  });

  test('reads database information with configured Basic auth', () async {
    late http.Request capturedRequest;
    final client = CouchDbClient(
      _config,
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'db_name': 'laundry_db',
            'doc_count': 3,
            'update_seq': '4-g1AAA',
          }),
          200,
        );
      }),
    );

    final info = await client.getDatabaseInfo();

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/laundry_db');
    expect(
      capturedRequest.headers['authorization'],
      'Basic ${base64Encode(utf8.encode('laundry-user:secret'))}',
    );
    expect(info.name, 'laundry_db');
    expect(info.documentCount, 3);
    client.close();
  });

  test(
    'CRUD smoke test preserves fields and deletes with latest revision',
    () async {
      Map<String, dynamic>? storedDocument;
      final methods = <String>[];
      final client = CouchDbClient(
        _config,
        httpClient: MockClient((request) async {
          methods.add(request.method);
          final id = request.url.pathSegments.last;
          if (request.method == 'PUT' && !request.body.contains('"_rev"')) {
            storedDocument = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map<String, dynamic>,
            )..['_rev'] = '1-created';
            storedDocument!['kept'] = 'original';
            return _jsonResponse({'ok': true, 'id': id, 'rev': '1-created'});
          }
          if (request.method == 'GET') {
            return _jsonResponse(storedDocument!);
          }
          if (request.method == 'PUT') {
            final updated = jsonDecode(request.body) as Map<String, dynamic>;
            expect(updated['_rev'], '1-created');
            expect(updated['kept'], 'original');
            expect(updated['step'], 'updated');
            storedDocument = {...updated, '_rev': '2-updated'};
            return _jsonResponse({'ok': true, 'id': id, 'rev': '2-updated'});
          }
          if (request.method == 'DELETE') {
            expect(request.url.queryParameters['rev'], '2-updated');
            storedDocument = null;
            return _jsonResponse({'ok': true, 'id': id, 'rev': '3-deleted'});
          }
          return http.Response('Unexpected request', 500);
        }),
      );

      await client.runCrudSmokeTest();

      expect(methods, ['PUT', 'GET', 'GET', 'PUT', 'GET', 'GET', 'DELETE']);
      expect(storedDocument, isNull);
      client.close();
    },
  );

  test('turns unauthorized responses into a useful CouchDB error', () async {
    final client = CouchDbClient(
      _config,
      httpClient: MockClient(
        (_) async => _jsonResponse({
          'error': 'unauthorized',
          'reason': 'Name or password is incorrect.',
        }, 401),
      ),
    );

    await expectLater(
      client.getDatabaseInfo(),
      throwsA(
        isA<CouchDbException>().having(
          (error) => error.message,
          'message',
          contains('authentication failed'),
        ),
      ),
    );
    client.close();
  });
}

const _config = CouchDbConfig(
  baseUrl: 'http://localhost:5984',
  database: 'laundry_db',
  username: 'laundry-user',
  password: 'secret',
);

http.Response _jsonResponse(Map<String, dynamic> body, [int statusCode = 200]) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
