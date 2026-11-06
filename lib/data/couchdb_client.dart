import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class CouchDbConfig {
  const CouchDbConfig({
    required this.baseUrl,
    required this.database,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String database;
  final String username;
  final String password;

  Uri get _baseUri => _parseBaseUrl(baseUrl);

  static Uri _parseBaseUrl(String baseUrl) {
    final value = baseUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const CouchDbException(
        'Enter a valid CouchDB base URL using http:// or https://. '
        'Do not put credentials in the URL.',
      );
    }

    if (uri.scheme != 'https' && !_isLoopback(uri.host)) {
      throw const CouchDbException(
        'Use HTTPS for non-local CouchDB servers. HTTP is allowed only '
        'for localhost or a loopback address.',
      );
    }

    return uri;
  }

  static void validateEndpoint({
    required String baseUrl,
    required String database,
  }) {
    final uri = _parseBaseUrl(baseUrl);
    if (!RegExp(r'^[a-z][a-z0-9_$()+-]*$').hasMatch(database.trim())) {
      throw const CouchDbException(
        'Database names must start with a lowercase letter and contain only '
        'lowercase letters, digits, or _ \$ ( ) + - characters.',
      );
    }
    if (uri.host.isEmpty) {
      throw const CouchDbException('Enter a CouchDB base URL.');
    }
  }

  void validate() {
    validateEndpoint(baseUrl: baseUrl, database: database);
    if (username.trim().isEmpty ||
        username.contains(':') ||
        username.contains('\r') ||
        username.contains('\n') ||
        password.isEmpty ||
        password.contains('\r') ||
        password.contains('\n')) {
      throw const CouchDbException(
        'Enter valid credentials for a restricted CouchDB user. The username '
        'cannot contain a colon or line break.',
      );
    }
  }

  Uri uriFor(List<String> segments) {
    validate();
    final base = _baseUri;
    final pathSegments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      database.trim(),
      ...segments,
    ];
    return base.replace(pathSegments: pathSegments);
  }

  Map<String, String> get headers {
    validate();
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return {
      'accept': 'application/json',
      'content-type': 'application/json',
      'authorization': 'Basic $credentials',
    };
  }

  static bool _isLoopback(String host) {
    final normalizedHost = host.toLowerCase();
    if (normalizedHost == 'localhost' || normalizedHost == '::1') {
      return true;
    }
    final address = InternetAddress.tryParse(normalizedHost);
    return address != null && address.isLoopback;
  }
}

class CouchDbException implements Exception {
  const CouchDbException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

@immutable
class CouchDbDatabaseInfo {
  const CouchDbDatabaseInfo({
    required this.name,
    required this.documentCount,
    required this.updateSequence,
  });

  final String name;
  final int documentCount;
  final Object? updateSequence;

