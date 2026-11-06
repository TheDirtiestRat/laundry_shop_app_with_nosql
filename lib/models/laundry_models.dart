enum OrderStatus {
  pending('Pending'),
  washing('Washing'),
  drying('Drying'),
  folding('Folding'),
  readyForPickup('Ready for Pickup'),
  claimed('Claimed'),
  cancelled('Cancelled');

  const OrderStatus(this.label);

  final String label;

  static OrderStatus fromValue(Object? value) => OrderStatus.values.firstWhere(
    (status) => status.label == value,
    orElse: () => throw FormatException('Unknown laundry order status: $value'),
  );
}

enum PaymentMethod {
  cash('Cash'),
  gcash('GCash'),
  maya('Maya'),
  bankTransfer('Bank Transfer');

  const PaymentMethod(this.label);

  final String label;

  static PaymentMethod fromValue(Object? value) =>
      PaymentMethod.values.firstWhere(
        (method) => method.label == value,
        orElse: () => throw FormatException('Unknown payment method: $value'),
      );
}

enum PaymentStatus { unpaid, partiallyPaid, fullyPaid }

int _int(Object? value, String field) {
  if (value is num && value.isFinite) return value.toInt();
  throw FormatException('Document field "$field" must be a number.');
}

DateTime _date(Object? value, String field) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Document field "$field" must be an ISO date.');
}

String _string(Object? value) => value is String ? value : '';

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Document field "$field" is missing or empty.');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw FormatException('Document field "$field" must be true or false.');
}

int _moneyCentavos(Object? cents, Object? legacyPesos) {
  if (cents is num && cents.isFinite) return cents.toInt();
  if (legacyPesos is num && legacyPesos.isFinite) {
    return (legacyPesos * 100).round();
  }
  throw const FormatException(
    'Document must include a numeric money amount in centavos or pesos.',
  );
}

