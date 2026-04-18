import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../../../core/models/models.dart";
import "../../../core/state/app_state.dart";
import "../../../shared/widgets/ui_kit.dart";

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _animations;
  String _selectedFilter = 'All';
  bool _isAutoRefresh = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animations = List.generate(8, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.1,
            (index + 1) * 0.1 + 0.3,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefresh = !_isAutoRefresh;
      if (_isAutoRefresh) {
        _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          context.read<AppState>().runAlerts();
        });
      } else {
        _refreshTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final alerts = _generateAlerts(s);
    final filteredAlerts = _filterAlerts(alerts);

    return PageSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ui.pageTitle(
              context,
              "Alerts & Notifications",
              subtitle: "Real-time monitoring of your pharmacy operations",
            ),

            // Alert Controls
            _buildAlertControls(context, s),
            Ui.sectionGap,

            // Alert Statistics
            _buildAlertStatistics(context, alerts),
            Ui.sectionGap,

            // Filter Tabs
            _buildFilterTabs(context),
            Ui.sectionGap,

            // Alerts List
            _buildAlertsList(context, filteredAlerts),
            Ui.sectionGap,

            // Alert Actions
            _buildAlertActions(context, s),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertControls(BuildContext context, AppState s) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Alert Controls",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Switch(
                value: _isAutoRefresh,
                onChanged: (_) => _toggleAutoRefresh(),
              ),
              Text(
                "Auto Refresh",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => s.runAlerts(),
                icon: const Icon(Icons.refresh),
                label: const Text("Run Alerts"),
              ),
              OutlinedButton.icon(
                onPressed: () => _clearAllAlerts(context),
                icon: const Icon(Icons.clear_all),
                label: const Text("Clear All"),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportAlerts(context, s),
                icon: const Icon(Icons.download),
                label: const Text("Export"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStatistics(BuildContext context, List<AlertItem> alerts) {
    final critical = alerts
        .where((a) => a.severity == AlertSeverity.critical)
        .length;
    final warning = alerts
        .where((a) => a.severity == AlertSeverity.warning)
        .length;
    final info = alerts.where((a) => a.severity == AlertSeverity.info).length;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _AlertStatCard(
          animation: _animations[0],
          title: "Critical",
          value: "$critical",
          icon: Icons.warning,
          color: Colors.red,
          subtitle: "Immediate attention required",
        ),
        _AlertStatCard(
          animation: _animations[1],
          title: "Warning",
          value: "$warning",
          icon: Icons.warning_amber,
          color: Colors.orange,
          subtitle: "Monitor closely",
        ),
        _AlertStatCard(
          animation: _animations[2],
          title: "Info",
          value: "$info",
          icon: Icons.info,
          color: Colors.blue,
          subtitle: "For your information",
        ),
        _AlertStatCard(
          animation: _animations[3],
          title: "Total",
          value: "${alerts.length}",
          icon: Icons.notifications,
          color: Colors.purple,
          subtitle: "All active alerts",
        ),
      ],
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: ['All', 'Critical', 'Warning', 'Info'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlertsList(BuildContext context, List<AlertItem> alerts) {
    if (alerts.isEmpty) {
      return ContentCard(
        child: Container(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                "All Clear!",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "No alerts at the moment. Everything is running smoothly.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: alerts.map((alert) {
        return AlertCard(
          title: alert.title,
          message: alert.message,
          type: alert.type,
          icon: alert.icon,
          timestamp: alert.timestamp,
          severity: alert.severityValue,
          onTap: () => _handleAlertTap(context, alert),
        );
      }).toList(),
    );
  }

  Widget _buildAlertActions(BuildContext context, AppState s) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _QuickActionCard(
                animation: _animations[4],
                title: "Low Stock Report",
                subtitle: "View all low stock items",
                icon: Icons.inventory_2,
                color: Colors.orange,
                onTap: () => _showLowStockReport(context, s),
              ),
              _QuickActionCard(
                animation: _animations[5],
                title: "Expiry Report",
                subtitle: "View items expiring soon",
                icon: Icons.timer,
                color: Colors.red,
                onTap: () => _showExpiryReport(context, s),
              ),
              _QuickActionCard(
                animation: _animations[6],
                title: "Alert Settings",
                subtitle: "Configure alert preferences",
                icon: Icons.settings,
                color: Colors.blue,
                onTap: () => _showAlertSettings(context),
              ),
              _QuickActionCard(
                animation: _animations[7],
                title: "Alert History",
                subtitle: "View past alerts",
                icon: Icons.history,
                color: Colors.purple,
                onTap: () => _showAlertHistory(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<AlertItem> _generateAlerts(AppState s) {
    final alerts = <AlertItem>[];

    // Low stock alerts
    for (final medicine in s.medicines.where((m) => m.isLowStock)) {
      alerts.add(
        AlertItem(
          title: "Low Stock: ${medicine.name}",
          message:
              "Only ${medicine.quantity} units remaining (reorder at ${medicine.reorderLevel})",
          type: AlertType.warning,
          severity: medicine.quantity == 0
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          icon: Icons.inventory_2,
          timestamp: DateTime.now().subtract(
            Duration(minutes: medicine.quantity * 5),
          ),
          medicine: medicine,
        ),
      );
    }

    // Expiry alerts
    for (final medicine in s.medicines.where((m) => m.isNearExpiry)) {
      final daysUntilExpiry = medicine.expiry.difference(DateTime.now()).inDays;
      alerts.add(
        AlertItem(
          title: "Expiring Soon: ${medicine.name}",
          message:
              "Expires in $daysUntilExpiry days (${DateFormat('yyyy-MM-dd').format(medicine.expiry)})",
          type: daysUntilExpiry <= 7 ? AlertType.critical : AlertType.warning,
          severity: daysUntilExpiry <= 7
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          icon: Icons.timer,
          timestamp: medicine.expiry.subtract(Duration(days: daysUntilExpiry)),
          medicine: medicine,
        ),
      );
    }

    // Sort by severity and timestamp
    alerts.sort((a, b) {
      if (a.severityValue != b.severityValue) {
        return b.severityValue - a.severityValue;
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return alerts;
  }

  List<AlertItem> _filterAlerts(List<AlertItem> alerts) {
    switch (_selectedFilter) {
      case 'Critical':
        return alerts
            .where((a) => a.severity == AlertSeverity.critical)
            .toList();
      case 'Warning':
        return alerts
            .where((a) => a.severity == AlertSeverity.warning)
            .toList();
      case 'Info':
        return alerts.where((a) => a.severity == AlertSeverity.info).toList();
      default:
        return alerts;
    }
  }

  void _handleAlertTap(BuildContext context, AlertItem alert) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(alert.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            const SizedBox(height: 16),
            Text(
              "Severity: ${alert.severity.name}",
              style: TextStyle(
                color: alert.type == AlertType.critical
                    ? Colors.red
                    : alert.type == AlertType.warning
                    ? Colors.orange
                    : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Time: ${DateFormat('yyyy-MM-dd HH:mm').format(alert.timestamp)}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          if (alert.medicine != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _viewMedicineDetails(context, alert.medicine!);
              },
              child: const Text("View Medicine"),
            ),
        ],
      ),
    );
  }

  void _clearAllAlerts(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear All Alerts"),
        content: const Text("Are you sure you want to clear all alerts?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("All alerts cleared")),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  void _exportAlerts(BuildContext context, AppState s) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Exporting alerts...")));
  }

  void _showLowStockReport(BuildContext context, AppState s) {
    final lowStock = s.medicines.where((m) => m.isLowStock).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Low Stock Report"),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView(
            children: lowStock
                .map(
                  (m) => ListTile(
                    title: Text(m.name),
                    subtitle: Text(
                      "Current: ${m.quantity} | Reorder: ${m.reorderLevel}",
                    ),
                    trailing: Text(
                      "${((m.quantity / m.reorderLevel) * 100).toInt()}%",
                      style: TextStyle(
                        color: m.quantity == 0 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showExpiryReport(BuildContext context, AppState s) {
    final nearExpiry = s.medicines.where((m) => m.isNearExpiry).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Expiry Report"),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView(
            children: nearExpiry.map((m) {
              final daysUntilExpiry = m.expiry
                  .difference(DateTime.now())
                  .inDays;
              return ListTile(
                title: Text(m.name),
                subtitle: Text(
                  "Expires: ${DateFormat('yyyy-MM-dd').format(m.expiry)}",
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: daysUntilExpiry <= 7 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${daysUntilExpiry}d",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showAlertSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Alert Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text("Low Stock Alerts"),
              subtitle: const Text("Alert when items are below reorder level"),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text("Expiry Alerts"),
              subtitle: const Text("Alert when items are near expiry"),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text("Sound Notifications"),
              subtitle: const Text("Play sound for critical alerts"),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showAlertHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Alert History"),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  "No alert history available",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Alert history will appear here as alerts are generated",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _viewMedicineDetails(BuildContext context, Medicine medicine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(medicine.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Generic: ${medicine.genericName}"),
            Text("Batch: ${medicine.batchNo}"),
            Text("Quantity: ${medicine.quantity}"),
            Text(
              "Purchase Price: Birr ${medicine.purchasePrice.toStringAsFixed(2)}",
            ),
            Text(
              "Selling Price: Birr ${medicine.sellingPrice.toStringAsFixed(2)}",
            ),
            Text("Supplier: ${medicine.supplier}"),
            Text("Category: ${medicine.category}"),
            Text("Expiry: ${DateFormat('yyyy-MM-dd').format(medicine.expiry)}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

class AlertItem {
  final String title;
  final String message;
  final AlertType type;
  final AlertSeverity severity;
  final IconData icon;
  final DateTime timestamp;
  final Medicine? medicine;

  AlertItem({
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.icon,
    required this.timestamp,
    this.medicine,
  });

  int get severityValue {
    switch (severity) {
      case AlertSeverity.critical:
        return 3;
      case AlertSeverity.warning:
        return 2;
      case AlertSeverity.info:
        return 1;
    }
  }
}

enum AlertSeverity { critical, warning, info }

class _AlertStatCard extends StatelessWidget {
  const _AlertStatCard({
    required this.animation,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final Animation<double> animation;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: SizedBox(
            width: 200,
            child: Card(
              elevation: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Animation<double> animation;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.1),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
