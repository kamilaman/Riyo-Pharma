import "dart:typed_data";

import "package:intl/intl.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";

import "../models/models.dart";

class StockPrintService {
  Future<void> printGrn({
    required String companyName,
    required StockOperationRecord operation,
    required Medicine medicine,
  }) async {
    final bytes = await buildGrnPdf(
      companyName: companyName,
      operation: operation,
      medicine: medicine,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(
        prefix: "grn",
        id: operation.id,
      ),
    );
  }

  Future<void> exportStockHistoryPdf({
    required String companyName,
    required List<StockOperationRecord> operations,
    required List<Medicine> medicines,
  }) async {
    final bytes = await buildStockHistoryPdf(
      companyName: companyName,
      operations: operations,
      medicines: medicines,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(prefix: "stock_history", id: DateTime.now().toIso8601String()),
    );
  }

  Future<Uint8List> buildGrnPdf({
    required String companyName,
    required StockOperationRecord operation,
    required Medicine medicine,
  }) async {
    final company = companyName.trim().isEmpty ? "Riyo Pharma" : companyName.trim();
    final document = pw.Document(
      title: operation.id,
      author: company,
      creator: "Riyopharma",
      subject: "Goods Receiving Note ${operation.id}",
    );

    final money = NumberFormat.currency(symbol: "ETB ", decimalDigits: 2);
    final dateTime = DateFormat("dd MMM yyyy, HH:mm");
    final dateOnly = DateFormat("yyyy-MM-dd");

    final qty = operation.qtyDelta;
    final unitCost = operation.unitCost ?? medicine.purchasePrice;
    final totalCost = qty * unitCost;
    final supplier = (operation.supplier ?? medicine.supplier).trim().isEmpty
        ? "Supplier"
        : (operation.supplier ?? medicine.supplier).trim();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 72, height: 5, color: PdfColors.teal700),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          company,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Goods Receiving Note (GRN)",
                          style: pw.TextStyle(
                            fontSize: 11.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          "Record of stock received from supplier.",
                          style: const pw.TextStyle(
                            fontSize: 9.3,
                            color: PdfColors.blueGrey600,
                            lineSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 18),
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.9),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _metaLine("GRN Number", operation.id),
                        _metaLine("Received On", dateTime.format(operation.date)),
                        _metaLine("Supplier", supplier),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Product details",
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _infoRow("Product", medicine.name),
                    _infoRow("Generic", medicine.genericName),
                    _infoRow("Batch", medicine.batchNo),
                    _infoRow("Mfg Date", dateOnly.format(medicine.manufacturedOn)),
                    _infoRow("Expiry Date", dateOnly.format(medicine.expiry)),
                    _infoRow("Unit", medicine.unit),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.0),
                  1: pw.FixedColumnWidth(120),
                },
                children: [
                  _kvRow("Quantity received", "$qty ${medicine.unit}"),
                  _kvRow("Unit cost", money.format(unitCost)),
                  _kvRow("Total cost", money.format(totalCost), bold: true),
                ],
              ),
              if (operation.note != null && operation.note!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  ),
                  child: pw.Text(
                    "Note: ${operation.note!.trim()}",
                    style: const pw.TextStyle(
                      fontSize: 9.6,
                      color: PdfColors.blueGrey700,
                      lineSpacing: 2,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return document.save();
  }

  Future<Uint8List> buildStockHistoryPdf({
    required String companyName,
    required List<StockOperationRecord> operations,
    required List<Medicine> medicines,
  }) async {
    final company = companyName.trim().isEmpty ? "Riyo Pharma" : companyName.trim();
    final document = pw.Document(
      title: "Stock history",
      author: company,
      creator: "Riyopharma",
      subject: "Stock operations history",
    );

    final dateTime = DateFormat("yyyy-MM-dd HH:mm");
    final money = NumberFormat.currency(symbol: "ETB ", decimalDigits: 2);

    Medicine? resolveMedicine(String id) {
      for (final m in medicines) {
        if (m.id == id) return m;
      }
      return null;
    }

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        ),
        build: (_) {
          final rows = operations.map((op) {
            final m = resolveMedicine(op.medicineId);
            final kind = op.kind.name.toUpperCase();
            final qty = op.qtyDelta >= 0 ? "+${op.qtyDelta}" : "${op.qtyDelta}";
            final unitCost = op.unitCost;
            final unitCostLabel = unitCost == null ? "-" : money.format(unitCost);
            final supplier = (op.supplier ?? "").trim().isEmpty ? "-" : op.supplier!.trim();
            final note = (op.note ?? "").trim().isEmpty ? "-" : op.note!.trim();
            return pw.TableRow(
              children: [
                _cell(dateTime.format(op.date)),
                _cell(kind),
                _cell(m?.name ?? op.medicineId),
                _cell(qty, align: pw.Alignment.centerRight),
                _cell(unitCostLabel, align: pw.Alignment.centerRight),
                _cell(supplier),
                _cell(note),
              ],
            );
          }).toList();

          return [
            pw.Text(
              company,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Stock operations history",
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blueGrey600,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
              columnWidths: const {
                0: pw.FixedColumnWidth(110),
                1: pw.FixedColumnWidth(70),
                2: pw.FlexColumnWidth(2.4),
                3: pw.FixedColumnWidth(52),
                4: pw.FixedColumnWidth(78),
                5: pw.FixedColumnWidth(90),
                6: pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _header("Date"),
                    _header("Type"),
                    _header("Medicine"),
                    _header("ΔQty", align: pw.Alignment.centerRight),
                    _header("Unit cost", align: pw.Alignment.centerRight),
                    _header("Supplier"),
                    _header("Note"),
                  ],
                ),
                ...rows,
              ],
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  pw.Widget _metaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 7.6, color: PdfColors.blueGrey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.1,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 92,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9.6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _kvRow(String label, String value, {bool bold = false}) {
    return pw.TableRow(
      children: [
        _cell(label),
        _cell(
          value,
          bold: bold,
          align: pw.Alignment.centerRight,
        ),
      ],
    );
  }

  pw.Widget _header(String text, {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9.1,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      ),
    );
  }

  pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 9.0,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.blueGrey900,
          ),
        ),
      ),
    );
  }

  String _fileName({required String prefix, required String id}) {
    final safe = id
        .replaceAll(RegExp(r'[<>:"/\\|?*]+'), "_")
        .replaceAll(RegExp(r"\s+"), "_")
        .replaceAll(RegExp(r"_+"), "_")
        .replaceAll(RegExp(r"^_|_$"), "");
    return "${prefix}_$safe.pdf";
  }
}

