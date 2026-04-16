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
                Text(
                  "Sell: Birr ${exact.sellingPrice.toStringAsFixed(2)}",
                ),
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
              "Scan here first or type — opens details when the code matches a product.",
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
              ...matches.take(8).map(
                    (m) => ListTile(
                      dense: true,
                      title: Text(m.name),
                      subtitle: Text(
                        "Barcode ${m.barcode} • Qty ${m.quantity}",
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
    final showQuickBarcode = user != null &&
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
                      value: "Birr ${s.todaySales.toStringAsFixed(2)}",
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
                              "Birr ${sale.total.toStringAsFixed(2)}",
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
                                            "Birr ${m.purchasePrice.toStringAsFixed(2)}",
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "Birr ${m.sellingPrice.toStringAsFixed(2)}",
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
            width: MediaQuery.sizeOf(ctx).width * 0.92 > 560
                ? 560
                : MediaQuery.sizeOf(ctx).width * 0.92,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.62,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: n,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: g,
                      decoration: const InputDecoration(labelText: "Generic"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: b,
                      decoration: const InputDecoration(labelText: "Batch"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: q,
                      decoration: const InputDecoration(labelText: "Qty"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reorder,
                      decoration: const InputDecoration(
                        labelText: "Reorder Level",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: buy,
                      decoration: const InputDecoration(
                        labelText: "Purchase Price",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sell,
                      decoration: const InputDecoration(
                        labelText: "Selling Price",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bar,
                      decoration: const InputDecoration(labelText: "Barcode"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: supplier,
                      items: s.suppliers
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialog(() => supplier = v ?? supplier),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: category,
                      items: s.categories
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialog(() => category = v ?? category),
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
    final s = context.watch<AppState>();
    final list = s.filterMedicines(query: search.text);
    final total = cart.entries.fold<double>(
      0,
      (sum, e) =>
          sum +
          s.medicines.firstWhere((m) => m.id == e.key).sellingPrice * e.value,
    );
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
            final code = _barcodeBuffer;
            final app = context.read<AppState>();
            final exact = app.findByBarcode(code);
            setState(() {
              if (exact != null && exact.quantity > 0) {
                cart[exact.id] = (cart[exact.id] ?? 0) + 1;
                search.clear();
              } else {
                search.text = code;
              }
            });
          }
          _barcodeBuffer = "";
          return;
        }
        final label = event.character ?? "";
        if (label.isNotEmpty && RegExp(r"[0-9A-Za-z-]").hasMatch(label)) {
          _barcodeBuffer += label;
        }
      },
      child: PageSurface(
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
                              "Scan adds a matched item to the cart; otherwise search filters the list.",
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
                      labelText:
                          "Search medicine (name/generic/barcode); scanner ready",
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
                                  "Try a different keyword or scan a barcode — exact codes add to the cart.",
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
                                    "Stock ${m.quantity} • Birr ${m.sellingPrice.toStringAsFixed(2)}",
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
                                  "${e.value} × Birr ${med.sellingPrice.toStringAsFixed(2)}",
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
                        "Birr ${total.toStringAsFixed(2)}",
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
          Text("Sales report: Birr ${totalSales.toStringAsFixed(2)}"),
          Text(
            "Profit/Loss: Birr ${(totalSales - totalPurchase).toStringAsFixed(2)}",
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
            child: _SimpleMaster(title: "Suppliers", kind: "supplier", values: s.suppliers),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SimpleMaster(title: "Customers", kind: "customer", values: s.customers),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SimpleMaster(title: "Categories", kind: "category", values: s.categories),
          ),
        ],
      ),
    );
  }
}

class _SimpleMaster extends StatefulWidget {
  const _SimpleMaster({required this.title, required this.kind, required this.values});
  final String title;
  final String kind;
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
                  widget.kind,
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
                    .map((v) => ListTile(
                          title: Text(v),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              context.read<AppState>().removeMasterValue(
                                widget.kind,
                                widget.values,
                                v,
                              );
                            },
                          ),
                        ))
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
                if (state.currentUser?.role == UserRole.admin) ...[
                  Ui.sectionGap,
                  Text(
                    "LAN Server Initialization",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ServerSyncPanel(),
                  Ui.sectionGap,
                  Text(
                    "User Management",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _UserManagementPanel(),
                ],
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

class _UserManagementPanel extends StatelessWidget {
  const _UserManagementPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: () => _openUserForm(context, null),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text("Add User"),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.users.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = state.users[i];
            return ListTile(
              title: Text(u.username),
              subtitle: Text("Role: ${u.role.name} • PIN: ${u.pin}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _openUserForm(context, u),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: state.currentUser?.id == u.id
                        ? null
                        : () => state.deleteUser(u.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openUserForm(BuildContext context, AppUser? existing) async {
    final state = context.read<AppState>();
    final userCtrl = TextEditingController(text: existing?.username ?? "");
    final pinCtrl = TextEditingController(text: existing?.pin ?? "");
    UserRole role = existing?.role ?? UserRole.cashier;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? "Add User" : "Edit User"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: "PIN"),
              ),
              const SizedBox(height: 10),
              DropdownButton<UserRole>(
                isExpanded: true,
                value: role,
                items: UserRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialog(() => role = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                if (userCtrl.text.trim().isEmpty || pinCtrl.text.trim().isEmpty) return;
                final u = AppUser(
                  id: existing?.id ?? "USR-${DateTime.now().microsecondsSinceEpoch}",
                  username: userCtrl.text.trim(),
                  pin: pinCtrl.text.trim(),
                  role: role,
                );
                if (existing == null) {
                  state.addUser(u);
                } else {
                  state.updateUser(u);
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSyncPanel extends StatefulWidget {
  const _ServerSyncPanel();

  @override
  State<_ServerSyncPanel> createState() => _ServerSyncPanelState();
}

class _ServerSyncPanelState extends State<_ServerSyncPanel> {
  final ipCtrl = TextEditingController();
  final portCtrl = TextEditingController(text: "3000");
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final net = state.network;
    
    final isConnected = net.serverIp != null;
    final isLoggedIn = net.token != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isConnected) ...[
          Text("Connected to: ${net.serverIp}:${net.serverPort}"),
          Text("Status: ${isLoggedIn ? 'Authenticated' : 'Requires Login'}"),
          const SizedBox(height: 12),
        ],
        if (!isLoggedIn) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(labelText: "Server IP"),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(labelText: "Port"),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final ok = await net.connectManual(ipCtrl.text.trim(), int.tryParse(portCtrl.text.trim()) ?? 3000);
                  if (ok && mounted) setState(() {});
                },
                child: const Text("Connect"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final ip = await net.discoverServer();
              if (ip != null && mounted) {
                setState(() => ipCtrl.text = ip);
              }
            },
            icon: const Icon(Icons.radar),
            label: const Text("Auto-detect LAN Server"),
          ),
          const SizedBox(height: 12),
          if (isConnected) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(labelText: "Sync User"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Sync Password"),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final ok = await net.login(userCtrl.text.trim(), passCtrl.text.trim());
                    if (ok && mounted) setState(() {});
                  },
                  child: const Text("Login"),
                ),
              ],
            ),
          ],
        ],
        if (isLoggedIn) ...[
          OutlinedButton.icon(
            onPressed: () {
              net.token = null; // Logout
              setState(() {});
            },
            icon: const Icon(Icons.logout),
            label: const Text("Disconnect Sync"),
          ),
        ]
      ],
    );
  }
}