int _weightGrams(Object? grams, Object? legacyKilograms) {
  if (grams is num && grams.isFinite) return grams.toInt();
  if (legacyKilograms is num && legacyKilograms.isFinite) {
    return (legacyKilograms * 1000).round();
  }
  throw const FormatException(
    'Order must include a numeric weight in grams or kilograms.',
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.contactNumber,
    required this.email,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String contactNumber;
  final String email;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: _requiredString(json, '_id'),
    name: _requiredString(json, 'full_name'),
    contactNumber: _requiredString(json, 'contact_number'),
    email: _string(json['email']),
    address: _string(json['address']),
    createdAt: _date(json['created_at'], 'created_at'),
    updatedAt: _date(json['updated_at'], 'updated_at'),
  );

  Map<String, dynamic> toDocument() => {
    'type': 'customer',
    'full_name': name,
    'contact_number': contactNumber,
    'email': email,
    'address': address,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class LaundryService {
  const LaundryService({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerKgCentavos,
    required this.estimatedCompletionHours,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final int pricePerKgCentavos;
  final int estimatedCompletionHours;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LaundryService.fromJson(Map<String, dynamic> json) => LaundryService(
    id: _requiredString(json, '_id'),
    name: _requiredString(json, 'service_name'),
    description: _string(json['description']),
    pricePerKgCentavos: _moneyCentavos(
      json['price_per_kg_centavos'],
      json['price_per_kg'],
    ),
    estimatedCompletionHours: _int(
      json['estimated_completion_hours'],
      'estimated_completion_hours',
    ),
    isAvailable: _requiredBool(json, 'is_available'),
    createdAt: _date(json['created_at'], 'created_at'),
    updatedAt: _date(json['updated_at'], 'updated_at'),
  );

  Map<String, dynamic> toDocument() => {
    'type': 'service',
    'service_name': name,
    'description': description,
    'price_per_kg_centavos': pricePerKgCentavos,
    'estimated_completion_hours': estimatedCompletionHours,
    'is_available': isAvailable,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class LaundryOrder {
  const LaundryOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.serviceId,
    required this.serviceName,
    required this.weightGrams,
    required this.pricePerKgCentavos,
    required this.totalAmountCentavos,
    required this.orderDate,
    required this.expectedPickupDate,
    required this.status,
    required this.specialInstructions,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String serviceId;
  final String serviceName;
  final int weightGrams;
  final int pricePerKgCentavos;
  final int totalAmountCentavos;
  final DateTime orderDate;
  final DateTime expectedPickupDate;
  final OrderStatus status;
  final String specialInstructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LaundryOrder.fromJson(Map<String, dynamic> json) => LaundryOrder(
    id: _requiredString(json, '_id'),
    customerId: _requiredString(json, 'customer_id'),
    customerName: _requiredString(json, 'customer_name'),
    serviceId: _requiredString(json, 'service_id'),
    serviceName: _requiredString(json, 'service_name'),
    weightGrams: _weightGrams(json['weight_grams'], json['laundry_weight']),
    pricePerKgCentavos: _moneyCentavos(
      json['price_per_kg_centavos'],
      json['price_per_kg'],
    ),
    totalAmountCentavos: _moneyCentavos(
      json['total_amount_centavos'],
      json['total_amount'],
    ),
    orderDate: _date(json['order_date'], 'order_date'),
    expectedPickupDate: _date(
      json['expected_pickup_date'],
      'expected_pickup_date',
    ),
    status: OrderStatus.fromValue(json['order_status']),
    specialInstructions: _string(json['special_instructions']),
    createdAt: _date(json['created_at'], 'created_at'),
    updatedAt: _date(json['updated_at'], 'updated_at'),
  );

  Map<String, dynamic> toDocument() => {
    'type': 'order',
    'customer_id': customerId,
    'customer_name': customerName,
    'service_id': serviceId,
    'service_name': serviceName,
    'weight_grams': weightGrams,
    'price_per_kg_centavos': pricePerKgCentavos,
    'total_amount_centavos': totalAmountCentavos,
    'order_date': orderDate.toUtc().toIso8601String(),
    'expected_pickup_date': expectedPickupDate.toUtc().toIso8601String(),
    'order_status': status.label,
    'special_instructions': specialInstructions,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class LaundryPayment {
  const LaundryPayment({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.amountCentavos,
    required this.method,
    required this.paymentDate,
    required this.reference,
    required this.isVoided,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String customerName;
  final int amountCentavos;
  final PaymentMethod method;
  final DateTime paymentDate;
  final String reference;
  final bool isVoided;
  final DateTime createdAt;

  factory LaundryPayment.fromJson(Map<String, dynamic> json) => LaundryPayment(
    id: _requiredString(json, '_id'),
    orderId: _requiredString(json, 'order_id'),
    customerName: _string(json['customer_name']),
    amountCentavos: _moneyCentavos(
      json['amount_centavos'],
      json['amount_paid'],
    ),
    method: PaymentMethod.fromValue(json['payment_method']),
    paymentDate: _date(json['payment_date'], 'payment_date'),
    reference: _string(json['payment_reference']),
    isVoided: json['is_voided'] == true,
    createdAt: _date(json['created_at'], 'created_at'),
  );

  Map<String, dynamic> toDocument() => {
    'type': 'payment',
    'order_id': orderId,
    'customer_name': customerName,
    'amount_centavos': amountCentavos,
    'payment_method': method.label,
    'payment_date': paymentDate.toUtc().toIso8601String(),
    'payment_reference': reference,
    'is_voided': isVoided,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

int calculateOrderTotalCentavos({
  required int weightGrams,
  required int pricePerKgCentavos,
}) {
  return ((weightGrams * pricePerKgCentavos) + 500) ~/ 1000;
}

int paymentsTotalCentavos(Iterable<LaundryPayment> payments) => payments
    .where((payment) => !payment.isVoided)
    .fold(0, (total, payment) => total + payment.amountCentavos);

int remainingBalanceCentavos(
  LaundryOrder order,
  Iterable<LaundryPayment> payments,
) {
  final balance = order.totalAmountCentavos - paymentsTotalCentavos(payments);
  return balance < 0 ? 0 : balance;
}

PaymentStatus paymentStatus(
  LaundryOrder order,
  Iterable<LaundryPayment> payments,
) {
  final paid = paymentsTotalCentavos(payments);
  if (paid == 0) return PaymentStatus.unpaid;
  if (paid >= order.totalAmountCentavos) return PaymentStatus.fullyPaid;
  return PaymentStatus.partiallyPaid;
}
