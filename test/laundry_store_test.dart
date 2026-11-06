import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laundry_shop_app_with_nosql/data/couchdb_client.dart';
import 'package:laundry_shop_app_with_nosql/data/laundry_store.dart';
import 'package:laundry_shop_app_with_nosql/models/laundry_models.dart';

void main() {
  late Map<String, Map<String, dynamic>> documents;
  late LaundryStore store;

  setUp(() {
    documents = {};
    store = LaundryStore(
      CouchDbClient(
        _config,
        httpClient: MockClient((request) async {
          final path = request.url.pathSegments;
          if (path.length == 1 && request.method == 'GET') {
            return _json({
              'db_name': 'laundry_db',
              'doc_count': documents.length,
              'update_seq': 1,
            });
          }
          if (path.length == 2 && path[1] == '_find') {
            final query = jsonDecode(request.body) as Map<String, dynamic>;
            final selector =
                query['selector'] as Map<String, dynamic>? ?? const {};
            final type = selector['type'];
            final matches = documents.values
                .where((document) => document['type'] == type)
                .toList();
            return _json({'docs': matches});
          }
          if (path.length == 2 && path[1] == '_index') {
            return _json({'result': 'created'});
          }
          if (path.length == 2) {
            final id = path[1];
            if (request.method == 'GET') {
              final document = documents[id];
              return document == null
                  ? _json({'error': 'not_found', 'reason': 'missing'}, 404)
                  : _json(document);
            }
            if (request.method == 'PUT') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final existing = documents[id];
              if (existing == null && body.containsKey('_rev')) {
                return _json({'error': 'conflict'}, 409);
              }
              if (existing != null && body['_rev'] != existing['_rev']) {
                return _json({'error': 'conflict'}, 409);
              }
              final revision = existing == null ? 1 : 2;
              documents[id] = {...body, '_id': id, '_rev': '$revision-test'};
              return _json({'ok': true, 'id': id, 'rev': '$revision-test'});
            }
            if (request.method == 'DELETE') {
              final document = documents[id];
              if (document == null) {
                return _json({'error': 'not_found'}, 404);
              }
              if (request.url.queryParameters['rev'] != document['_rev']) {
                return _json({'error': 'conflict'}, 409);
              }
              documents.remove(id);
              return _json({'ok': true, 'id': id, 'rev': 'deleted'});
            }
          }
          return _json({'error': 'not_found'}, 404);
        }),
      ),
    );
  });

  tearDown(() {
    store.dispose();
  });

  test('uses centavos and rounds kilogram pricing consistently', () {
    expect(
      calculateOrderTotalCentavos(weightGrams: 1250, pricePerKgCentavos: 3500),
      4375,
    );
    expect(formatMoney(4375), '₱43.75');
    expect(parseMoneyCentavos('1.2'), 120);
    expect(parseMoneyCentavos('0.01'), 1);
    expect(parseMoneyCentavos('1.001'), isNull);
    expect(parseWeightGrams('1.25'), 1250);
    expect(parseWeightGrams('0.001'), 1);
    expect(parseWeightGrams('1.0001'), isNull);
    expect(
      paymentStatus(
        LaundryOrder(
          id: 'order',
          customerId: 'customer',
          customerName: 'Customer',
          serviceId: 'service',
          serviceName: 'Wash',
          weightGrams: 1000,
          pricePerKgCentavos: 10000,
          totalAmountCentavos: 10000,
          orderDate: DateTime.utc(2026),
          expectedPickupDate: DateTime.utc(2026, 1, 2),
          status: OrderStatus.pending,
          specialInstructions: '',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        [],
      ),
      PaymentStatus.unpaid,
    );
  });

  test(
    'creates an order, records partial payments, and prevents overpayment',
    () async {
      await store.refresh();
      await store.createCustomer(
        name: 'Test Customer',
        contactNumber: '09170000000',
        email: '',
        address: '',
      );
      await store.createService(
        name: 'Wash and Fold',
        description: '',
        pricePerKgCentavos: 3500,
        completionHours: 24,
        isAvailable: true,
      );
      final customer = store.customers.single;
      final service = store.services.single;

      await store.createOrder(
        customerId: customer.id,
        serviceId: service.id,
        weightGrams: 5000,
        expectedPickupDate: DateTime.now().add(const Duration(days: 1)),
        specialInstructions: '',
      );
      final order = store.orders.single;
      expect(order.totalAmountCentavos, 17500);

      await store.createPayment(
        orderId: order.id,
        amountCentavos: 10000,
        method: PaymentMethod.cash,
        reference: '',
      );
      expect(
        remainingBalanceCentavos(store.orders.single, store.payments),
        7500,
      );
      await expectLater(
        store.createPayment(
          orderId: order.id,
          amountCentavos: 7501,
          method: PaymentMethod.gcash,
          reference: '',
        ),
        throwsA(isA<CouchDbException>()),
      );
    },
  );

  test('protects customer history, deactivates referenced services, and voids '
      'payments without deleting records', () async {
    await store.refresh();
    await store.createCustomer(
      name: 'History Customer',
      contactNumber: '09171111111',
      email: '',
      address: '',
    );
    await store.createService(
      name: 'History Service',
      description: '',
      pricePerKgCentavos: 5000,
      completionHours: 12,
      isAvailable: true,
    );
    final customerId = store.customers.single.id;
    final serviceId = store.services.single.id;
    await store.createOrder(
      customerId: customerId,
      serviceId: serviceId,
      weightGrams: 1000,
      expectedPickupDate: DateTime.now().add(const Duration(days: 1)),
      specialInstructions: '',
    );
    final order = store.orders.single;
    await expectLater(
      store.deleteCustomer(customerId),
      throwsA(isA<CouchDbException>()),
    );
    await store.deleteService(serviceId);
    expect(store.services.single.isAvailable, isFalse);

    await store.createPayment(
      orderId: order.id,
      amountCentavos: 5000,
      method: PaymentMethod.maya,
      reference: 'receipt',
    );
    final paymentId = store.payments.single.id;
    await store.voidPayment(paymentId);
    expect(store.payments.single.isVoided, isTrue);
    expect(documents.containsKey(paymentId), isTrue);
    expect(paymentsTotalCentavos(store.payments), 0);
  });
}

const _config = CouchDbConfig(
  baseUrl: 'http://localhost:5984',
  database: 'laundry_db',
  username: 'test-user',
  password: 'test-password',
);

http.Response _json(Map<String, dynamic> body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}
