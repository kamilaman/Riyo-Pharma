import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/state/app_state.dart";
import "../../alerts/views/alerts_page.dart";
import "../../dashboard/views/dashboard_page.dart";
import "../../inventory/views/inventory_page.dart";
import "../../masters/views/masters_page.dart";
import "../../reports/views/reports_page.dart";
import "../../sales/views/sales_page.dart";
import "../../settings/views/settings_page.dart";
import "../../alerts/viewmodels/alerts_view_model.dart";
import "../../dashboard/viewmodels/dashboard_view_model.dart";
import "../../inventory/viewmodels/inventory_view_model.dart";
import "../../masters/viewmodels/masters_view_model.dart";
import "../../reports/viewmodels/reports_view_model.dart";
import "../../sales/viewmodels/sales_view_model.dart";
import "../../settings/viewmodels/settings_view_model.dart";
import "../viewmodels/home_shell_view_model.dart";

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeShellViewModel>();
    final appState = context.read<AppState>();
    final user = viewModel.currentUser;
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final allPages = [
      ChangeNotifierProvider(
        create: (_) => DashboardViewModel(appState),
        child: const DashboardPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => InventoryViewModel(appState),
        child: const InventoryPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => SalesViewModel(appState),
        child: const PosPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => ReportsViewModel(appState),
        child: const ReportsPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => MastersViewModel(appState),
        child: const MastersPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => AlertsViewModel(appState),
        child: const AlertsPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => SettingsViewModel(appState),
        child: const SettingsPage(),
      ),
    ];
    final userPages = [
      ChangeNotifierProvider(
        create: (_) => DashboardViewModel(appState),
        child: const DashboardPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => InventoryViewModel(appState),
        child: const InventoryPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => SalesViewModel(appState),
        child: const PosPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => ReportsViewModel(appState),
        child: const ReportsPage(),
      ),
      ChangeNotifierProvider(
        create: (_) => AlertsViewModel(appState),
        child: const AlertsPage(),
      ),
    ];
    final pages = viewModel.allowAdmin ? allPages : userPages;

    final adminDestinations = const [
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
    ];
    final userDestinations = const [
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
    final destinations = viewModel.allowAdmin
        ? adminDestinations
        : userDestinations;

    if (viewModel.selectedIndex >= pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<HomeShellViewModel>().ensureValidIndex(pages.length);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Riyo Pharma"),
        centerTitle: false,
        actions: [
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Chip(
                label: Text("${user.username} - ${user.role.name}"),
                avatar: const Icon(Icons.verified_user_outlined, size: 18),
              ),
            ),
          const SizedBox(width: 8),
          if (isMobile)
            IconButton(
              tooltip: "Logout",
              onPressed: viewModel.logout,
              icon: const Icon(Icons.logout),
            )
          else
            TextButton.icon(
              onPressed: viewModel.logout,
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: isMobile
          ? pages[viewModel.selectedIndex]
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: viewModel.selectedIndex,
                  onDestinationSelected: (value) => context
                      .read<HomeShellViewModel>()
                      .setSelectedIndex(value, pages.length),
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.85,
                  destinations: destinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[viewModel.selectedIndex]),
              ],
            ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: viewModel.selectedIndex,
              onDestinationSelected: (value) => context
                  .read<HomeShellViewModel>()
                  .setSelectedIndex(value, pages.length),
              destinations: destinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: destination.icon,
                      label: (destination.label as Text).data ?? "",
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}
