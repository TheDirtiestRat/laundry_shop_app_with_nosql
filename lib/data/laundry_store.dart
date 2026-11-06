import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/laundry_models.dart';
import 'couchdb_client.dart';

class LaundryStore extends ChangeNotifier {
  LaundryStore(this.client);

  final CouchDbClient client;

  List<Customer> customers = const [];
  List<LaundryService> services = const [];
  List<LaundryOrder> orders = const [];
  List<LaundryPayment> payments = const [];
  bool isLoading = false;
  String? lastError;
  bool _disposed = false;
  Future<void>? _indexSetup;

  bool get isConnected => true;

  Future<void> refresh() async {
    isLoading = true;
    lastError = null;
    _notify();
    try {
      await _ensureIndexes();
      final results = await Future.wait([
        _findType('customer'),
        _findType('service'),
        _findType('order'),
        _findType('payment'),
      ]);
      customers = results[0].map(Customer.fromJson).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      services = results[1].map(LaundryService.fromJson).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      orders = results[2].map(LaundryOrder.fromJson).toList()
        ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
      payments = results[3].map(LaundryPayment.fromJson).toList()
        ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    } catch (error, stackTrace) {
      lastError = error is CouchDbException
          ? error.message
          : 'Could not load valid laundry documents: $error';
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> _ensureIndexes() async {
    final pending = _indexSetup ??= _createIndexes();
    try {
      await pending;
    } catch (error, stackTrace) {
      if (identical(_indexSetup, pending)) _indexSetup = null;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _createIndexes() async {
    const indexes = <(String, List<String>)>[
      ('laundry-type', ['type']),
      ('laundry-type-order', ['type', 'order_id']),
      ('laundry-type-customer', ['type', 'customer_id']),
      ('laundry-type-service', ['type', 'service_id']),
      ('laundry-type-status', ['type', 'order_status']),
    ];
    for (final (name, fields) in indexes) {
      await client.createIndex({
        'index': {'fields': fields},
        'name': name,
        'type': 'json',
      });
    }
  }

  Future<List<Map<String, dynamic>>> _findType(String type) async {
    const pageSize = 500;
    final documents = <Map<String, dynamic>>[];
    var skip = 0;
    while (true) {
      final result = await client.findDocuments({
        'selector': {'type': type},
        'limit': pageSize,
        'skip': skip,
      });
      final rows = result['docs'];
      if (rows is! List) {
        throw CouchDbException(
          'CouchDB returned an invalid list for $type documents.',
        );
      }
      final page = rows.whereType<Map<String, dynamic>>().toList();
      documents.addAll(page);
      if (page.length < pageSize) return documents;
      skip += page.length;
    }
  }

  Future<void> createCustomer({
    required String name,
    required String contactNumber,
    required String email,
    required String address,
  }) async {
    final trimmedName = name.trim();
    final trimmedContact = contactNumber.trim();
    if (trimmedName.isEmpty || trimmedContact.isEmpty) {
      throw const CouchDbException('Name and contact number are required.');
    }
    if (customers.any(
      (customer) =>
          customer.contactNumber.toLowerCase() == trimmedContact.toLowerCase(),
    )) {
      throw const CouchDbException(
        'A customer with this contact number already exists.',
      );
    }
    if (email.trim().isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      throw const CouchDbException('Enter a valid email address.');
    }
    final now = DateTime.now();
    final customer = Customer(
      id: _newId('customer'),
      name: trimmedName,
      contactNumber: trimmedContact,
      email: email.trim(),
      address: address.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await client.createDocument(customer.id, customer.toDocument());
    await refresh();
  }

  Future<void> updateCustomer(
    String id, {
    required String name,
    required String contactNumber,
    required String email,
    required String address,
  }) async {
    if (name.trim().isEmpty || contactNumber.trim().isEmpty) {
      throw const CouchDbException('Name and contact number are required.');
    }
    if (customers.any(
      (customer) =>
          customer.id != id &&
          customer.contactNumber.toLowerCase() ==
              contactNumber.trim().toLowerCase(),
    )) {
      throw const CouchDbException(
        'A customer with this contact number already exists.',
      );
    }
    if (email.trim().isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      throw const CouchDbException('Enter a valid email address.');
    }
    await client.updateDocument(id, {
      'full_name': name.trim(),
      'contact_number': contactNumber.trim(),
      'email': email.trim(),
      'address': address.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await refresh();
  }

  Future<void> deleteCustomer(String id) async {
    if (orders.any((order) => order.customerId == id)) {
      throw const CouchDbException(
        'This customer has order history and cannot be deleted. Keep the '
        'record so transaction history remains accurate.',
      );
    }
    await client.deleteDocument(id);
    await refresh();
  }

  Future<void> createService({
    required String name,
    required String description,
    required int pricePerKgCentavos,
    required int completionHours,
    required bool isAvailable,
  }) async {
    if (name.trim().isEmpty ||
        pricePerKgCentavos <= 0 ||
        completionHours <= 0) {
      throw const CouchDbException(
        'Enter a service name, positive price, and positive completion time.',
      );
    }
    if (services.any(
      (service) => service.name.toLowerCase() == name.trim().toLowerCase(),
    )) {
      throw const CouchDbException('A service with this name already exists.');
    }
    final now = DateTime.now();
    final service = LaundryService(
      id: _newId('service'),
      name: name.trim(),
      description: description.trim(),
      pricePerKgCentavos: pricePerKgCentavos,
      estimatedCompletionHours: completionHours,
      isAvailable: isAvailable,
      createdAt: now,
      updatedAt: now,
    );
    await client.createDocument(service.id, service.toDocument());
    await refresh();
  }

  Future<void> updateService(
    String id, {
    required String name,
    required String description,
    required int pricePerKgCentavos,
    required int completionHours,
    required bool isAvailable,
  }) async {
    if (name.trim().isEmpty ||
        pricePerKgCentavos <= 0 ||
        completionHours <= 0) {
      throw const CouchDbException(
        'Enter a service name, positive price, and positive completion time.',
      );
    }
    if (services.any(
      (service) =>
          service.id != id &&
          service.name.toLowerCase() == name.trim().toLowerCase(),
    )) {
      throw const CouchDbException('A service with this name already exists.');
    }
    await client.updateDocument(id, {
      'service_name': name.trim(),
      'description': description.trim(),
      'price_per_kg_centavos': pricePerKgCentavos,
      'estimated_completion_hours': completionHours,
      'is_available': isAvailable,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await refresh();
  }

  Future<void> deleteService(String id) async {
    if (orders.any((order) => order.serviceId == id)) {
      await client.updateDocument(id, {
        'is_available': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await client.deleteDocument(id);
    }
    await refresh();
  }

  Future<void> createOrder({
    required String customerId,
    required String serviceId,
    required int weightGrams,
    required DateTime expectedPickupDate,
    required String specialInstructions,
  }) async {
    final customer = _customerById(customerId);
    final service = _serviceById(serviceId);
    if (!service.isAvailable) {
      throw const CouchDbException('The selected service is unavailable.');
    }
    if (weightGrams <= 0) {
      throw const CouchDbException('Laundry weight must be greater than zero.');
    }
    final now = DateTime.now();
    if (expectedPickupDate.isBefore(DateTime(now.year, now.month, now.day))) {
      throw const CouchDbException(
        'Expected pickup date cannot be before the order date.',
      );
    }
    final order = LaundryOrder(
      id: _newId('order'),
      customerId: customer.id,
      customerName: customer.name,
      serviceId: service.id,
      serviceName: service.name,
      weightGrams: weightGrams,
      pricePerKgCentavos: service.pricePerKgCentavos,
      totalAmountCentavos: calculateOrderTotalCentavos(
        weightGrams: weightGrams,
        pricePerKgCentavos: service.pricePerKgCentavos,
      ),
      orderDate: now,
      expectedPickupDate: expectedPickupDate,
      status: OrderStatus.pending,
      specialInstructions: specialInstructions.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await client.createDocument(order.id, order.toDocument());
    await refresh();
  }

  Future<void> updateOrder({
    required String id,
    required int weightGrams,
    required DateTime expectedPickupDate,
    required OrderStatus status,
    required String specialInstructions,
  }) async {
    if (weightGrams <= 0) {
      throw const CouchDbException('Laundry weight must be greater than zero.');
    }
    final order = _orderById(id);
    final normalizedPickup = DateTime(
      expectedPickupDate.year,
      expectedPickupDate.month,
      expectedPickupDate.day,
    );
    final normalizedOrder = DateTime(
      order.orderDate.year,
      order.orderDate.month,
      order.orderDate.day,
    );
    if (normalizedPickup.isBefore(normalizedOrder)) {
      throw const CouchDbException(
        'Expected pickup date cannot precede the order date.',
      );
    }
    if (status == OrderStatus.cancelled && _paidForOrder(order.id) > 0) {
      throw const CouchDbException(
        'This order has payments. Record a refund or adjustment before '
        'cancelling it.',
      );
    }
    final total = calculateOrderTotalCentavos(
      weightGrams: weightGrams,
      pricePerKgCentavos: order.pricePerKgCentavos,
    );
    if (total < _paidForOrder(id)) {
      throw const CouchDbException(
        'The new order total cannot be less than payments already recorded.',
      );
    }
    await client.updateDocument(id, {
      'weight_grams': weightGrams,
      'total_amount_centavos': total,
      'expected_pickup_date': expectedPickupDate.toUtc().toIso8601String(),
      'order_status': status.label,
      'special_instructions': specialInstructions.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await refresh();
  }

  Future<void> createPayment({
    required String orderId,
    required int amountCentavos,
    required PaymentMethod method,
    required String reference,
  }) async {
    if (amountCentavos <= 0) {
      throw const CouchDbException('Payment amount must be greater than zero.');
    }
    await refresh();
    final order = _orderById(orderId);
    if (order.status == OrderStatus.cancelled) {
      throw const CouchDbException('Cannot pay a cancelled order.');
    }
    final orderPayments = payments.where(
      (payment) => payment.orderId == orderId,
    );
    final balance = remainingBalanceCentavos(order, orderPayments);
    if (amountCentavos > balance) {
      throw CouchDbException(
        'Payment exceeds the outstanding balance of '
        '${formatMoney(balance)}.',
      );
    }
    final now = DateTime.now();
    final payment = LaundryPayment(
      id: _newId('payment'),
      orderId: orderId,
      customerName: order.customerName,
      amountCentavos: amountCentavos,
      method: method,
      paymentDate: now,
      reference: reference.trim(),
      isVoided: false,
      createdAt: now,
    );
    await client.createDocument(payment.id, payment.toDocument());
    await refresh();
  }

  Future<void> voidPayment(String id) async {
    final payment = payments.firstWhere(
      (item) => item.id == id,
      orElse: () => throw const CouchDbException('Payment was not found.'),
    );
    if (payment.isVoided) {
      throw const CouchDbException('This payment has already been voided.');
    }
    await client.updateDocument(id, {
      'is_voided': true,
      'voided_at': DateTime.now().toUtc().toIso8601String(),
    });
    await refresh();
  }

  Customer _customerById(String id) => customers.firstWhere(
    (customer) => customer.id == id,
    orElse: () => throw const CouchDbException('Select an existing customer.'),
  );

  LaundryService _serviceById(String id) => services.firstWhere(
    (service) => service.id == id,
    orElse: () => throw const CouchDbException('Select an existing service.'),
  );

  LaundryOrder _orderById(String id) => orders.firstWhere(
    (order) => order.id == id,
    orElse: () => throw const CouchDbException('Order was not found.'),
  );

  int _paidForOrder(String orderId) => paymentsTotalCentavos(
    payments.where((payment) => payment.orderId == orderId),
  );

  String _newId(String type) {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${type}_$suffix';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    client.close();
    super.dispose();
  }
}

String formatMoney(int centavos) {
  final absolute = centavos.abs();
  final pesos = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final grouped = pesos.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${centavos < 0 ? '-' : ''}₱$grouped.$fraction';
}

int? parseMoneyCentavos(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
  return whole * 100 + fraction;
}

int? parseWeightGrams(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final fraction = int.parse((match.group(2) ?? '').padRight(3, '0'));
  return whole * 1000 + fraction;
}