  factory CouchDbDatabaseInfo.fromJson(Map<String, dynamic> json) {
    final name = json['db_name'];
    final documentCount = json['doc_count'];
    if (name is! String || documentCount is! int) {
      throw const CouchDbException(
        'CouchDB returned database information in an unexpected format.',
      );
    }
    return CouchDbDatabaseInfo(
      name: name,
      documentCount: documentCount,
      updateSequence: json['update_seq'],
    );
  }
}

class CouchDbClient {
  CouchDbClient(
    this.config, {
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 12),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null {
    config.validate();
  }

  final CouchDbConfig config;
  final Duration timeout;
  final http.Client _httpClient;
  final bool _ownsClient;

  Future<CouchDbDatabaseInfo> getDatabaseInfo() async {
    final response = await _request(
      () => _httpClient.get(config.uriFor(const []), headers: config.headers),
    );
    return CouchDbDatabaseInfo.fromJson(_decodeObject(response));
  }

  Future<Map<String, dynamic>> getDocument(String id) async {
    final response = await _request(
      () => _httpClient.get(config.uriFor([id]), headers: config.headers),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> createDocument(
    String id,
    Map<String, dynamic> document,
  ) async {
    if (document.containsKey('_rev')) {
      throw const CouchDbException(
        'A new document must not include a CouchDB revision.',
      );
    }
    if (document['_id'] != null && document['_id'] != id) {
      throw const CouchDbException(
        'The document ID does not match the requested ID.',
      );
    }
    final payload = Map<String, dynamic>.from(document)..['_id'] = id;
    final response = await _request(
      () => _httpClient.put(
        config.uriFor([id]),
        headers: config.headers,
        body: jsonEncode(payload),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> updateDocument(
    String id,
    Map<String, dynamic> changes,
  ) async {
    if (changes.containsKey('_id') || changes.containsKey('_rev')) {
      throw const CouchDbException(
        'Do not include _id or _rev in document changes; CouchDB manages them.',
      );
    }
    final currentDocument = await getDocument(id);
    final revision = currentDocument['_rev'];
    if (revision is! String) {
      throw const CouchDbException(
        'CouchDB document is missing its revision; it cannot be updated safely.',
      );
    }
    final updatedDocument = Map<String, dynamic>.from(currentDocument)
      ..addAll(changes);
    final response = await _request(
      () => _httpClient.put(
        config.uriFor([id]),
        headers: config.headers,
        body: jsonEncode(updatedDocument),
      ),
    );
    return _decodeObject(response);
  }

  Future<void> deleteDocument(String id) async {
    final document = await getDocument(id);
    final revision = document['_rev'];
    if (revision is! String) {
      throw const CouchDbException(
        'CouchDB document is missing its revision; it cannot be deleted safely.',
      );
    }
    final response = await _request(
      () => _httpClient.delete(
        config.uriFor([id]).replace(queryParameters: {'rev': revision}),
        headers: config.headers,
      ),
    );
    _decodeObject(response);
  }

  Future<Map<String, dynamic>> findDocuments(Map<String, dynamic> query) async {
    final response = await _request(
      () => _httpClient.post(
        config.uriFor(const ['_find']),
        headers: config.headers,
        body: jsonEncode(query),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> createIndex(
    Map<String, dynamic> definition,
  ) async {
    final response = await _request(
      () => _httpClient.post(
        config.uriFor(const ['_index']),
        headers: config.headers,
        body: jsonEncode(definition),
      ),
    );
    return _decodeObject(response);
  }

  Future<void> runCrudSmokeTest() async {
    final marker =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(1 << 32)}';
    final id = 'connection-test-$marker';
    var created = false;
    var deleted = false;

    try {
      await createDocument(id, {
        'type': 'connection_test',
        'test_marker': marker,
        'step': 'created',
      });
      created = true;

      final initial = await getDocument(id);
      if (initial['_id'] != id ||
          initial['type'] != 'connection_test' ||
          initial['test_marker'] != marker) {
        throw const CouchDbException(
          'The temporary test document could not be verified after creation.',
        );
      }

      await updateDocument(id, {'step': 'updated'});
      final updated = await getDocument(id);
      if (updated['step'] != 'updated' || updated['test_marker'] != marker) {
        throw const CouchDbException(
          'The temporary test document could not be verified after update.',
        );
      }

      await deleteDocument(id);
      deleted = true;
    } catch (error) {
      if (created && !deleted) {
        try {
          final leftover = await getDocument(id);
          if (leftover['type'] == 'connection_test' &&
              leftover['test_marker'] == marker) {
            await deleteDocument(id);
          }
        } on CouchDbException catch (cleanupError) {
          throw CouchDbException(
            '$error The temporary test document could not be cleaned up: '
            '${cleanupError.message}',
            statusCode: cleanupError.statusCode,
          );
        }
      }
      rethrow;
    }
  }

  Future<http.Response> _request(Future<http.Response> Function() send) async {
    late final http.Response response;
    try {
      response = await send().timeout(timeout);
    } on TimeoutException {
      throw const CouchDbException(
        'The CouchDB request timed out. Check the server address and network.',
      );
    } on SocketException {
      throw const CouchDbException(
        'Could not reach CouchDB. Check that the server is running and '
        'the base URL is correct.',
      );
    } on http.ClientException catch (error) {
      throw CouchDbException('Could not communicate with CouchDB: $error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
    return response;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw const CouchDbException('CouchDB returned invalid JSON.');
    }
    throw const CouchDbException(
      'CouchDB returned an unexpected response format.',
    );
  }

  CouchDbException _httpError(http.Response response) {
    String? error;
    String? reason;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final responseError = decoded['error'];
        final responseReason = decoded['reason'];
        if (responseError is String) error = responseError;
        if (responseReason is String) reason = responseReason;
      }
    } on FormatException {
      // The status code still provides a useful error when the body is not JSON.
    }

    final message = switch (response.statusCode) {
      400 => 'CouchDB rejected the request (400). ${reason ?? ''}'.trim(),
      401 =>
        'CouchDB authentication failed (401). Check the restricted '
            'user credentials.',
      403 =>
        'CouchDB denied access (403). Check the user’s database '
            'permissions.',
      404 =>
        'The CouchDB database or document was not found (404). '
            'Create the database in CouchDB before connecting.',
      409 =>
        'CouchDB reported a revision conflict (409). Fetch the latest '
            'document revision and retry.',
      >= 500 =>
        'CouchDB server error (${response.statusCode}). '
                '${reason ?? ''}'
            .trim(),
      _ =>
        'CouchDB request failed (${response.statusCode}). '
                '${reason ?? error ?? ''}'
            .trim(),
    };
    return CouchDbException(message, statusCode: response.statusCode);
  }

  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}
