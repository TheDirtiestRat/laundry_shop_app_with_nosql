import 'package:flutter/material.dart';

import '../../data/laundry_store.dart';
import '../../data/couchdb_client.dart';
import '../../models/laundry_models.dart';
import '../shared/management_widgets.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({required this.store, super.key});

  final LaundryStore? store;

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool? _availabilityFilter;

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
        final services = store.services.where((service) {
          final matches =
              service.name.toLowerCase().contains(query) ||
              service.description.toLowerCase().contains(query);
          return matches &&
              (_availabilityFilter == null ||
                  service.isAvailable == _availabilityFilter);
        }).toList();

        return ManagementTablePage(
          title: 'Laundry services',
          description:
              'Manage service descriptions, pricing, and availability.',
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _query = value),
          onAdd: () => _editService(context, store),
          onRefresh: () => refreshStore(context, store),
          errorMessage: store.lastError,
          emptyMessage: 'No services found. Add your first laundry service.',
          filter: DropdownButton<bool?>(
            value: _availabilityFilter,
            hint: const Text('Availability'),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('All services')),
              DropdownMenuItem<bool?>(value: true, child: Text('Available')),
              DropdownMenuItem<bool?>(value: false, child: Text('Unavailable')),
            ],
            onChanged: (value) => setState(() => _availabilityFilter = value),
          ),
          columns: const [
            DataColumn(label: Text('SERVICE ID')),
            DataColumn(label: Text('SERVICE NAME')),
            DataColumn(label: Text('DESCRIPTION')),
            DataColumn(label: Text('PRICE / KG')),
            DataColumn(label: Text('COMPLETION')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: [
            for (final service in services)
              DataRow(
                cells: [
                  DataCell(Text(_shortId(service.id))),
                  DataCell(Text(service.name)),
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        service.description.isEmpty ? '—' : service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(formatMoney(service.pricePerKgCentavos))),
                  DataCell(Text('${service.estimatedCompletionHours} hrs')),
                  DataCell(
                    StatusBadge(
                      label: service.isAvailable ? 'Available' : 'Unavailable',
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () =>
                              _editService(context, store, service),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: service.isAvailable
                              ? 'Delete or deactivate'
                              : 'Delete',
                          onPressed: () =>
                              _deleteService(context, store, service),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                        ),
                      ],
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

String _shortId(String id) => id.length > 18 ? id.substring(0, 18) : id;

Future<void> _editService(
  BuildContext context,
  LaundryStore store, [
  LaundryService? service,
]) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: service?.name ?? '');
  final description = TextEditingController(text: service?.description ?? '');
  final price = TextEditingController(
    text: service == null
        ? ''
        : (service.pricePerKgCentavos / 100).toStringAsFixed(2),
  );
  final hours = TextEditingController(
    text: service?.estimatedCompletionHours.toString() ?? '24',
  );
  var available = service?.isAvailable ?? true;
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(service == null ? 'Add service' : 'Edit service'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Service name', required: true),
                const SizedBox(height: 12),
                _field(description, 'Description', maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        price,
                        'Price per kg (PHP)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) =>
                            parseMoneyCentavos(value ?? '') == null ||
                                parseMoneyCentavos(value ?? '')! <= 0
                            ? 'Enter a positive price.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        hours,
                        'Completion hours',
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            int.tryParse(value ?? '') == null ||
                                int.parse(value!) <= 0
                            ? 'Enter positive hours.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for new orders'),
                  value: available,
                  onChanged: (value) => setDialogState(() => available = value),
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
                      final priceCentavos = parseMoneyCentavos(price.text)!;
                      final completion = int.parse(hours.text);
                      if (service == null) {
                        await store.createService(
                          name: name.text,
                          description: description.text,
                          pricePerKgCentavos: priceCentavos,
                          completionHours: completion,
                          isAvailable: available,
                        );
                      } else {
                        await store.updateService(
                          service.id,
                          name: name.text,
                          description: description.text,
                          pricePerKgCentavos: priceCentavos,
                          completionHours: completion,
                          isAvailable: available,
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
            child: Text(saving ? 'Saving…' : 'Save service'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  description.dispose();
  price.dispose();
  hours.dispose();
}

Future<void> _deleteService(
  BuildContext context,
  LaundryStore store,
  LaundryService service,
) async {
  final referenced = store.orders.any((order) => order.serviceId == service.id);
  final confirmed = await confirmAction(
    context,
    title: referenced ? 'Deactivate service?' : 'Delete service?',
    message: referenced
        ? 'This service is referenced by orders. It will be marked unavailable '
              'so transaction history remains intact.'
        : 'Delete ${service.name}?',
    confirmLabel: referenced ? 'Deactivate' : 'Delete',
  );
  if (!confirmed) return;
  try {
    await store.deleteService(service.id);
  } on CouchDbException catch (error) {
    if (context.mounted) await showStoreError(context, error);
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool required = false,
  int maxLines = 1,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
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
