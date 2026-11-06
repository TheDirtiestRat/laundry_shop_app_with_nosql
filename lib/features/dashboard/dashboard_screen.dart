import 'package:flutter/material.dart';

import '../../data/couchdb_client.dart';
import '../../data/laundry_store.dart';
import '../../models/laundry_models.dart';
import '../shared/management_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.store, super.key});

  final LaundryStore? store;

  @override
  Widget build(BuildContext context) {
    final currentStore = store;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            currentStore == null
                ? 'Connect your CouchDB database to view shop activity.'
                : 'Here is what is happening in your laundry shop.',
            style: const TextStyle(color: Color(0xFF78869B), fontSize: 14),
          ),
          const SizedBox(height: 22),
          if (currentStore == null)
            const _NotConnectedCard()
          else
            AnimatedBuilder(
              animation: currentStore,
              builder: (context, _) => _DashboardData(store: currentStore),
            ),
        ],
      ),
    );
  }
}

class _DashboardData extends StatelessWidget {
  const _DashboardData({required this.store});

  final LaundryStore store;

  @override
  Widget build(BuildContext context) {
    if (store.isLoading &&
        store.customers.isEmpty &&
        store.services.isEmpty &&
        store.orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final outstanding = store.orders.fold<int>(0, (total, order) {
      return total +
          remainingBalanceCentavos(
            order,
            store.payments.where((payment) => payment.orderId == order.id),
          );
    });
    final paymentTotal = paymentsTotalCentavos(store.payments);
    final metrics = <_Metric>[
      _Metric(
        'Total Customers',
        store.customers.length,
        Icons.people_alt_outlined,
        const Color(0xFF4F8FEA),
      ),
      _Metric(
        'Total Orders',
        store.orders.length,
        Icons.receipt_long_outlined,
        const Color(0xFF8B73D6),
      ),
      _Metric(
        'Available Services',
        store.services.where((service) => service.isAvailable).length,
        Icons.local_laundry_service_outlined,
        const Color(0xFF36A88A),
      ),
      _Metric(
        'Payments Received',
        paymentTotal,
        Icons.account_balance_wallet_outlined,
        const Color(0xFFE3A33B),
        money: true,
      ),
      _Metric(
        'Pending Orders',
        store.orders
            .where((order) => order.status == OrderStatus.pending)
            .length,
        Icons.hourglass_empty_rounded,
        const Color(0xFF4F8FEA),
      ),
      _Metric(
        'Ready for Pickup',
        store.orders
            .where((order) => order.status == OrderStatus.readyForPickup)
            .length,
        Icons.inventory_2_outlined,
        const Color(0xFF36A88A),
      ),
      _Metric(
        'Outstanding Balance',
        outstanding,
        Icons.payments_outlined,
        const Color(0xFFDD7A63),
        money: true,
      ),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1500
        ? 4
        : width >= 950
        ? 3
        : width >= 650
        ? 2
        : 1;
    final recent = store.orders.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (store.lastError != null)
          _InlineError(
            message: store.lastError!,
            onRetry: () => _refresh(context, store),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent orders',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh dashboard',
                      onPressed: () => _refresh(context, store),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(26),
                    child: Center(
                      child: Text(
                        'No orders yet. Create an order to get started.',
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ORDER')),
                        DataColumn(label: Text('CUSTOMER')),
                        DataColumn(label: Text('SERVICE')),
                        DataColumn(label: Text('TOTAL')),
                        DataColumn(label: Text('STATUS')),
                      ],
                      rows: [
                        for (final order in recent)
                          DataRow(
                            cells: [
                              DataCell(Text(_shortId(order.id))),
                              DataCell(Text(order.customerName)),
                              DataCell(Text(order.serviceName)),
                              DataCell(
                                Text(formatMoney(order.totalAmountCentavos)),
                              ),
                              DataCell(StatusBadge(label: order.status.label)),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric {
  const _Metric(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.money = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool money;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.money
                      ? formatMoney(metric.value)
                      : metric.value.toString(),
                  style: const TextStyle(
                    color: Color(0xFF25334A),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF78869B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConnectedCard extends StatelessWidget {
  const _NotConnectedCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Row(
        children: [
          Icon(Icons.cloud_queue_rounded, color: Color(0xFF4F8FEA), size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Open Settings, configure the CouchDB connection, and choose '
              '“Connect and load data” to view live dashboard metrics.',
              style: TextStyle(color: Color(0xFF65748A), height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined, color: Colors.red),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Retry',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );
}

Future<void> _refresh(BuildContext context, LaundryStore store) async {
  try {
    await store.refresh();
  } on CouchDbException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

String _shortId(String id) => id.length > 18 ? id.substring(0, 18) : id;
