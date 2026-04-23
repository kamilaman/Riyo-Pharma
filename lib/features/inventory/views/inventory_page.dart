import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";
import "dart:math" as math;

import "../../../core/models/models.dart";
import "../../../core/services/stock_print_service.dart";
import "../../../core/state/app_state.dart";
import "../../../shared/widgets/ui_kit.dart";

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
  int _tabIndex = 0;
  String _opsKindFilter = "all";
  Medicine? _opsMedicineFilter;
  DateTime? _opsFrom;
  DateTime? _opsTo;
  Medicine? _productHistoryMedicine;
  int _inventoryRowsPerPage = 10;
  int _inventoryPageIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = state.filterMedicines(query: search.text);
    return DefaultTabController(
      length: 3,
      child: KeyboardListener(
      focusNode: keyboardFocus,
        onKeyEvent: (event) => _handleScannerKey(event),
        child: Padding(
          padding: Ui.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Ui.pageTitle(
                      context,
                      "Inventory",
                      subtitle:
                          "Maintain medicines, then record GRN, damages, and adjustments.",
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
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatCard(
                      title: "Total items",
                      value: "${state.medicines.length}",
                      icon: Icons.inventory_2_outlined,
                      tint: const Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      title: "Low stock",
                      value: "${state.lowStockCount}",
                      icon: Icons.warning_amber_rounded,
                      tint: const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      title: "Near expiry",
                      value: "${state.nearExpiryCount}",
                      icon: Icons.event_busy_outlined,
                      tint: const Color(0xFFB91C1C),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TabBar(
                onTap: (value) => setState(() => _tabIndex = value),
                tabs: const [
                  Tab(text: "Inventory"),
                  Tab(text: "Stock Management"),
                  Tab(text: "Valuation & History"),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildInventoryTab(context, state, rows),
                    _buildStockManagementTab(context, state),
                    _buildValuationAndHistoryTab(context, state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleScannerKey(KeyEvent event) {
    if (_tabIndex != 0) {
      return;
    }
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
  }

  Widget _buildInventoryTab(
    BuildContext context,
    AppState state,
    List<Medicine> rows,
  ) {
    final safeRowsPerPage = _inventoryRowsPerPage.clamp(10, 100);
    final totalPages =
        rows.isEmpty ? 1 : ((rows.length - 1) ~/ safeRowsPerPage) + 1;
    if (_inventoryPageIndex >= totalPages) {
      _inventoryPageIndex = 0;
    }
    final start = _inventoryPageIndex * safeRowsPerPage;
    final visible = rows.skip(start).take(safeRowsPerPage).toList();

    return Column(
      children: [
        _InventoryToolbar(
          searchController: search,
          onSearchChanged: () => setState(() {}),
          onClear: () => setState(() => search.clear()),
          onExport: () => _exportData(context),
          onImport: () => _importData(context),
          onNewMedicine: () => _openForm(context, null),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _InventoryTableCard(
            rows: rows,
            visibleRows: visible,
            startIndex: start,
            rowsPerPage: safeRowsPerPage,
            pageIndex: _inventoryPageIndex,
            totalPages: totalPages,
            onRowsPerPageChanged: (value) => setState(() {
              _inventoryRowsPerPage = value;
              _inventoryPageIndex = 0;
            }),
            onPreviousPage: _inventoryPageIndex <= 0
                ? null
                : () => setState(() => _inventoryPageIndex -= 1),
            onNextPage: _inventoryPageIndex >= totalPages - 1
                ? null
                : () => setState(() => _inventoryPageIndex += 1),
          ),
        ),
      ],
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(
      text:
          "C:\\\\riyopharma_backup_${DateTime.now().millisecondsSinceEpoch}.json",
    );
    final path = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Export data (backup)"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Save to path (.json)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text("Export"),
          ),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty || !context.mounted) return;
    await state.backup(path.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Exported: ${path.trim()}")),
    );
  }

  Future<void> _importData(BuildContext context) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Import data (restore)"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Backup path (.json)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text("Import"),
          ),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty || !context.mounted) return;
    await state.restore(path.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Imported successfully.")),
    );
  }

  Widget _buildStockManagementTab(BuildContext context, AppState state) {
    final operations = _filteredStockOperations(state);
    return SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          ContentCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Stock Management",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openGoodsReceiving(context),
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  label: const Text("New GRN"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ContentCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: _opsKindFilter,
                    decoration: const InputDecoration(
                      labelText: "Operation type",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("All types")),
                      DropdownMenuItem(value: "grn", child: Text("GRN")),
                      DropdownMenuItem(value: "damage", child: Text("Damages")),
                      DropdownMenuItem(value: "adjustment", child: Text("Adjustments")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _opsKindFilter = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: DropdownButtonFormField<Medicine?>(
                    initialValue: _opsMedicineFilter,
                    decoration: const InputDecoration(
                      labelText: "Medicine",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Medicine?>(
                        value: null,
                        child: Text("All medicines"),
                      ),
                      ...state.medicines.map(
                        (m) => DropdownMenuItem<Medicine?>(
                          value: m,
                          child: Text("${m.name} (${m.batchNo})"),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _opsMedicineFilter = value),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _opsFrom ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(1990),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _opsFrom = picked);
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _opsFrom == null
                        ? "From: Any"
                        : "From: ${DateFormat("yyyy-MM-dd").format(_opsFrom!)}",
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _opsTo ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _opsTo = picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _opsTo == null
                        ? "To: Any"
                        : "To: ${DateFormat("yyyy-MM-dd").format(_opsTo!)}",
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _opsKindFilter = "all";
                    _opsMedicineFilter = null;
                    _opsFrom = null;
                    _opsTo = null;
                  }),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text("Reset"),
                ),
                FilledButton.tonalIcon(
                  onPressed: operations.isEmpty
                      ? null
                      : () async {
                          final svc = StockPrintService();
                          await svc.exportStockHistoryPdf(
                            companyName: state.companyName,
                            operations: operations,
                            medicines: state.medicines,
                          );
                        },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text("Export PDF (${operations.length})"),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 420,
                child: ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.download_for_offline_outlined,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Goods Receiving Notes",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Record supplier deliveries (stock-in) and unit cost for valuation.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
            ),
            const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openGoodsReceiving(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text("Receive goods (GRN)"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 420,
                child: ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.report_gmailerrorred_outlined,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                          const SizedBox(width: 10),
            Expanded(
                            child: Text(
                              "Damages",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Remove damaged/expired items from stock with an audit reason.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openDamages(context),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text("Record damages"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 420,
              child: ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF0F4C81),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Adjustments",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Fix count differences by setting quantity or applying a +/- adjustment.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openAdjustments(context),
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text("New adjustment"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Stock operations",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                if (operations.isEmpty)
                  Text(
                    "No matching stock operations.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  ...operations.take(24).map((op) {
                    final medicine = state.medicines
                        .where((m) => m.id == op.medicineId)
                        .cast<Medicine?>()
                        .firstWhere((m) => m != null, orElse: () => null);
                    final name = medicine?.name ?? op.medicineId;
                    final qtyLabel =
                        op.qtyDelta >= 0 ? "+${op.qtyDelta}" : "${op.qtyDelta}";
                    final kindLabel = switch (op.kind) {
                      StockOperationKind.grn => "GRN",
                      StockOperationKind.damage => "Damage",
                      StockOperationKind.adjustment => "Adjustment",
                    };
                    final showPrint = op.kind == StockOperationKind.grn && medicine != null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: op.qtyDelta >= 0
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              qtyLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: op.qtyDelta >= 0
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF9A3412),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$kindLabel • ${DateFormat("yyyy-MM-dd HH:mm").format(op.date)}${(op.note ?? "").trim().isEmpty ? "" : " • ${op.note}"}",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (showPrint)
                            IconButton(
                              tooltip: "Print GRN",
                              onPressed: () async {
                                final svc = StockPrintService();
                                await svc.printGrn(
                                  companyName: state.companyName,
                                  operation: op,
                                  medicine: medicine,
                                );
                              },
                              icon: const Icon(Icons.print_rounded),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<StockOperationRecord> _filteredStockOperations(AppState state) {
    bool matchKind(StockOperationRecord op) {
      switch (_opsKindFilter) {
        case "grn":
          return op.kind == StockOperationKind.grn;
        case "damage":
          return op.kind == StockOperationKind.damage;
        case "adjustment":
          return op.kind == StockOperationKind.adjustment;
        case "all":
        default:
          return true;
      }
    }

    bool matchMedicine(StockOperationRecord op) {
      final med = _opsMedicineFilter;
      if (med == null) return true;
      return op.medicineId == med.id;
    }

    bool matchDate(StockOperationRecord op) {
      final from = _opsFrom;
      final to = _opsTo;
      final d = op.date;
      if (from != null) {
        final fromStart = DateTime(from.year, from.month, from.day);
        if (d.isBefore(fromStart)) return false;
      }
      if (to != null) {
        final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
        if (d.isAfter(toEnd)) return false;
      }
      return true;
    }

    final filtered = state.stockOperations
        .where((op) => matchKind(op) && matchMedicine(op) && matchDate(op))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  Widget _buildValuationAndHistoryTab(BuildContext context, AppState state) {
    final money = NumberFormat.currency(symbol: "ETB ", decimalDigits: 2);
    final totalValue = state.totalStockValue;
    final totalQty = state.medicines.fold<int>(0, (s, m) => s + m.quantity);

    _productHistoryMedicine ??=
        state.medicines.isEmpty ? null : state.medicines.first;

    final valuationRows = [...state.medicines]
      ..sort(
        (a, b) => (b.purchasePrice * b.quantity)
            .compareTo(a.purchasePrice * a.quantity),
      );

    final selected = _productHistoryMedicine;
    final events = selected == null
        ? const <_ProductEvent>[]
        : _buildProductEvents(state, selected.id);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentCard(
            child: Text(
              "Inventory valuation & product history",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                StatCard(
                  title: "Total stock value",
                  value: money.format(totalValue),
                  icon: Icons.account_balance_wallet_outlined,
                  tint: const Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 12),
                StatCard(
                  title: "Units in stock",
                  value: "$totalQty",
                  icon: Icons.numbers_outlined,
                  tint: const Color(0xFF0F766E),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Valuation table (by purchase price)",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: valuationRows.isEmpty
                          ? null
                          : () async {
                              final svc = StockPrintService();
                              final ops = _filteredStockOperations(state);
                              await svc.exportStockHistoryPdf(
                                companyName: state.companyName,
                                operations: ops,
                                medicines: state.medicines,
                              );
                            },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text("Export ops PDF"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (valuationRows.isEmpty)
                  Text(
                    "No medicines available.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1080),
                            child: DataTable(
                        headingRowHeight: 48,
                              columns: const [
                          DataColumn(label: Text("Medicine")),
                                DataColumn(label: Text("Batch")),
                                DataColumn(label: Text("Qty")),
                          DataColumn(label: Text("Unit")),
                                DataColumn(label: Text("Buy")),
                          DataColumn(label: Text("Value")),
                                DataColumn(label: Text("Sell")),
                          DataColumn(label: Text("Potential")),
                        ],
                        rows: valuationRows.map((m) {
                          final value = m.purchasePrice * m.quantity;
                          final potential = m.sellingPrice * m.quantity;
                          return DataRow(
                                      cells: [
                                        DataCell(Text(m.name)),
                                        DataCell(Text(m.batchNo)),
                              DataCell(Text("${m.quantity}")),
                              DataCell(Text(m.unit)),
                              DataCell(Text(money.format(m.purchasePrice))),
                              DataCell(Text(money.format(value))),
                              DataCell(Text(money.format(m.sellingPrice))),
                              DataCell(Text(money.format(potential))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Product history",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 520,
                      child: DropdownButtonFormField<Medicine>(
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: "Select medicine",
                          border: OutlineInputBorder(),
                        ),
                        items: state.medicines
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text("${m.name} (${m.batchNo})"),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _productHistoryMedicine = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selected == null)
                                          Text(
                    "No medicines available.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                else if (events.isEmpty)
                  Text(
                    "No history for this product yet.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  ...events.take(40).map((e) {
                    final tone = e.qtyDelta >= 0
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFEDD5);
                    final toneText = e.qtyDelta >= 0
                        ? const Color(0xFF166534)
                        : const Color(0xFF9A3412);
                    final qtyLabel =
                        e.qtyDelta >= 0 ? "+${e.qtyDelta}" : "${e.qtyDelta}";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tone,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              qtyLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: toneText,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                          Text(
                                  e.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${DateFormat("yyyy-MM-dd HH:mm").format(e.date)}${(e.subtitle ?? "").trim().isEmpty ? "" : " • ${e.subtitle}"}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_ProductEvent> _buildProductEvents(AppState state, String medicineId) {
    final events = <_ProductEvent>[];

    for (final op in state.stockOperations) {
      if (op.medicineId != medicineId) continue;
      final title = switch (op.kind) {
        StockOperationKind.grn => "GRN (Goods received)",
        StockOperationKind.damage => "Damages / write-off",
        StockOperationKind.adjustment => "Stock adjustment",
      };
      final subtitleParts = <String>[];
      if ((op.supplier ?? "").trim().isNotEmpty) {
        subtitleParts.add("Supplier: ${op.supplier}");
      }
      if (op.unitCost != null) {
        subtitleParts.add("Unit cost: ETB ${op.unitCost!.toStringAsFixed(2)}");
      }
      if ((op.note ?? "").trim().isNotEmpty) {
        subtitleParts.add(op.note!.trim());
      }
      events.add(
        _ProductEvent(
          date: op.date,
          qtyDelta: op.qtyDelta,
          title: title,
          subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(" • "),
        ),
      );
    }

    for (final sale in state.sales) {
      for (final line in sale.lines) {
        if (line.medicineId != medicineId) continue;
        events.add(
          _ProductEvent(
            date: sale.date,
            qtyDelta: -line.qty,
            title: "Sale",
            subtitle: "Invoice: ${sale.id} • Customer: ${sale.customer}",
          ),
        );
      }
    }

    for (final p in state.purchases) {
      if (p.medicineId != medicineId) continue;
      events.add(
        _ProductEvent(
          date: p.date,
          qtyDelta: p.qty,
          title: "Purchase / Stock-in",
          subtitle:
              "Supplier: ${p.supplier} • Unit cost: ETB ${p.unitCost.toStringAsFixed(2)}",
        ),
      );
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Future<void> _openGoodsReceiving(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add a medicine first.")),
      );
      return;
    }

    Medicine medicine = state.medicines.first;
    String supplier = state.suppliers.isEmpty ? "Default Supplier" : state.suppliers.first;
    final qty = TextEditingController(text: "1");
    final unitCost = TextEditingController(text: "${medicine.purchasePrice}");

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text("Goods Receiving Note (GRN)"),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width * 0.92 > 560
                ? 560
                : MediaQuery.sizeOf(ctx).width * 0.92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
                                            children: [
                DropdownButtonFormField<Medicine>(
                  initialValue: medicine,
                  decoration: const InputDecoration(
                    labelText: "Medicine",
                    border: OutlineInputBorder(),
                  ),
                  items: state.medicines
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text("${m.name} (${m.batchNo})"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialog(() {
                      medicine = value;
                      unitCost.text = "${medicine.purchasePrice}";
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: supplier,
                  decoration: const InputDecoration(
                    labelText: "Supplier",
                    border: OutlineInputBorder(),
                  ),
                  items: (state.suppliers.isEmpty
                          ? ["Default Supplier"]
                          : state.suppliers)
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialog(() => supplier = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Quantity (${medicine.unit})",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitCost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Unit cost",
                    border: OutlineInputBorder(),
                                                ),
                                              ),
                                            ],
                                          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final q = int.tryParse(qty.text.trim()) ?? 0;
                final c = double.tryParse(unitCost.text.trim()) ?? -1;
                if (q <= 0 || c < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter valid qty and unit cost.")),
                  );
                  return;
                }
                state.recordGoodsReceiving(
                  medicineId: medicine.id,
                  qty: q,
                  unitCost: c,
                  supplier: supplier,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("GRN recorded successfully.")),
                );
              },
              child: const Text("Receive"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDamages(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add a medicine first.")),
      );
      return;
    }

    Medicine medicine = state.medicines.first;
    final qty = TextEditingController(text: "1");
    final reason = TextEditingController(text: "damaged");

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text("Record Damages"),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width * 0.92 > 560
                ? 560
                : MediaQuery.sizeOf(ctx).width * 0.92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Medicine>(
                  initialValue: medicine,
                  decoration: const InputDecoration(
                    labelText: "Medicine",
                    border: OutlineInputBorder(),
                  ),
                  items: state.medicines
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text("${m.name} (${m.batchNo})"),
                                    ),
                                  )
                                  .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialog(() => medicine = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Quantity to remove (${medicine.unit})",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: "Reason / Note",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final q = int.tryParse(qty.text.trim()) ?? 0;
                if (q <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter a valid quantity.")),
                  );
                  return;
                }
                final r = reason.text.trim().isEmpty ? "damaged" : reason.text.trim();
                final result = state.recordDamage(
                  medicineId: medicine.id,
                  qty: q,
                  reason: r,
                );
                if (result != "OK") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Damages recorded successfully.")),
                );
              },
              child: const Text("Remove"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdjustments(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add a medicine first.")),
      );
      return;
    }

    Medicine medicine = state.medicines.first;
    String mode = "set";
    final value = TextEditingController(text: "${medicine.quantity}");
    final note = TextEditingController(text: "adjustment");

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text("Stock Adjustment"),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width * 0.92 > 560
                ? 560
                : MediaQuery.sizeOf(ctx).width * 0.92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Medicine>(
                  initialValue: medicine,
                  decoration: const InputDecoration(
                    labelText: "Medicine",
                    border: OutlineInputBorder(),
                  ),
                  items: state.medicines
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text("${m.name} (${m.batchNo})"),
                        ),
                      )
                      .toList(),
                  onChanged: (value0) {
                    if (value0 == null) return;
                    setDialog(() {
                      medicine = value0;
                      if (mode == "set") {
                        value.text = "${medicine.quantity}";
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: "Adjustment mode",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "set", child: Text("Set quantity to")),
                    DropdownMenuItem(value: "delta", child: Text("Apply +/- change")),
                  ],
                  onChanged: (value0) {
                    if (value0 == null) return;
                    setDialog(() {
                      mode = value0;
                      value.text = mode == "set" ? "${medicine.quantity}" : "0";
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: mode == "set"
                        ? "New quantity (${medicine.unit})"
                        : "Delta (+/-) (${medicine.unit})",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: "Note",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final noteText = note.text.trim().isEmpty ? "adjustment" : note.text.trim();
                if (mode == "set") {
                  final newQty = int.tryParse(value.text.trim());
                  if (newQty == null || newQty < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter a valid new quantity.")),
                    );
                    return;
                  }
                  final result = state.recordAdjustment(
                    medicineId: medicine.id,
                    setTo: newQty,
                    note: noteText,
                  );
                  if (result != "OK") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result)),
                    );
                    return;
                  }
                } else {
                  final delta = int.tryParse(value.text.trim());
                  if (delta == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter a valid delta value.")),
                    );
                    return;
                  }
                  final result = state.recordAdjustment(
                    medicineId: medicine.id,
                    delta: delta,
                    note: noteText,
                  );
                  if (result != "OK") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result)),
                    );
                    return;
                  }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Adjustment saved.")),
                );
              },
              child: const Text("Save"),
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
    final u = TextEditingController(text: existing?.unit ?? "pcs");
    final q = TextEditingController(text: "${existing?.quantity ?? 0}");
    final buy = TextEditingController(text: "${existing?.purchasePrice ?? 0}");
    final sell = TextEditingController(text: "${existing?.sellingPrice ?? 0}");
    final reorder = TextEditingController(
      text: "${existing?.reorderLevel ?? 10}",
    );
    DateTime mfg = existing?.manufacturedOn ?? DateTime.now();
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
                      controller: u,
                      decoration: const InputDecoration(
                        labelText: "Unit of measurement (e.g. tabs, pcs, ml)",
                      ),
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
                    DropdownButtonFormField<String>(
                      initialValue: supplier,
                      decoration: const InputDecoration(
                        labelText: "Supplier",
                        border: OutlineInputBorder(),
                      ),
                      items: s.suppliers
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialog(() => supplier = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
                      ),
                      items: s.categories
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialog(() => category = v);
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Manufacturing: ${DateFormat("yyyy-MM-dd").format(mfg)}",
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: mfg,
                              firstDate: DateTime(1990),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) {
                              setDialog(() => mfg = d);
                            }
                          },
                          child: const Text("Pick"),
                        ),
                      ],
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
                // Validation
                if (n.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Medicine name is required')),
                  );
                  return;
                }
                if (g.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generic name is required')),
                  );
                  return;
                }
                if (q.text.trim().isEmpty ||
                    int.tryParse(q.text) == null ||
                    int.parse(q.text) < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Valid quantity is required')),
                  );
                  return;
                }
                if (buy.text.trim().isEmpty ||
                    double.tryParse(buy.text) == null ||
                    double.parse(buy.text) < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valid purchase price is required'),
                    ),
                  );
                  return;
                }
                if (sell.text.trim().isEmpty ||
                    double.tryParse(sell.text) == null ||
                    double.parse(sell.text) < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valid selling price is required'),
                    ),
                  );
                  return;
                }
                // Validate that selling price is greater than buying price
                final buyPrice = double.parse(buy.text);
                final sellPrice = double.parse(sell.text);
                if (sellPrice <= buyPrice) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Selling price must be greater than buying price',
                      ),
                    ),
                  );
                  return;
                }

                final med = Medicine(
                  id:
                      existing?.id ??
                      "MED-${DateTime.now().microsecondsSinceEpoch}",
                  name: n.text.trim(),
                  genericName: g.text.trim(),
                  batchNo: b.text.trim(),
                  manufacturedOn: mfg,
                  expiry: exp,
                  unit: u.text.trim().isEmpty ? "pcs" : u.text.trim(),
                  quantity: int.parse(q.text),
                  purchasePrice: double.parse(buy.text),
                  sellingPrice: double.parse(sell.text),
                  supplier: supplier,
                  category: category,
                  barcode: "",
                  reorderLevel: int.tryParse(reorder.text) ?? 10,
                );
                if (existing == null) {
                  s.addMedicine(med);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Medicine added successfully'),
                    ),
                  );
                } else {
                  s.updateMedicine(med);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Medicine updated successfully'),
                    ),
                  );
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

