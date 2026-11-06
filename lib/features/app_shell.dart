import 'package:flutter/material.dart';

import '../data/laundry_store.dart';
import 'customers/customer_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'orders/order_screen.dart';
import 'payments/payment_screen.dart';
import 'services/service_screen.dart';
import 'settings/couchdb_settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  LaundryStore? _store;

  static const _destinations = <_Destination>[
    _Destination('Dashboard', Icons.space_dashboard_outlined),
    _Destination('Customers', Icons.people_outline),
    _Destination('Laundry Services', Icons.local_laundry_service_outlined),
    _Destination('Orders', Icons.receipt_long_outlined),
    _Destination('Payments', Icons.account_balance_wallet_outlined),
    _Destination('Settings', Icons.settings_outlined),
  ];

  Future<void> _acceptStore(LaundryStore store) async {
    final oldStore = _store;
    setState(() => _store = store);
    oldStore?.dispose();
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final expandedSidebar = constraints.maxWidth >= 1000;

            return Row(
              children: [
                _Sidebar(
                  expanded: expandedSidebar,
                  destinations: _destinations,
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(title: _destinations[_selectedIndex].label),
                      Expanded(
                        child: switch (_selectedIndex) {
                          0 => DashboardScreen(store: _store),
                          1 => CustomerScreen(store: _store),
                          2 => ServiceScreen(store: _store),
                          3 => OrderScreen(store: _store),
                          4 => PaymentScreen(store: _store),
                          5 => CouchDbSettingsScreen(onConnected: _acceptStore),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.expanded,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool expanded;
  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: expanded ? 248 : 76,
      margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 8,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EEF6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B263B5A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 0),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_laundry_service_rounded,
                    color: colors.primary,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'FreshFold',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF25334A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: Color(0xFF9AA6B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          for (var index = 0; index < destinations.length; index++)
            _SidebarItem(
              destination: destinations[index],
              selected: selectedIndex == index,
              expanded: expanded,
              onTap: () => onSelected(index),
            ),
          const Spacer(),
          if (expanded)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Laundry management',
                style: TextStyle(color: Color(0xFF9AA6B8), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 46,
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
      decoration: BoxDecoration(
        color: selected ? colors.primary.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(
            destination.icon,
            size: 20,
            color: selected ? colors.primary : const Color(0xFF78869B),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? colors.primary : const Color(0xFF65748A),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: expanded ? '' : destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: item,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${_monthName(now.month)} ${now.day}, ${now.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(date, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 760) ...[
            const CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFFDCEAFF),
              child: Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: Color(0xFF4F8FEA),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
