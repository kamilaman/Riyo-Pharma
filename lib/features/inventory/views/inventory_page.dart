import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../../../core/models/models.dart";
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
                  expiry: exp,
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