class _ProductEvent {
  const _ProductEvent({
    required this.date,
    required this.qtyDelta,
    required this.title,
    this.subtitle,
  });

  final DateTime date;
  final int qtyDelta;
  final String title;
  final String? subtitle;
}

class _InventoryToolbar extends StatelessWidget {
  const _InventoryToolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClear,
    required this.onExport,
    required this.onImport,
    required this.onNewMedicine,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onNewMedicine;

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: "Search / Barcode (scanner supported)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => onSearchChanged(),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            label: const Text("Clear"),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text("Export data"),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            onPressed: onImport,
            icon: const Icon(Icons.download_outlined),
            label: const Text("Import data"),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            onPressed: onNewMedicine,
            icon: const Icon(Icons.add_rounded),
            label: const Text("New"),
          ),
        ],
      ),
    );
  }
}

class _InventoryTableCard extends StatelessWidget {
  const _InventoryTableCard({
    required this.rows,
    required this.visibleRows,
    required this.startIndex,
    required this.rowsPerPage,
    required this.pageIndex,
    required this.totalPages,
    required this.onRowsPerPageChanged,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final List<Medicine> rows;
  final List<Medicine> visibleRows;
  final int startIndex;
  final int rowsPerPage;
  final int pageIndex;
  final int totalPages;
  final ValueChanged<int> onRowsPerPageChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      padding: const EdgeInsets.all(0),
      child: SizedBox.expand(
        child: rows.isEmpty
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: "No medicines",
                message: "Add medicines or scan/search by barcode to get started.",
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final minWidth = math.max(constraints.maxWidth, 1120.0);
                  final textTheme = Theme.of(context).textTheme;
                  final cs = Theme.of(context).colorScheme;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Medicines (${rows.length})",
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              "Rows",
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 110,
                              child: DropdownButtonFormField<int>(
                                initialValue: rowsPerPage,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [10, 20, 50, 100]
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text("$v"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  onRowsPerPageChanged(value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: minWidth,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowHeight: 48,
                                columns: const [
                                  DataColumn(label: Text("#")),
                                  DataColumn(label: Text("Name")),
                                  DataColumn(label: Text("Generic")),
                                  DataColumn(label: Text("Batch")),
                                  DataColumn(label: Text("Mfg Date")),
                                  DataColumn(label: Text("Expiry")),
                                  DataColumn(label: Text("Unit")),
                                  DataColumn(label: Text("Qty")),
                                  DataColumn(label: Text("Buy")),
                                  DataColumn(label: Text("Sell")),
                                  DataColumn(label: Text("Supplier")),
                                  DataColumn(label: Text("Category")),
                                ],
                                rows: visibleRows.asMap().entries.map((entry) {
                                  final rowIndex = entry.key;
                                  final m = entry.value;
                                  final serial = startIndex + rowIndex + 1;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text("$serial")),
                                      DataCell(Text(m.name)),
                                      DataCell(Text(m.genericName)),
                                      DataCell(Text(m.batchNo)),
                                      DataCell(
                                        Text(
                                          DateFormat("yyyy-MM-dd")
                                              .format(m.manufacturedOn),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          DateFormat("yyyy-MM-dd").format(m.expiry),
                                        ),
                                      ),
                                      DataCell(Text(m.unit)),
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
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Row(
                          children: [
                            Text(
                              rows.isEmpty
                                  ? "0"
                                  : "${startIndex + 1}-${math.min(startIndex + rowsPerPage, rows.length)} of ${rows.length}",
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: "Previous",
                              onPressed: onPreviousPage,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              "Page ${pageIndex + 1} / $totalPages",
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            IconButton(
                              tooltip: "Next",
                              onPressed: onNextPage,
                              icon: const Icon(Icons.chevron_right_rounded),
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

