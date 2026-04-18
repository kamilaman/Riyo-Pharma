import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../../../core/models/models.dart";
import "../../../core/state/app_state.dart";
import "../../../shared/helpers/receipt_preview_helper.dart";
import "../../../shared/widgets/ui_kit.dart";

/// Barcode wedge capture + lookup for admin and pharmacist (dashboard entry).
class _AdminQuickBarcodePanel extends StatefulWidget {
  const _AdminQuickBarcodePanel();

  @override
  State<_AdminQuickBarcodePanel> createState() =>
      _AdminQuickBarcodePanelState();
}

class _AdminQuickBarcodePanelState extends State<_AdminQuickBarcodePanel> {
  final search = TextEditingController();
  final keyboardFocus = FocusNode();
  DateTime _lastKeyAt = DateTime.now();
  String _barcodeBuffer = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => keyboardFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    search.dispose();
    keyboardFocus.dispose();
    super.dispose();
  }

  void _applyScanOrQuery(AppState s, String code) {
    final trimmed = code.trim();
    if (trimmed.length < 4) return;
    final exact = s.findByBarcode(trimmed);
    if (exact != null) {
      search.clear();
      setState(() {});
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Medicine match"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exact.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text("Generic: ${exact.genericName}"),
                Text("Batch: ${exact.batchNo}"),
                Text("Barcode: ${exact.barcode}"),
                Text("Qty: ${exact.quantity}"),
                Text("Sell: Birr ${exact.sellingPrice.toStringAsFixed(2)}"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      );
      return;
    }
    search.text = trimmed;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final matches = s.filterMedicines(query: search.text);
    return KeyboardListener(
      focusNode: keyboardFocus,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final now = DateTime.now();
        if (now.difference(_lastKeyAt).inMilliseconds > 350) {
          _barcodeBuffer = "";
        }
        _lastKeyAt = now;
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_barcodeBuffer.length >= 4) {
            _applyScanOrQuery(context.read<AppState>(), _barcodeBuffer);
          }
          _barcodeBuffer = "";
          return;
        }
        final label = event.character ?? "";
        if (label.isNotEmpty && RegExp(r"[0-9A-Za-z-]").hasMatch(label)) {
          _barcodeBuffer += label;
        }
      },
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Quick barcode lookup",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Scan here first or type Ã¢â‚¬â€ opens details when the code matches a product.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              decoration: const InputDecoration(
                labelText: "Barcode / search",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => _applyScanOrQuery(s, v),
            ),
            if (search.text.trim().isNotEmpty && matches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Matches (${matches.length})",
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...matches
                  .take(8)
                  .map(
                    (m) => ListTile(
                      dense: true,
                      title: Text(m.name),
                      subtitle: Text(
                        "Barcode ${m.barcode} Ã¢â‚¬Â¢ Qty ${m.quantity}",
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.currentUser;
    final showQuickBarcode =
        user != null &&
        (user.role == UserRole.admin || user.role == UserRole.pharmacist);
    final low = s.medicines.where((m) => m.isLowStock).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    final nearExpiry = s.medicines.where((m) => m.isNearExpiry).toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));
    final recentSales = [...s.sales]..sort((a, b) => b.date.compareTo(a.date));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1200;
        final panelWidth = isWide
            ? (constraints.maxWidth - 40 - 24) / 3
            : constraints.maxWidth - 40;
        return PageSurface(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ui.pageTitle(
                  context,
                  "Dashboard",
                  subtitle: "Overview of stock, alerts, and today's sales.",
                ),
                if (showQuickBarcode) ...[
                  Ui.sectionGap,
                  const _AdminQuickBarcodePanel(),
                ],
                Ui.sectionGap,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatCard(
                      title: "Total Stock Value",
                      value: "Birr ${s.totalStockValue.toStringAsFixed(2)}",
                      icon: Icons.account_balance_wallet_outlined,
                      tint: const Color(0xFF2563EB),
                      progress: s.medicines.isNotEmpty
                          ? (s.totalStockValue / (s.medicines.length * 1000))
                                .clamp(0.0, 1.0)
                          : 0.0,
                      trend: "+12.5%",
                      footer: "${s.medicines.length} items",
                    ),
                    StatCard(
                      title: "Low Stock Items",
                      value: "${s.lowStockCount}",
                      icon: Icons.warning_amber_outlined,
                      tint: const Color(0xFFF59E0B),
                      progress: s.medicines.isNotEmpty
                          ? (s.lowStockCount / s.medicines.length).clamp(
                              0.0,
                              1.0,
                            )
                          : 0.0,
                      trend: s.lowStockCount > 0 ? "-${s.lowStockCount}" : "+0",
                      footer: "Based on reorder level",
                    ),
                    StatCard(
                      title: "Near Expiry",
                      value: "${s.nearExpiryCount}",
                      icon: Icons.timer_outlined,
                      tint: const Color(0xFFEF4444),
                      progress: s.medicines.isNotEmpty
                          ? (s.nearExpiryCount / s.medicines.length).clamp(
                              0.0,
                              1.0,
                            )
                          : 0.0,
                      trend: s.nearExpiryCount > 0
                          ? "-${s.nearExpiryCount}"
                          : "+0",
                      footer: "Next 30 days",
                    ),
                    StatCard(
                      title: "Today's Sales",
                      value: "Birr ${s.todaySales.toStringAsFixed(2)}",
                      icon: Icons.payments_outlined,
                      tint: const Color(0xFF10B981),
                      progress: s.sales.isNotEmpty
                          ? (s.todaySales / 5000).clamp(0.0, 1.0)
                          : 0.0,
                      trend: "+8.3%",
                      footer:
                          "${s.sales.where((sale) => sale.date.day == DateTime.now().day).length} transactions",
                    ),
                  ],
                ),
                Ui.sectionGap,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _enhancedAlertPanel(
                      context: context,
                      title: "Stock Alerts",
                      width: panelWidth,
                      alerts: [
                        ...low.map(
                          (m) => AlertCard(
                            title: "Low Stock: ${m.name}",
                            message:
                                "Only ${m.quantity} units left (reorder at ${m.reorderLevel}) Ã¢â‚¬Â¢ Batch ${m.batchNo}",
                            type: AlertType.warning,
                            icon: Icons.inventory_2_outlined,
                            severity: m.quantity == 0
                                ? 3
                                : (m.quantity < m.reorderLevel / 2 ? 2 : 1),
                            timestamp: DateTime.now().subtract(
                              Duration(minutes: m.quantity * 5),
                            ),
                            onTap: () =>
                                _handleAlertTap(context, 'low_stock', m),
                          ),
                        ),
                        ...nearExpiry.map((m) {
                          final daysUntilExpiry = m.expiry
                              .difference(DateTime.now())
                              .inDays;
                          return AlertCard(
                            title: "Expiring Soon: ${m.name}",
                            message:
                                "Expires in $daysUntilExpiry days (${DateFormat('yyyy-MM-dd').format(m.expiry)}) Ã¢â‚¬Â¢ Batch ${m.batchNo}",
                            type: daysUntilExpiry <= 7
                                ? AlertType.critical
                                : AlertType.warning,
                            icon: Icons.timer_outlined,
                            severity: daysUntilExpiry <= 7
                                ? 3
                                : (daysUntilExpiry <= 14 ? 2 : 1),
                            timestamp: m.expiry.subtract(
                              Duration(days: daysUntilExpiry),
                            ),
                            onTap: () => _handleAlertTap(context, 'expiry', m),
                          );
                        }),
                      ],
                      emptyWidget: const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: "All Systems Good",
                        message:
                            "No stock alerts at the moment. Everything is running smoothly!",
                      ),
                    ),
                    _enhancedAlertPanel(
                      context: context,
                      title: "Recent Activity",
                      width: panelWidth,
                      alerts: recentSales
                          .take(8)
                          .map(
                            (sale) => AlertCard(
                              title: "Sale: ${sale.id}",
                              message:
                                  "${sale.lines.length} items sold Ã¢â‚¬Â¢ Customer: ${sale.customer} Ã¢â‚¬Â¢ Birr ${sale.total.toStringAsFixed(2)}",
                              type: AlertType.success,
                              icon: Icons.receipt_long_outlined,
                              timestamp: sale.date,
                              severity: sale.total > 1000 ? 2 : 1,
                              onTap: () =>
                                  _handleAlertTap(context, 'sale', sale),
                            ),
                          )
                          .toList(),
                      emptyWidget: const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: "No Sales Today",
                        message:
                            "Sales will appear here after checkout in POS.",
                      ),
                    ),
                    _enhancedDashboardPanel(
                      context: context,
                      title: "Quick Stats",
                      width: panelWidth,
                      stats: [
                        _QuickStat(
                          "Total Medicines",
                          "${s.medicines.length}",
                          Icons.medication,
                          Colors.blue,
                        ),
                        _QuickStat(
                          "Active Suppliers",
                          "${s.suppliers.length}",
                          Icons.business,
                          Colors.green,
                        ),
                        _QuickStat(
                          "Categories",
                          "${s.categories.length}",
                          Icons.category,
                          Colors.orange,
                        ),
                        _QuickStat(
                          "Today Transactions",
                          "${s.sales.where((sale) => sale.date.day == DateTime.now().day).length}",
                          Icons.point_of_sale,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _enhancedAlertPanel({
    required BuildContext context,
    required String title,
    required double width,
    required List<AlertCard> alerts,
    required Widget emptyWidget,
  }) {
    return SizedBox(
      width: width,
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${alerts.length}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty) emptyWidget else Column(children: alerts),
          ],
        ),
      ),
    );
  }

  Widget _enhancedDashboardPanel({
    required BuildContext context,
    required String title,
    required double width,
    required List<_QuickStat> stats,
  }) {
    return SizedBox(
      width: width,
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...stats.map(
              (stat) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuickStatWidget(stat: stat),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAlertTap(
    BuildContext context,
    String type,
    dynamic data,
  ) async {
    switch (type) {
      case 'low_stock':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Low stock alert: ${data.name}'),
            action: SnackBarAction(
              label: 'View Details',
              onPressed: () {
                // Navigate to inventory with filter
              },
            ),
          ),
        );
        break;
      case 'expiry':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expiry alert: ${data.name}'),
            action: SnackBarAction(
              label: 'View Details',
              onPressed: () {
                // Navigate to inventory with filter
              },
            ),
          ),
        );
        break;
      case 'sale':
        if (data is SaleRecord) {
          await openSaleReceiptPreview(context, data);
        }
        break;
    }
  }
}

class _QuickStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat(this.label, this.value, this.icon, this.color);
}

class _QuickStatWidget extends StatefulWidget {
  final _QuickStat stat;

  const _QuickStatWidget({required this.stat});

  @override
  State<_QuickStatWidget> createState() => _QuickStatWidgetState();
}

class _QuickStatWidgetState extends State<_QuickStatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.stat.color.withValues(alpha: 0.1),
                widget.stat.color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: widget.stat.color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Transform.scale(
                scale: _animation.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.stat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    widget.stat.icon,
                    color: widget.stat.color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        widget.stat.value,
                        key: ValueKey(widget.stat.value),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: widget.stat.color,
                            ),
                      ),
                    ),
                    Text(
                      widget.stat.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
