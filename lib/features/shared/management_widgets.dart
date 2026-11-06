import 'package:flutter/material.dart';

import '../../data/laundry_store.dart';

class ManagementTablePage extends StatelessWidget {
  const ManagementTablePage({
    required this.title,
    required this.description,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    required this.onRefresh,
    this.errorMessage,
    this.filter,
    super.key,
  });

  final String title;
  final String description;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;
  final VoidCallback onRefresh;
  final String? errorMessage;
  final Widget? filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF78869B), fontSize: 14),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final search = SizedBox(
                        width: constraints.maxWidth < 520
                            ? double.infinity
                            : 320,
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search records',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: const Color(0xFFF7F9FD),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      );
                      final addButton = FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add new'),
                      );
                      final refreshButton = IconButton(
                        tooltip: 'Refresh',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      );
                      if (constraints.maxWidth < 520) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            search,
                            const SizedBox(height: 12),
                            if (filter case final activeFilter?) ...[
                              const SizedBox(height: 12),
                              activeFilter,
                            ],
                            Row(
                              children: [
                                refreshButton,
                                const Spacer(),
                                addButton,
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          search,
                          if (filter case final activeFilter?) ...[
                            const SizedBox(width: 12),
                            activeFilter,
                          ],
                          const Spacer(),
                          refreshButton,
                          addButton,
                        ],
                      );
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB63F48),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (rows.isEmpty)
                    _EmptyTable(message: emptyMessage)
                  else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE9EEF6)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF7F9FD),
                                ),
                                headingTextStyle: const TextStyle(
                                  color: Color(0xFF65748A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                dataTextStyle: const TextStyle(
                                  color: Color.fromARGB(255, 9, 27, 55),
                                  fontSize: 12,
                                ),
                                horizontalMargin: 18,
                                columnSpacing: 28,
                                columns: columns,
                                rows: rows,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${rows.length} record${rows.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF8A97A9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTable extends StatelessWidget {
  const _EmptyTable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(34),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FD),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 32, color: Color(0xFF8A97A9)),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class StoreStateView extends StatelessWidget {
  const StoreStateView({required this.store, required this.builder, super.key});

  final LaundryStore? store;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final currentStore = store;
    if (currentStore == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, size: 40, color: Color(0xFF8A97A9)),
              SizedBox(height: 12),
              Text(
                'Connect CouchDB in Settings to use this feature.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: currentStore,
      builder: (context, _) {
        if (currentStore.isLoading &&
            currentStore.customers.isEmpty &&
            currentStore.services.isEmpty &&
            currentStore.orders.isEmpty &&
            currentStore.payments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (currentStore.lastError != null &&
            currentStore.customers.isEmpty &&
            currentStore.services.isEmpty &&
            currentStore.orders.isEmpty &&
            currentStore.payments.isEmpty) {
          return _StoreError(
            message: currentStore.lastError!,
            onRetry: () => refreshStore(context, currentStore),
          );
        }
        return builder(context);
      },
    );
  }
}

class _StoreError extends StatelessWidget {
  const _StoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 38, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Ready for Pickup' ||
      'Fully Paid' ||
      'Available' => const Color(0xFF258563),
      'Cancelled' ||
      'Unpaid' ||
      'Unavailable' ||
      'Void' => const Color(0xFFB63F48),
      'Partially Paid' ||
      'Washing' ||
      'Drying' ||
      'Folding' => const Color(0xFFB87A16),
      _ => const Color(0xFF4F8FEA),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> showStoreError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Action failed'),
      content: Text(error.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> refreshStore(BuildContext context, LaundryStore store) async {
  try {
    await store.refresh();
  } catch (error) {
    if (context.mounted) await showStoreError(context, error);
  }
}
