import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth_gate.dart';
import 'b2b_page.dart';
import 'executive_dashboard_page.dart';
import 'history_page.dart';
import 'inventory_page.dart';
import 'stock_alert_page.dart';
import 'system_status_page.dart';
import 'planning_data_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pages = <Widget>[];
    final destinations = <NavigationDestination>[];
    void add(Widget page, IconData icon, String label) {
      pages.add(page);
      destinations.add(NavigationDestination(icon: Icon(icon), label: label));
    }

    if (auth.isManager) {
      add(const ExecutiveDashboardPage(), Icons.analytics_outlined, 'ภาพรวม');
    }
    if (auth.canManageInventory) {
      add(const InventoryPage(), Icons.inventory_2_outlined, 'คลังสินค้า');
    }
    if (auth.isManager || auth.canManageOrders) {
      add(
        const StockAlertPage(),
        Icons.notifications_active_outlined,
        'แจ้งเตือน',
      );
    }
    if (auth.canManageOrders || auth.canManageInventory) {
      add(
        const B2BPage(),
        Icons.business_outlined,
        auth.canManageOrders ? 'คำสั่งซื้อขายส่ง' : 'คำสั่งผลิต',
      );
    }
    add(const HistoryPage(), Icons.history, 'ประวัติ');
    if (index >= pages.length) index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Water World • ${auth.currentUser?.displayName ?? ''}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') auth.signOut();
              if (value == 'status') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemStatusPage()),
                );
              }
              if (value == 'users') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                );
              }
              if (value == 'recipes') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecipeSetupPage()),
                );
              }
              if (value == 'receipts') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PurchaseReceiptsPage(),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              if (auth.isManager)
                const PopupMenuItem(
                  value: 'users',
                  child: Text('จัดการบัญชีผู้ใช้'),
                ),
              if (auth.canManageInventory)
                const PopupMenuItem(
                  value: 'recipes',
                  child: Text('สูตรการผลิต'),
                ),
              if (auth.canManageOrders)
                const PopupMenuItem(
                  value: 'receipts',
                  child: Text('ใบรับสินค้าจากการซื้อ'),
                ),
              const PopupMenuItem(
                value: 'status',
                child: Text('บัญชีและข้อมูล'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: destinations.length >= 2
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: destinations,
            )
          : null,
    );
  }
}
