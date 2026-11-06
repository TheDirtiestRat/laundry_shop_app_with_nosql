import 'package:flutter/material.dart';

import '../../data/laundry_store.dart';
import '../../models/laundry_models.dart';
import '../shared/management_widgets.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({required this.store, super.key});

  final LaundryStore? store;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  OrderStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreStateView(
      store: widget.store,
      builder: (context) {
        final store = widget.store!;
        final query = _query.toLowerCase();
        final orders = store.orders.where((order) {
          final matches =
              order.customerName.toLowerCase().contains(query) ||
              order.id.toLowerCase().contains(query) ||
              order.serviceName.toLowerCase().contains(query);
          return matches &&
              (_statusFilter == null || order.status == _statusFilter);
        }).toList();

        return ManagementTablePage(
          title: 'Laundry orders',
          description:
              'Create orders, update progress, and track pickup dates.',
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _query = value),
          onAdd: () => _editOrder(context, store),
          onRefresh: () => refreshStore(context, store),
          errorMessage: store.lastError,
          emptyMessage: 'No matching orders.',
          filter: DropdownButton<OrderStatus?>(
            value: _statusFilter,
            hint: const Text('Order status'),
            items: [
              const DropdownMenuItem<OrderStatus?>(
                value: null,
                child: Text('All statuses'),
              ),
              for (final status in OrderStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
          columns: const [
            DataColumn(label: Text('ORDER ID')),
            DataColumn(label: Text('CUSTOMER')),
            DataColumn(label: Text('SERVICE')),
            DataColumn(label: Text('WEIGHT')),
            DataColumn(label: Text('TOTAL')),
            DataColumn(label: Text('PAYMENT')),
            DataColumn(label: Text('ORDER DATE')),
            DataColumn(label: Text('PICKUP DATE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: [
            for (final order in orders)
              DataRow(
                cells: [
                  DataCell(Text(_shortId(order.id))),
                  DataCell(Text(order.customerName)),
                  DataCell(Text(order.serviceName)),
                  DataCell(Text(_formatWeight(order.weightGrams))),
                  DataCell(Text(formatMoney(order.totalAmountCentavos))),
                  DataCell(
                    StatusBadge(
                      label: switch (paymentStatus(
                        order,
                        store.payments.where(
                          (payment) => payment.orderId == order.id,
                        ),
                      )) {
                        PaymentStatus.unpaid => 'Unpaid',
                        PaymentStatus.partiallyPaid => 'Partially Paid',
                        PaymentStatus.fullyPaid => 'Fully Paid',
                      },
                    ),
                  ),
                  DataCell(Text(_formatDate(order.orderDate))),
                  DataCell(Text(_formatDate(order.expectedPickupDate))),
                  DataCell(StatusBadge(label: order.status.label)),
                  DataCell(
                    IconButton(
                      tooltip: order.status == OrderStatus.cancelled
                          ? 'View order'
                          : 'Edit order',
                      onPressed: () => order.status == OrderStatus.cancelled
                          ? _showOrderDetails(context, order, store)
                          : _editOrder(context, store, order),
                      icon: Icon(
                        order.status == OrderStatus.cancelled
                            ? Icons.visibility_outlined
                            : Icons.edit_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

Future<void> _editOrder(
  BuildContext context,
  LaundryStore store, [
  LaundryOrder? order,
]) async {
  if (order == null && (store.customers.isEmpty || store.services.isEmpty)) {
    await showStoreError(
      context,
      'Add at least one customer and one service before creating an order.',
    );
    return;
  }
  final formKey = GlobalKey<FormState>();
  var customerId = order?.customerId;
  var serviceId = order?.serviceId;
  var status = order?.status ?? OrderStatus.pending;
  var pickupDate = order?.expectedPickupDate ?? DateTime.now();
  final weight = TextEditingController(
    text: order == null ? '' : (order.weightGrams / 1000).toStringAsFixed(3),
  );
  final instructions = TextEditingController(
    text: order?.specialInstructions ?? '',
  );
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(order == null ? 'Create laundry order' : 'Edit order'),
        content: SizedBox(
          width: 540,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (order == null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: customerId,
                      decoration: const InputDecoration(labelText: 'Customer'),
                      items: [
                        for (final customer in store.customers)
                          DropdownMenuItem(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Select a customer.' : null,
                      onChanged: (value) =>
                          setDialogState(() => customerId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: serviceId,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: [
                        for (final service in store.services.where(
                          (service) => service.isAvailable,
                        ))
                          DropdownMenuItem(
                            value: service.id,
                            child: Text(
                              '${service.name} — '
                              '${formatMoney(service.pricePerKgCentavos)}/kg',
                            ),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Select an available service.' : null,
                      onChanged: (value) =>
                          setDialogState(() => serviceId = value),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    _readOnlyValue('Customer', order.customerName),
                    _readOnlyValue('Service', order.serviceName),
                    DropdownButtonFormField<OrderStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final value in OrderStatus.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = parseWeightGrams(value ?? '');
                      return parsed == null || parsed <= 0
                          ? 'Enter a weight greater than zero.'
                          : null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Laundry weight (kg)',
                    ),
                  ),
                  if (order != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Current total: ${formatMoney(order.totalAmountCentavos)}',
                        style: const TextStyle(color: Color(0xFF78869B)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final earliestDate = order == null
                          ? DateTime.now()
                          : DateTime(
                              order.orderDate.year,
                              order.orderDate.month,
                              order.orderDate.day,
                            );
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: pickupDate.isBefore(earliestDate)
                            ? earliestDate
                            : pickupDate,
                        firstDate: earliestDate,
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (selected != null) {
                        setDialogState(() => pickupDate = selected);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expected pickup date',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_formatDate(pickupDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: instructions,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Special instructions',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    final grams = parseWeightGrams(weight.text)!;
                    setDialogState(() => saving = true);
                    try {
                      if (order == null) {
                        await store.createOrder(
                          customerId: customerId!,
                          serviceId: serviceId!,
                          weightGrams: grams,
                          expectedPickupDate: pickupDate,
                          specialInstructions: instructions.text,
                        );
                      } else {
                        await store.updateOrder(
                          id: order.id,
                          weightGrams: grams,
                          expectedPickupDate: pickupDate,
                          status: status,
                          specialInstructions: instructions.text,
                        );
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (error) {
                      if (dialogContext.mounted) {
                        await showStoreError(dialogContext, error);
                        setDialogState(() => saving = false);
                      }
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Save order'),
          ),
        ],
      ),
    ),
  );
  weight.dispose();
  instructions.dispose();
}

Widget _readOnlyValue(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Align(alignment: Alignment.centerLeft, child: Text('$label: $value')),
);

Future<void> _showOrderDetails(
  BuildContext context,
  LaundryOrder order,
  LaundryStore store,
) async {
  final relatedPayments = store.payments.where((p) => p.orderId == order.id);
  final paid = paymentsTotalCentavos(relatedPayments);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Order ${_shortId(order.id)}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _readOnlyValue('Customer', order.customerName),
            _readOnlyValue('Service', order.serviceName),
            _readOnlyValue('Status', order.status.label),
            _readOnlyValue('Weight', _formatWeight(order.weightGrams)),
            _readOnlyValue('Total', formatMoney(order.totalAmountCentavos)),
            _readOnlyValue('Paid', formatMoney(paid)),
            _readOnlyValue(
              'Balance',
              formatMoney(remainingBalanceCentavos(order, relatedPayments)),
            ),
            _readOnlyValue('Pickup', _formatDate(order.expectedPickupDate)),
            _readOnlyValue(
              'Instructions',
              order.specialInstructions.isEmpty
                  ? 'None'
                  : order.specialInstructions,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _shortId(String id) => id.length > 18 ? id.substring(0, 18) : id;

String _formatWeight(int grams) {
  final kilograms = grams / 1000;
  return '${kilograms.toStringAsFixed(kilograms.truncateToDouble() == kilograms ? 0 : 3)} kg';
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
