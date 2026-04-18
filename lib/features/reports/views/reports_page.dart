import "dart:io";
import "dart:typed_data";

import "package:csv/csv.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:path_provider/path_provider.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "package:provider/provider.dart";

import "../../../core/models/models.dart";
import "../../../core/state/app_state.dart";
import "../../../shared/helpers/receipt_preview_helper.dart";
import "../../../shared/widgets/ui_kit.dart";

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with TickerProviderStateMixin {
  static const List<String> _periodOptions = [
    "Today",
    "This Week",
    "This Month",
    "This Year",
    "All Time",
  ];
  static const List<String> _reportOptions = [
    "Overview",
    "Sales",
    "Inventory",
    "Financial",
    "Expiry",
  ];

  late AnimationController _animationController;
  late List<Animation<double>> _animations;
  final NumberFormat _currency = NumberFormat.currency(
    symbol: "ETB ",
    decimalDigits: 2,
  );
  String _selectedPeriod = "This Month";
  String _selectedReport = "Overview";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animations = List.generate(6, (index) {
      return CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.08,
          0.5 + index * 0.08,
          curve: Curves.easeOutCubic,
        ),
      );
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final snapshot = _buildSnapshot(state);

    return PageSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1280;

          final analyticsColumn = Column(
            children: [
              _buildTrendCard(context, snapshot),
              const SizedBox(height: 18),
              _buildCategoryCard(context, snapshot),
              const SizedBox(height: 18),
              _buildRecentSalesCard(context, snapshot),
            ],
          );

          final operationsColumn = Column(
            children: [
              _buildOperationalFocusCard(context, snapshot),
              const SizedBox(height: 18),
              _buildReportModulesCard(context, snapshot),
              const SizedBox(height: 18),
              _buildExportCenter(context, snapshot),
            ],
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(context, state, snapshot),
                const SizedBox(height: 18),
                _buildMetricGrid(context, snapshot),
                const SizedBox(height: 18),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: analyticsColumn),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: operationsColumn),
                    ],
                  )
                else
                  Column(
                    children: [
                      analyticsColumn,
                      const SizedBox(height: 18),
                      operationsColumn,
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  _ReportSnapshot _buildSnapshot(AppState state) {
    final sales = _salesForSelectedPeriod(state.sales);
    final purchases = state.purchases.where((purchase) {
      if (_selectedPeriod == "All Time") {
        return true;
      }
      return !purchase.date.isBefore(_periodStart(DateTime.now()));
    }).toList();

    final revenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final cost = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.qty * purchase.unitCost,
    );
    final profit = revenue - cost;
    final unitsSold = sales.fold<int>(
      0,
      (sum, sale) =>
          sum + sale.lines.fold<int>(0, (lineSum, line) => lineSum + line.qty),
    );

    return _ReportSnapshot(
      state: state,
      sales: sales,
      purchases: purchases,
      revenue: revenue,
      cost: cost,
      profit: profit,
      unitsSold: unitsSold,
      trend: _buildSalesTrend(sales),
      categories: _buildCategoryMix(state.medicines),
      topProducts: _buildTopProducts(sales),
      lowStockItems: state.medicines
          .where((medicine) => medicine.isLowStock)
          .toList(),
      nearExpiryItems: state.medicines
          .where((medicine) => medicine.isNearExpiry)
          .toList(),
    );
  }

  DateTime _periodStart(DateTime now) {
    switch (_selectedPeriod) {
      case "Today":
        return DateTime(now.year, now.month, now.day);
      case "This Week":
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
      case "This Month":
        return DateTime(now.year, now.month);
      case "This Year":
        return DateTime(now.year);
      case "All Time":
        return DateTime(2000);
      default:
        return DateTime(now.year, now.month);
    }
  }

  List<SaleRecord> _salesForSelectedPeriod(List<SaleRecord> sales) {
    if (_selectedPeriod == "All Time") {
      return [...sales]..sort((a, b) => b.date.compareTo(a.date));
    }

    final start = _periodStart(DateTime.now());
    return sales.where((sale) => !sale.date.isBefore(start)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<_TrendPoint> _buildSalesTrend(List<SaleRecord> sales) {
    final now = DateTime.now();
    final formatter = DateFormat("EEE");
    final points = <_TrendPoint>[];

    for (var offset = 6; offset >= 0; offset--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: offset));
      final value = sales
          .where(
            (sale) =>
                sale.date.year == day.year &&
                sale.date.month == day.month &&
                sale.date.day == day.day,
          )
          .fold<double>(0, (sum, sale) => sum + sale.total);
      points.add(_TrendPoint(label: formatter.format(day), value: value));
    }

    return points;
  }

  List<_CategorySlice> _buildCategoryMix(List<Medicine> medicines) {
    final counts = <String, int>{};
    for (final medicine in medicines) {
      counts.update(medicine.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final palette = <Color>[
      const Color(0xFF145F63),
      const Color(0xFF0F766E),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const [
        _CategorySlice(
          label: "No Data",
          count: 0,
          ratio: 0,
          color: Color(0xFF94A3B8),
        ),
      ];
    }

    return entries.asMap().entries.map((entry) {
      return _CategorySlice(
        label: entry.value.key,
        count: entry.value.value,
        ratio: total == 0 ? 0 : entry.value.value / total,
        color: palette[entry.key % palette.length],
      );
    }).toList();
  }

  List<_TopProduct> _buildTopProducts(List<SaleRecord> sales) {
    final totals = <String, _TopProductAccumulator>{};
    for (final sale in sales) {
      for (final line in sale.lines) {
        final product = totals.putIfAbsent(
          line.name,
          () => _TopProductAccumulator(name: line.name),
        );
        product.units += line.qty;
        product.revenue += line.total;
      }
    }

    return totals.values
        .map(
          (item) => _TopProduct(
            name: item.name,
            units: item.units,
            revenue: item.revenue,
          ),
        )
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  Widget _buildHero(
    BuildContext context,
    AppState state,
    _ReportSnapshot snapshot,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11273D), Color(0xFF164C63), Color(0xFF0F766E)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2211273D),
            blurRadius: 30,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Executive Reporting Center",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Track revenue, stock exposure, expiry risk, and transaction flow in one clean corporate reporting workspace.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSelectorChip(
                    context,
                    icon: Icons.calendar_month_outlined,
                    value: _selectedPeriod,
                    options: _periodOptions,
                    onChanged: (value) =>
                        setState(() => _selectedPeriod = value),
                  ),
                  _buildSelectorChip(
                    context,
                    icon: Icons.summarize_outlined,
                    value: _selectedReport,
                    options: _reportOptions,
                    onChanged: (value) =>
                        setState(() => _selectedReport = value),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildHeroPill(label: "Company", value: state.companyName),
              _buildHeroPill(
                label: "Transactions",
                value: "${snapshot.sales.length}",
              ),
              _buildHeroPill(
                label: "Units Sold",
                value: "${snapshot.unitsSold}",
              ),
              _buildHeroPill(
                label: "Net Position",
                value: _currency.format(snapshot.profit),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorChip(
    BuildContext context, {
    required IconData icon,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: Colors.white,
              items: options
                  .map(
                    (option) =>
                        DropdownMenuItem(value: option, child: Text(option)),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(BuildContext context, _ReportSnapshot snapshot) {
    final metrics = [
      _ReportMetric(
        "Revenue",
        _currency.format(snapshot.revenue),
        const Color(0xFF0F766E),
        Icons.payments_outlined,
        "${snapshot.sales.length} sales",
      ),
      _ReportMetric(
        "Operational Cost",
        _currency.format(snapshot.cost),
        const Color(0xFFB45309),
        Icons.inventory_2_outlined,
        "${snapshot.purchases.length} purchases",
      ),
      _ReportMetric(
        "Net Profit",
        _currency.format(snapshot.profit),
        snapshot.profit >= 0
            ? const Color(0xFF1D4ED8)
            : const Color(0xFFB42318),
        Icons.account_balance_outlined,
        snapshot.profit >= 0 ? "Positive margin" : "Negative margin",
      ),
      _ReportMetric(
        "Expiry Risk",
        "${snapshot.nearExpiryItems.length} items",
        const Color(0xFFDC6803),
        Icons.timer_outlined,
        "Monitor expiring stock",
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics.asMap().entries.map((entry) {
        return _ExecutiveMetricCard(
          animation: _animations[entry.key],
          metric: entry.value,
        );
      }).toList(),
    );
  }

  Widget _buildTrendCard(BuildContext context, _ReportSnapshot snapshot) {
    final maxValue = snapshot.trend.fold<double>(
      0,
      (sum, item) => item.value > sum ? item.value : sum,
    );
    final peak = snapshot.trend.isEmpty
        ? null
        : snapshot.trend.reduce((a, b) => a.value >= b.value ? a : b);

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: "Revenue Trend",
            subtitle: "Last 7 days of realized sales",
            badge: peak == null
                ? "No sales"
                : "Peak ${peak.label} ${_currency.format(peak.value)}",
          ),
          const SizedBox(height: 18),
          Container(
            height: 260,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD8E7ED)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: snapshot.trend.map((item) {
                final ratio = maxValue == 0 ? 0.0 : item.value / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Text(
                          item.value == 0
                              ? "0"
                              : _currency
                                    .format(item.value)
                                    .replaceAll("ETB ", ""),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF496273),
                              ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              height: 32 + (ratio * 136),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF2C7FB8),
                                    Color(0xFF0F766E),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x220F766E),
                                    blurRadius: 12,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, _ReportSnapshot snapshot) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: "Inventory Composition",
            subtitle: "Current category mix across stocked items",
            badge: "${snapshot.state.medicines.length} items",
          ),
          const SizedBox(height: 18),
          ...snapshot.categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: category.ratio.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE7EEF3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          category.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 74,
                    child: Text(
                      "${category.count} • ${(category.ratio * 100).toStringAsFixed(0)}%",
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5A6E7E),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentSalesCard(BuildContext context, _ReportSnapshot snapshot) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: "Recent Transactions",
            subtitle: "Tap any receipt row to open the PDF document preview",
            badge: "${snapshot.sales.length} in scope",
          ),
          const SizedBox(height: 18),
          if (snapshot.sales.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: "No transactions for this period",
              message: "Complete a sale to populate the reporting timeline.",
            )
          else
            Column(
              children: snapshot.sales.take(6).map((sale) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openSaleReceiptPreview(context, sale),
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD9E7EE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0F766E,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sale.id,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${DateFormat('dd MMM yyyy, HH:mm').format(sale.date)} • ${sale.customer}",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF607281),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currency.format(sale.total),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F766E),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${sale.lines.length} lines",
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: const Color(0xFF607281)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOperationalFocusCard(
    BuildContext context,
    _ReportSnapshot snapshot,
  ) {
    final topProduct = snapshot.topProducts.isEmpty
        ? null
        : snapshot.topProducts.first;

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: "Operational Focus",
            subtitle: "Immediate attention areas from inventory and sales flow",
            badge: _selectedReport,
          ),
          const SizedBox(height: 18),
          _buildInsightRow(
            context,
            color: const Color(0xFF0F766E),
            title: "Top performer",
            value: topProduct == null
                ? "No sales yet"
                : "${topProduct.name} • ${_currency.format(topProduct.revenue)}",
          ),
          const SizedBox(height: 14),
          _buildInsightRow(
            context,
            color: const Color(0xFFDC6803),
            title: "Near expiry exposure",
            value: "${snapshot.nearExpiryItems.length} products expiring soon",
          ),
          const SizedBox(height: 14),
          _buildInsightRow(
            context,
            color: const Color(0xFFB42318),
            title: "Low stock exposure",
            value:
                "${snapshot.lowStockItems.length} products below reorder level",
          ),
          const SizedBox(height: 14),
          _buildInsightRow(
            context,
            color: const Color(0xFF1D4ED8),
            title: "Average transaction",
            value: snapshot.sales.isEmpty
                ? _currency.format(0)
                : _currency.format(snapshot.revenue / snapshot.sales.length),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    BuildContext context, {
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF607281),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportModulesCard(
    BuildContext context,
    _ReportSnapshot snapshot,
  ) {
    final modules = [
      _ReportModule(
        title: "Inventory Review",
        subtitle: "${snapshot.state.medicines.length} items in stock file",
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF1D4ED8),
        onTap: () => _showInventoryReport(context, snapshot.state),
      ),
      _ReportModule(
        title: "Expiry Watchlist",
        subtitle: "${snapshot.nearExpiryItems.length} expiring items",
        icon: Icons.event_busy_outlined,
        color: const Color(0xFFDC6803),
        onTap: () => _showExpiryReport(context, snapshot.state),
      ),
      _ReportModule(
        title: "Sales Ledger",
        subtitle: "${snapshot.sales.length} transactions in period",
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF0F766E),
        onTap: () => _showSalesReport(context, snapshot.state),
      ),
      _ReportModule(
        title: "Financial Summary",
        subtitle: "Revenue, cost, and margin review",
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF7C3AED),
        onTap: () => _showFinancialReport(context, snapshot.state),
      ),
    ];

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: "Detailed Modules",
            subtitle: "Open focused report dialogs for operational review",
            badge: "${modules.length} modules",
          ),
          const SizedBox(height: 18),
          ...modules.map((module) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportModuleTile(module: module),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExportCenter(BuildContext context, _ReportSnapshot snapshot) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: "Export Center",
            subtitle: "Deliver report outputs as structured business documents",
            badge: _selectedPeriod,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _csv(context, snapshot),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text("Export CSV"),
              ),
              OutlinedButton.icon(
                onPressed: () => _pdf(snapshot),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text("Export PDF"),
              ),
              OutlinedButton.icon(
                onPressed: () => _printReport(snapshot),
                icon: const Icon(Icons.print_outlined),
                label: const Text("Print Report"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "PDF exports now include a corporate header, footer, metric summary, and transaction tables for review or filing.",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607281)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607281),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF0F766E),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  void _showInventoryReport(BuildContext context, AppState state) {
    _showDataDialog(
      context,
      title: "Inventory Report",
      subtitle: "Current stock position across available medicines.",
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: state.medicines.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final medicine = state.medicines[index];
          return ListTile(
            title: Text(medicine.name),
            subtitle: Text("Batch ${medicine.batchNo} • ${medicine.category}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${medicine.quantity} units"),
                Text(
                  _currency.format(medicine.sellingPrice),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExpiryReport(BuildContext context, AppState state) {
    final items =
        state.medicines.where((medicine) => medicine.isNearExpiry).toList()
          ..sort((a, b) => a.expiry.compareTo(b.expiry));

    _showDataDialog(
      context,
      title: "Expiry Watchlist",
      subtitle: "Products nearest to expiry based on current stock.",
      child: items.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: "No items close to expiry",
              message: "Your current inventory is clear for the next 30 days.",
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final medicine = items[index];
                return ListTile(
                  title: Text(medicine.name),
                  subtitle: Text(
                    "Expires ${DateFormat('dd MMM yyyy').format(medicine.expiry)} • Batch ${medicine.batchNo}",
                  ),
                  trailing: Text(
                    "${medicine.expiry.difference(DateTime.now()).inDays} days",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSalesReport(BuildContext context, AppState state) {
    final sales = _salesForSelectedPeriod(state.sales);

    _showDataDialog(
      context,
      title: "Sales Ledger",
      subtitle: "Receipt list for the selected reporting period.",
      child: sales.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: "No sales available",
              message: "No completed sales match the selected period.",
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: sales.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sale = sales[index];
                return ListTile(
                  onTap: () => openSaleReceiptPreview(context, sale),
                  leading: CircleAvatar(
                    backgroundColor: const Color(
                      0xFF0F766E,
                    ).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF0F766E),
                    child: const Icon(Icons.receipt_long),
                  ),
                  title: Text(sale.id),
                  subtitle: Text(
                    "${DateFormat('dd MMM yyyy, HH:mm').format(sale.date)} • ${sale.customer}",
                  ),
                  trailing: Text(
                    _currency.format(sale.total),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showFinancialReport(BuildContext context, AppState state) {
    final snapshot = _buildSnapshot(state);

    _showDataDialog(
      context,
      title: "Financial Summary",
      subtitle: "High-level financial view for the selected reporting period.",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFinanceLine(context, "Revenue", snapshot.revenue),
          const Divider(height: 24),
          _buildFinanceLine(context, "Cost", snapshot.cost),
          const Divider(height: 24),
          _buildFinanceLine(
            context,
            "Net Profit",
            snapshot.profit,
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceLine(
    BuildContext context,
    String label,
    double value, {
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          _currency.format(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: emphasize
                ? (value >= 0
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFB42318))
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _showDataDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF607281),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: child),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Close"),
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

  Future<void> _csv(BuildContext context, _ReportSnapshot snapshot) async {
    final rows = <List<dynamic>>[
      ["Receipt", "Date", "Customer", "Cashier", "Total"],
      ...snapshot.sales.map(
        (sale) => [
          sale.id,
          DateFormat("yyyy-MM-dd HH:mm").format(sale.date),
          sale.customer,
          sale.cashier,
          sale.total.toStringAsFixed(2),
        ],
      ),
    ];

    final dir = await getApplicationDocumentsDirectory();
    final path =
        "${dir.path}/riyopharma_report_${_selectedPeriod.replaceAll(' ', '_').toLowerCase()}.csv";
    await File(path).writeAsString(const ListToCsvConverter().convert(rows));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("CSV exported: $path")));
    }
  }

  Future<void> _pdf(_ReportSnapshot snapshot) async {
    final bytes = await _buildReportPdf(snapshot);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: "Riyopharma_Report_${_selectedPeriod.replaceAll(' ', '_')}.pdf",
    );
  }

  Future<void> _printReport(_ReportSnapshot snapshot) async {
    final bytes = await _buildReportPdf(snapshot);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: "Riyopharma_Report_${_selectedPeriod.replaceAll(' ', '_')}.pdf",
    );
  }

  Future<Uint8List> _buildReportPdf(_ReportSnapshot snapshot) async {
    final doc = pw.Document(
      title: "Riyopharma Report $_selectedPeriod",
      author: snapshot.state.companyName,
      creator: "Riyopharma",
    );
    final generatedAt = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
        ),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey100),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    snapshot.state.companyName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Executive Performance Report",
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Period: $_selectedPeriod"),
                    pw.Text("View: $_selectedReport"),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey100)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Generated ${DateFormat('dd MMM yyyy HH:mm').format(generatedAt)}",
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.Text(
                "Page ${context.pageNumber} of ${context.pagesCount}",
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              children: [
                _pdfMetric("Revenue", _currency.format(snapshot.revenue)),
                pw.SizedBox(width: 18),
                _pdfMetric("Cost", _currency.format(snapshot.cost)),
                pw.SizedBox(width: 18),
                _pdfMetric("Profit", _currency.format(snapshot.profit)),
                pw.SizedBox(width: 18),
                _pdfMetric("Transactions", "${snapshot.sales.length}"),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            "Top Selling Products",
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            headers: const ["Product", "Units", "Revenue"],
            data: snapshot.topProducts.isEmpty
                ? [
                    const ["No sales data", "-", "-"],
                  ]
                : snapshot.topProducts.take(6).map((item) {
                    return [
                      item.name,
                      "${item.units}",
                      _currency.format(item.revenue),
                    ];
                  }).toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            "Recent Transactions",
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9.2),
            headers: const ["Receipt", "Date", "Customer", "Cashier", "Total"],
            data: snapshot.sales.isEmpty
                ? [
                    const ["No sales", "-", "-", "-", "-"],
                  ]
                : snapshot.sales.take(10).map((sale) {
                    return [
                      sale.id,
                      DateFormat("dd MMM yyyy HH:mm").format(sale.date),
                      sale.customer,
                      sale.cashier,
                      _currency.format(sale.total),
                    ];
                  }).toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _pdfPanel(
                  title: "Inventory Risks",
                  lines: [
                    "Low stock items: ${snapshot.lowStockItems.length}",
                    "Near expiry items: ${snapshot.nearExpiryItems.length}",
                    "Inventory categories: ${snapshot.categories.length}",
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _pdfPanel(
                  title: "Reporting Notes",
                  lines: [
                    "This report summarizes the selected reporting window.",
                    "Revenue is based on completed sales records.",
                    "Cost is based on purchase records captured in the same period.",
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfPanel({required String title, required List<String> lines}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          ...lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                line,
                style: const pw.TextStyle(
                  fontSize: 9.2,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveMetricCard extends StatelessWidget {
  const _ExecutiveMetricCard({required this.animation, required this.metric});

  final Animation<double> animation;
  final _ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 24),
            child: SizedBox(
              width: 290,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFD9E7EE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: metric.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(metric.icon, color: metric.color),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: metric.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            metric.footer,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: metric.color,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      metric.value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: metric.color,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      metric.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReportModuleTile extends StatelessWidget {
  const _ReportModuleTile({required this.module});

  final _ReportModule module;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: module.onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: module.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(module.icon, color: module.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF607281),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: module.color),
          ],
        ),
      ),
    );
  }
}

class _ReportSnapshot {
  const _ReportSnapshot({
    required this.state,
    required this.sales,
    required this.purchases,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.unitsSold,
    required this.trend,
    required this.categories,
    required this.topProducts,
    required this.lowStockItems,
    required this.nearExpiryItems,
  });

  final AppState state;
  final List<SaleRecord> sales;
  final List<PurchaseRecord> purchases;
  final double revenue;
  final double cost;
  final double profit;
  final int unitsSold;
  final List<_TrendPoint> trend;
  final List<_CategorySlice> categories;
  final List<_TopProduct> topProducts;
  final List<Medicine> lowStockItems;
  final List<Medicine> nearExpiryItems;
}

class _ReportMetric {
  const _ReportMetric(
    this.title,
    this.value,
    this.color,
    this.icon,
    this.footer,
  );

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String footer;
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class _CategorySlice {
  const _CategorySlice({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int count;
  final double ratio;
  final Color color;
}

class _TopProduct {
  const _TopProduct({
    required this.name,
    required this.units,
    required this.revenue,
  });

  final String name;
  final int units;
  final double revenue;
}

class _TopProductAccumulator {
  _TopProductAccumulator({required this.name});

  final String name;
  int units = 0;
  double revenue = 0;
}

class _ReportModule {
  const _ReportModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
