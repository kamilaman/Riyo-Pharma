import "dart:io";

import "package:csv/csv.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/intl.dart";
import "package:path_provider/path_provider.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "package:provider/provider.dart";

import "../app_state.dart";
import "../models.dart";
import "../receipt_service.dart";
import "ui_kit.dart";

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
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
                Ui.sectionGap,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatCard(
                      title: "Total Stock Value",
                      value: "Rs ${s.totalStockValue.toStringAsFixed(2)}",
                      icon: Icons.account_balance_wallet_outlined,
                      tint: const Color(0xFF2563EB),
                    ),
                    StatCard(
                      title: "Low Stock Items",
                      value: "${s.lowStockCount}",
                      icon: Icons.warning_amber_outlined,
                      tint: const Color(0xFFF59E0B),
                      footer: "Based on reorder level",
                    ),
                    StatCard(
                      title: "Near Expiry",
                      value: "${s.nearExpiryCount}",
                      icon: Icons.timer_outlined,
                      tint: const Color(0xFFEF4444),
                      footer: "Next 30 days",
                    ),
                    StatCard(
                      title: "Today's Sales",
                      value: "Rs ${s.todaySales.toStringAsFixed(2)}",
                      icon: Icons.payments_outlined,
                      tint: const Color(0xFF10B981),
                    ),
                  ],
                ),
                Ui.sectionGap,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _dashboardPanel(
                      context: context,
                      title: "Low stock",
                      width: panelWidth,
                      empty: low.isEmpty,
                      emptyWidget: const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: "All good",
                        message: "No low-stock items right now.",
                      ),
                      list: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: low.length.clamp(0, 12),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = low[i];
                          return ListTile(
                            title: Text(m.name),
                            subtitle: Text(
                              "Batch ${m.batchNo} • Reorder ${m.reorderLevel}",
                            ),
                            trailing: Text(
                              "${m.quantity}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _dashboardPanel(
                      context: context,
                      title: "Near expiry",
                      width: panelWidth,
                      empty: nearExpiry.isEmpty,
                      emptyWidget: const EmptyState(
                        icon: Icons.schedule_outlined,
                        title: "No expiry alerts",
                        message:
                            "Nothing is nearing expiry in the next 30 days.",
                      ),
                      list: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: nearExpiry.length.clamp(0, 12),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = nearExpiry[i];
                          return ListTile(
                            title: Text(m.name),
                            subtitle: Text("Batch ${m.batchNo}"),
                            trailing: Text(
                              DateFormat("yyyy-MM-dd").format(m.expiry),
                            ),
                          );
                        },
                      ),
                    ),
                    _dashboardPanel(
                      context: context,
                      title: "Recent sales",
                      width: panelWidth,
                      empty: recentSales.isEmpty,
                      emptyWidget: const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: "No sales yet",
                        message:
                            "Sales will appear here after checkout in POS.",
                      ),
                      list: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentSales.length.clamp(0, 10),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final sale = recentSales[i];
                          return ListTile(
                            title: Text(sale.id),
                            subtitle: Text(
                              DateFormat("yyyy-MM-dd HH:mm").format(sale.date),
                            ),
                            trailing: Text(
                              "Rs ${sale.total.toStringAsFixed(2)}",
                            ),
                          );
                        },
                      ),
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

  Widget _dashboardPanel({
    required BuildContext context,
    required String title,
    required double width,
    required bool empty,
    required Widget emptyWidget,
    required Widget list,
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
            const SizedBox(height: 10),
            if (empty) emptyWidget else list,
          ],
        ),
      ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
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
    keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = state.filterMedicines(query: search.text);
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
            search.text = _barcodeBuffer;
            setState(() {});
          }
          _barcodeBuffer = "";
          return;
        }
        final label = event.character ?? "";
        if (label.isNotEmpty && RegExp(r"[0-9A-Za-z-]").hasMatch(label)) {
          _barcodeBuffer += label;
        }
      },
      child: Padding(
        padding: Ui.pagePadding,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Ui.pageTitle(
                    context,
                    "Inventory",
                    subtitle: "Search, scan barcode, and manage stock items.",
                  ),
                ),
                Ui.rowGap,
                FilledButton.icon(
                  onPressed: () => _openForm(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text("Add medicine"),
                ),
              ],
            ),
            Ui.sectionGap,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: "Search / Barcode (scanner supported)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() => search.clear()),
                  icon: const Icon(Icons.close),
                  label: const Text("Clear"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ContentCard(
                padding: const EdgeInsets.all(0),
                child: rows.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: "No medicines",
                        message:
                            "Add medicines or scan/search by barcode to get started.",
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 980),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowHeight: 46,
                              columns: const [
                                DataColumn(label: Text("Name")),
                                DataColumn(label: Text("Generic")),
                                DataColumn(label: Text("Batch")),
                                DataColumn(label: Text("Expiry")),
                                DataColumn(label: Text("Qty")),
                                DataColumn(label: Text("Buy")),
                                DataColumn(label: Text("Sell")),
                                DataColumn(label: Text("Supplier")),
                                DataColumn(label: Text("Category")),
                                DataColumn(label: Text("Barcode")),
                                DataColumn(label: Text("")),
                              ],
                              rows: rows
                                  .map(
                                    (m) => DataRow(
                                      cells: [
                                        DataCell(Text(m.name)),
                                        DataCell(Text(m.genericName)),
                                        DataCell(Text(m.batchNo)),
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              "yyyy-MM-dd",
                                            ).format(m.expiry),
                                          ),
                                        ),
                                        DataCell(Text("${m.quantity}")),
                                        DataCell(
                                          Text(
                                            "Rs ${m.purchasePrice.toStringAsFixed(2)}",
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "Rs ${m.sellingPrice.toStringAsFixed(2)}",
                                          ),
                                        ),
                                        DataCell(Text(m.supplier)),
                                        DataCell(Text(m.category)),
                                        DataCell(Text(m.barcode)),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                tooltip: "Edit",
                                                onPressed: () =>
                                                    _openForm(context, m),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: "Delete",
                                                onPressed: () => context
                                                    .read<AppState>()
                                                    .deleteMedicine(m.id),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, Medicine? existing) async {
    final s = context.read<AppState>();
    final n = TextEditingController(text: existing?.name ?? "");
    final g = TextEditingController(text: existing?.genericName ?? "");
    final b = TextEditingController(text: existing?.batchNo ?? "");
    final q = TextEditingController(text: "${existing?.quantity ?? 0}");
    final buy = TextEditingController(text: "${existing?.purchasePrice ?? 0}");
    final sell = TextEditingController(text: "${existing?.sellingPrice ?? 0}");
    final bar = TextEditingController(text: existing?.barcode ?? "");
    final reorder = TextEditingController(
      text: "${existing?.reorderLevel ?? 10}",
    );
    DateTime exp =
        existing?.expiry ?? DateTime.now().add(const Duration(days: 90));
    String supplier = existing?.supplier ?? s.suppliers.first;
    String category = existing?.category ?? s.categories.first;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? "Add Medicine" : "Edit Medicine"),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                TextField(
                  controller: g,
                  decoration: const InputDecoration(labelText: "Generic"),
                ),
                TextField(
                  controller: b,
                  decoration: const InputDecoration(labelText: "Batch"),
                ),
                TextField(
                  controller: q,
                  decoration: const InputDecoration(labelText: "Qty"),
                ),
                TextField(
                  controller: reorder,
                  decoration: const InputDecoration(labelText: "Reorder Level"),
                ),
                TextField(
                  controller: buy,
                  decoration: const InputDecoration(
                    labelText: "Purchase Price",
                  ),
                ),
                TextField(
                  controller: sell,
                  decoration: const InputDecoration(labelText: "Selling Price"),
                ),
                TextField(
                  controller: bar,
                  decoration: const InputDecoration(labelText: "Barcode"),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: supplier,
                  items: s.suppliers
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialog(() => supplier = v ?? supplier),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: category,
                  items: s.categories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialog(() => category = v ?? category),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Expiry: ${DateFormat("yyyy-MM-dd").format(exp)}",
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: exp,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setDialog(() => exp = d);
                        }
                      },
                      child: const Text("Pick"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final med = Medicine(
                  id:
                      existing?.id ??
                      "MED-${DateTime.now().microsecondsSinceEpoch}",
                  name: n.text,
                  genericName: g.text,
                  batchNo: b.text,
                  expiry: exp,
                  quantity: int.tryParse(q.text) ?? 0,
                  purchasePrice: double.tryParse(buy.text) ?? 0,
                  sellingPrice: double.tryParse(sell.text) ?? 0,
                  supplier: supplier,
                  category: category,
                  barcode: bar.text,
                  reorderLevel: int.tryParse(reorder.text) ?? 10,
                );
                if (existing == null) {
                  s.addMedicine(med);
                } else {
                  s.updateMedicine(med);
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}

class PosPage extends StatefulWidget {
  const PosPage({super.key});
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final Map<String, int> cart = {};
  final search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.filterMedicines(query: search.text);
    final total = cart.entries.fold<double>(
      0,
      (sum, e) =>
          sum +
          s.medicines.firstWhere((m) => m.id == e.key).sellingPrice * e.value,
    );
    return PageSurface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Ui.pageTitle(
                        context,
                        "Sales / POS",
                        subtitle:
                            "Fast billing with search and barcode-friendly workflow.",
                      ),
                    ),
                    Ui.rowGap,
                    OutlinedButton.icon(
                      onPressed: cart.isEmpty
                          ? null
                          : () => setState(cart.clear),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text("Clear cart"),
                    ),
                  ],
                ),
                Ui.sectionGap,
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    labelText: "Search medicine (name/generic/barcode)",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Ui.itemGap,
                Expanded(
                  child: ContentCard(
                    padding: const EdgeInsets.all(0),
                    child: list.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_outlined,
                            title: "No matches",
                            message:
                                "Try a different keyword or scan a barcode into the search box.",
                          )
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final m = list[i];
                              return ListTile(
                                title: Text(m.name),
                                subtitle: Text(
                                  "Stock ${m.quantity} • Rs ${m.sellingPrice.toStringAsFixed(2)}",
                                ),
                                trailing: FilledButton.tonalIcon(
                                  onPressed: m.quantity <= 0
                                      ? null
                                      : () => setState(
                                          () => cart[m.id] =
                                              (cart[m.id] ?? 0) + 1,
                                        ),
                                  icon: const Icon(Icons.add),
                                  label: const Text("Add"),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(),
          SizedBox(
            width: 380,
            child: ContentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cart",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: cart.isEmpty
                        ? const EmptyState(
                            icon: Icons.shopping_cart_outlined,
                            title: "Cart is empty",
                            message:
                                "Add items from the list to start billing.",
                          )
                        : ListView(
                            children: cart.entries.map((e) {
                              final med = s.medicines.firstWhere(
                                (m) => m.id == e.key,
                              );
                              return ListTile(
                                title: Text(med.name),
                                subtitle: Text(
                                  "${e.value} × Rs ${med.sellingPrice.toStringAsFixed(2)}",
                                ),
                                trailing: IconButton(
                                  tooltip: "Remove",
                                  onPressed: () => setState(() {
                                    final v = (cart[e.key] ?? 1) - 1;
                                    if (v <= 0) {
                                      cart.remove(e.key);
                                    } else {
                                      cart[e.key] = v;
                                    }
                                  }),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Text("Total"),
                      const Spacer(),
                      Text(
                        "Rs ${total.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: cart.isEmpty
                        ? null
                        : () async {
                            final res = context.read<AppState>().completeSale(
                              "Walk-in Customer",
                              cart,
                            );
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(res)));
                            if (res == "OK") {
                              final sale = context.read<AppState>().sales.last;
                              final user = context
                                  .read<AppState>()
                                  .currentUser!;
                              await ReceiptService().printReceipt(
                                companyName: context
                                    .read<AppState>()
                                    .companyName,
                                cashier: user.username,
                                sale: sale,
                              );
                              if (mounted) setState(cart.clear);
                            }
                          },
                    child: const Text("Checkout & Print Receipt"),
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

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final totalSales = s.sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalPurchase = s.purchases.fold<double>(
      0,
      (sum, p) => sum + p.qty * p.unitCost,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Stock summary: ${s.medicines.length}"),
          Text("Expiry report: ${s.nearExpiryCount}"),
          Text("Sales report: Rs ${totalSales.toStringAsFixed(2)}"),
          Text(
            "Profit/Loss: Rs ${(totalSales - totalPurchase).toStringAsFixed(2)}",
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _csv(context, s),
                child: const Text("Export CSV"),
              ),
              OutlinedButton(
                onPressed: () => _pdf(s),
                child: const Text("Export PDF"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _csv(BuildContext context, AppState s) async {
    final rows = <List<dynamic>>[
      ["Name", "Qty", "Expiry"],
      ...s.medicines.map(
        (m) => [m.name, m.quantity, DateFormat("yyyy-MM-dd").format(m.expiry)],
      ),
    ];
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/pharmacore_report.csv";
    await File(path).writeAsString(const ListToCsvConverter().convert(rows));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("CSV exported: $path")));
    }
  }

  Future<void> _pdf(AppState s) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          children: s.medicines
              .map((m) => pw.Text("${m.name} | ${m.quantity}"))
              .toList(),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }
}

class MastersPage extends StatelessWidget {
  const MastersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _SimpleMaster(title: "Suppliers", values: s.suppliers),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SimpleMaster(title: "Customers", values: s.customers),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SimpleMaster(title: "Categories", values: s.categories),
          ),
        ],
      ),
    );
  }
}

class _SimpleMaster extends StatefulWidget {
  const _SimpleMaster({required this.title, required this.values});
  final String title;
  final List<String> values;
  @override
  State<_SimpleMaster> createState() => _SimpleMasterState();
}

class _SimpleMasterState extends State<_SimpleMaster> {
  final ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: "Add"),
            ),
            FilledButton(
              onPressed: () {
                context.read<AppState>().addMasterValue(
                  widget.values,
                  ctrl.text,
                );
                ctrl.clear();
              },
              child: const Text("Save"),
            ),
            Expanded(
              child: ListView(
                children: widget.values
                    .map((v) => ListTile(title: Text(v)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: () => context.read<AppState>().runAlerts(),
            child: const Text("Run local alerts"),
          ),
          const SizedBox(height: 8),
          ...s.medicines
              .where((m) => m.isLowStock || m.isNearExpiry)
              .map(
                (m) => Text(
                  "${m.name} | low:${m.isLowStock} | expiry:${m.isNearExpiry}",
                ),
              ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final company = TextEditingController(text: state.companyName);
    final printer = TextEditingController(text: state.printerName);
    return PageSurface(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ui.pageTitle(
                  context,
                  "Settings",
                  subtitle:
                      "Manage company profile, printer, backup and restore.",
                ),
                Ui.sectionGap,
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: "Company Name"),
                  onSubmitted: state.updateCompanyName,
                ),
                Ui.itemGap,
                TextField(
                  controller: printer,
                  decoration: const InputDecoration(labelText: "Printer Name"),
                  onSubmitted: state.updatePrinterName,
                ),
                Ui.sectionGap,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _backup(context),
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text("Backup DB"),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _restore(context),
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text("Restore DB"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _backup(BuildContext context) async {
    final state = context.read<AppState>();
    final docs = await getApplicationDocumentsDirectory();
    final path =
        "${docs.path}/pharmacore_backup_${DateTime.now().millisecondsSinceEpoch}.json";
    await state.backup(path);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Backup created: $path")));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ctrl = TextEditingController();
    final p = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Restore"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Backup path"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text("Restore"),
          ),
        ],
      ),
    );
    if (p == null || p.trim().isEmpty || !context.mounted) return;
    await context.read<AppState>().restore(p.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Restored")));
    }
  }
}
