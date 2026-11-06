import 'package:flutter/material.dart';

import '../../data/laundry_store.dart';
import '../../models/laundry_models.dart';
import '../shared/management_widgets.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({required this.store, super.key});

  final LaundryStore? store;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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
        final customers = store.customers.where((customer) {
          return customer.name.toLowerCase().contains(query) ||
              customer.contactNumber.toLowerCase().contains(query) ||
              customer.email.toLowerCase().contains(query);
        }).toList();

        return ManagementTablePage(
          title: 'Customers',
          description: 'Manage customer records and contact information.',
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _query = value),
          onAdd: () => _editCustomer(context, store),
          onRefresh: () => refreshStore(context, store),
          errorMessage: store.lastError,
          emptyMessage: 'No customers found. Add your first customer.',
          columns: const [
            DataColumn(label: Text('CUSTOMER ID')),
            DataColumn(label: Text('NAME')),
            DataColumn(label: Text('CONTACT')),
            DataColumn(label: Text('EMAIL')),
            DataColumn(label: Text('ADDRESS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: [
            for (final customer in customers)
              DataRow(
                cells: [
                  DataCell(Text(_shortId(customer.id))),
                  DataCell(Text(customer.name)),
                  DataCell(Text(customer.contactNumber)),
                  DataCell(Text(customer.email.isEmpty ? '—' : customer.email)),
                  DataCell(
                    Text(customer.address.isEmpty ? '—' : customer.address),
                  ),
                  DataCell(
                    _actions(
                      onEdit: () => _editCustomer(context, store, customer),
                      onDelete: () => _deleteCustomer(context, store, customer),
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

Widget _actions({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Edit',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined, size: 18),
      ),
      IconButton(
        tooltip: 'Delete',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
      ),
    ],
  );
}

String _shortId(String id) => id.length > 18 ? id.substring(0, 18) : id;

Future<void> _editCustomer(
  BuildContext context,
  LaundryStore store, [
  Customer? customer,
]) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: customer?.name ?? '');
  final contact = TextEditingController(text: customer?.contactNumber ?? '');
  final email = TextEditingController(text: customer?.email ?? '');
  final address = TextEditingController(text: customer?.address ?? '');
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(customer == null ? 'Add customer' : 'Edit customer'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Full name', required: true),
                const SizedBox(height: 12),
                _field(contact, 'Contact number', required: true),
                const SizedBox(height: 12),
                _field(
                  email,
                  'Email (optional)',
                  validator: (value) =>
                      value != null &&
                          value.isNotEmpty &&
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 12),
                _field(address, 'Address (optional)', maxLines: 2),
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
                      if (customer == null) {
                        await store.createCustomer(
                          name: name.text,
                          contactNumber: contact.text,
                          email: email.text,
                          address: address.text,
                        );
                      } else {
                        await store.updateCustomer(
                          customer.id,
                          name: name.text,
                          contactNumber: contact.text,
                          email: email.text,
                          address: address.text,
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
            child: Text(saving ? 'Saving…' : 'Save customer'),
          ),
        ],
      ),
    ),
  );

  name.dispose();
  contact.dispose();
  email.dispose();
  address.dispose();
}

Future<void> _deleteCustomer(
  BuildContext context,
  LaundryStore store,
  Customer customer,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Delete customer?',
    message:
        'Delete ${customer.name}? Customers with order history cannot be deleted.',
    confirmLabel: 'Delete',
  );
  if (!confirmed) return;
  try {
    await store.deleteCustomer(customer.id);
  } catch (error) {
    if (context.mounted) await showStoreError(context, error);
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool required = false,
  int maxLines = 1,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    validator:
        validator ??
        (required
            ? (value) => value == null || value.trim().isEmpty
                  ? '$label is required.'
                  : null
            : null),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
