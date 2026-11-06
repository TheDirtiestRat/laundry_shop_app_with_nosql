import 'package:flutter/material.dart';

import '../../data/laundry_store.dart';
import '../../models/laundry_models.dart';
import '../shared/management_widgets.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.store, super.key});

  final LaundryStore? store;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _includeVoided = false;

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
        final payments = store.payments.where((payment) {
          final order = store.orders.where(
            (item) => item.id == payment.orderId,
          );
          final orderText = order.isEmpty ? '' : order.first.id;
          final matches =
              payment.customerName.toLowerCase().contains(query) ||
              payment.id.toLowerCase().contains(query) ||
              orderText.toLowerCase().contains(query);
          return matches && (_includeVoided || !payment.isVoided);
        }).toList();

        return ManagementTablePage(
          title: 'Payments',
          description: 'Record receipts, view payment history, and correct errors safely.',
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _query = value),
          onAdd: () => _createPayment(context, store),
          onRefresh: () => refreshStore(context, store),
          errorMessage: store.lastError,
          emptyMessage: 'No matching payment records.',
          filter: FilterChip(
            label: const Text('Include voided'),
            selected: _includeVoided,
            onSelected: (value) => setState(() => _includeVoided = value),
          ),
          columns: const [
            DataColumn(label: Text('PAYMENT ID')),
            DataColumn(label: Text('ORDER ID')),
            DataColumn(label: Text('CUSTOMER')),
            DataColumn(label: Text('AMOUNT')),
            DataColumn(label: Text('METHOD')),
            DataColumn(label: Text('PAYMENT DATE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: [
            for (final payment in payments)
              DataRow(
                cells: [
                  DataCell(Text(_shortId(payment.id))),
                  DataCell(Text(_shortId(payment.orderId))),
                  DataCell(Text(payment.customerName)),
                  DataCell(Text(formatMoney(payment.amountCentavos))),
                  DataCell(Text(payment.method.label)),
                  DataCell(Text(_formatDate(payment.paymentDate))),
                  DataCell(
                    StatusBadge(label: payment.isVoided ? 'Void' : 'Received'),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: payment.isVoided
                          ? 'Already voided'
                          : 'Void payment',
                      onPressed: payment.isVoided
                          ? null
                          : () => _voidPayment(context, store, payment),
                      icon: const Icon(
                        Icons.undo_rounded,
                        size: 18,
                        color: Colors.red,
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

Future<void> _createPayment(BuildContext context, LaundryStore store) async {
  final eligibleOrders = store.orders.where((order) {
    return order.status != OrderStatus.cancelled &&
        remainingBalanceCentavos(
              order,
              store.payments.where((payment) => payment.orderId == order.id),
            ) >
            0;
  }).toList();
  if (eligibleOrders.isEmpty) {
    await showStoreError(
      context,
      'There are no orders with an outstanding balance.',
    );
    return;
  }

  final formKey = GlobalKey<FormState>();
  String? orderId = eligibleOrders.first.id;
  PaymentMethod method = PaymentMethod.cash;
  final amount = TextEditingController();
  final reference = TextEditingController();
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final order = eligibleOrders.firstWhere((item) => item.id == orderId);
        final balance = remainingBalanceCentavos(
          order,
          store.payments.where((payment) => payment.orderId == order.id),
        );

        return AlertDialog(
          title: const Text('Record payment'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: orderId,
                    decoration: const InputDecoration(labelText: 'Order'),
                    items: [
                      for (final option in eligibleOrders)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(
                            '${_shortId(option.id)} · ${option.customerName}',
                          ),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() => orderId = value),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Order total: ${formatMoney(order.totalAmountCentavos)}'
                      '    Balance due: ${formatMoney(balance)}',
                      style: const TextStyle(
                        color: Color(0xFF65748A),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final cents = parseMoneyCentavos(value ?? '');
                      if (cents == null || cents <= 0) {
                        return 'Enter a payment amount greater than zero.';
                      }
                      if (cents > balance) {
                        return 'Payment cannot exceed ${formatMoney(balance)}.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Amount paid (PHP)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: [
                      for (final option in PaymentMethod.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => method = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                    ),
                  ),
                ],
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
                      setDialogState(() => saving = true);
                      try {
                        await store.createPayment(
                          orderId: orderId!,
                          amountCentavos: parseMoneyCentavos(amount.text)!,
                          method: method,
                          reference: reference.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          await showStoreError(dialogContext, error);
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save payment'),
            ),
          ],
        );
      },
    ),
  );
  amount.dispose();
  reference.dispose();
}

Future<void> _voidPayment(
  BuildContext context,
  LaundryStore store,
  LaundryPayment payment,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Void payment record?',
    message:
        'This keeps the record for audit history and excludes it from paid '
        'totals. If a replacement receipt is needed, record it separately.',
    confirmLabel: 'Void payment',
  );
  if (!confirmed) return;
  try {
    await store.voidPayment(payment.id);
  } catch (error) {
    if (context.mounted) await showStoreError(context, error);
  }
}

String _shortId(String id) => id.length > 18 ? id.substring(0, 18) : id;

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
