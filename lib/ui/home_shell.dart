import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../app_state.dart";
import "../models.dart";
import "pages.dart";

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser!;
    final allPages = const [
      DashboardPage(),
      InventoryPage(),
      PosPage(),
      ReportsPage(),
      MastersPage(),
      AlertsPage(),
      SettingsPage(),
    ];
    final allowAdmin =
        user.role == UserRole.admin || user.role == UserRole.pharmacist;
    final pages = allowAdmin
        ? allPages
        : const [
            DashboardPage(),
            InventoryPage(),
            PosPage(),
            ReportsPage(),
            AlertsPage(),
          ];

    final destinations = allowAdmin
        ? const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: Text("Dashboard"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text("Inventory"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              label: Text("Sales / POS"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.summarize_outlined),
              label: Text("Reports"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.groups_outlined),
              label: Text("Masters"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.notifications_active_outlined),
              label: Text("Alerts"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              label: Text("Settings"),
            ),
          ]
        : const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: Text("Dashboard"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text("Inventory"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              label: Text("Sales / POS"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.summarize_outlined),
              label: Text("Reports"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.notifications_active_outlined),
              label: Text("Alerts"),
            ),
          ];

    if (index >= pages.length) {
      index = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("PharmaCore"),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Chip(
              label: Text("${user.username} • ${user.role.name}"),
              avatar: const Icon(Icons.verified_user_outlined, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => context.read<AppState>().logout(),
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (v) => setState(() => index = v),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -0.85,
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[index]),
        ],
      ),
    );
  }
}
