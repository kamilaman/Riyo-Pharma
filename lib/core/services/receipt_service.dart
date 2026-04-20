import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

class ReceiptService {
  static const double defaultVatRate = 15.0;

  Future<bool?> showReceiptPreview({
    required BuildContext context,
    required String companyName,
    required SaleRecord sale,
    String? cashier,
    double vatRate = defaultVatRate,
    bool isDraft = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xB3172028),
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        final previewWidth = size.width > 1200 ? 1040.0 : size.width - 32;
        final previewHeight = size.height > 860
            ? size.height - 32
            : size.height - 24;

        return Dialog(
          elevation: 0,
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFFF1F3F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: previewWidth,
              maxHeight: previewHeight,
              minHeight: size.height * 0.74,
            ),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    pdfFileName: fileNameForSale(companyName, sale),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    useActions: false,
                    maxPageWidth: 760,
                    padding: EdgeInsets.zero,
                    previewPageMargin: const EdgeInsets.symmetric(vertical: 28),
                    scrollViewDecoration: const BoxDecoration(
                      color: Color(0xFFE7EBF0),
                    ),
                    pdfPreviewPageDecoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFFD8DEE6)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    build: (format) => buildReceiptPdf(
                      companyName: companyName,
                      sale: sale,
                      cashier: cashier,
                      vatRate: vatRate,
                      pageFormat: format,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(isDraft ? 'Cancel' : 'Close'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () {
                        if (isDraft) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          printReceipt(
                            companyName: companyName,
                            sale: sale,
                            cashier: cashier,
                            vatRate: vatRate,
                          );
                        }
                      },
                      icon: const Icon(Icons.print_rounded),
                      label: Text(
                        isDraft ? 'Confirm & Print' : 'Print Receipt',
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

  Future<void> printReceipt({
    required String companyName,
    required SaleRecord sale,
    String? cashier,
    double vatRate = defaultVatRate,
  }) async {
    final bytes = await buildReceiptPdf(
      companyName: companyName,
      sale: sale,
      cashier: cashier,
      vatRate: vatRate,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileNameForSale(companyName, sale),
    );
  }

  Future<Uint8List> buildReceiptPdf({
    required String companyName,
    required SaleRecord sale,
    String? cashier,
    double vatRate = defaultVatRate,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final money = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
    final issueFormat = DateFormat('dd MMM yyyy, HH:mm');
    final safeVatRate = vatRate.clamp(0, 100).toDouble();
    final subtotal = sale.total;
    final vatAmount = subtotal * (safeVatRate / 100);
    final grandTotal = subtotal + vatAmount;
    final totalUnits = sale.lines.fold<int>(0, (sum, line) => sum + line.qty);
    final customerName = sale.customer.trim().isEmpty
        ? 'Company'
        : sale.customer.trim();
    final cashierName = _resolveCashier(sale, cashier);
    final company = companyName.trim().isEmpty
        ? 'Riyo Pharma'
        : companyName.trim();
    final generatedAt = DateTime.now();

    final document = pw.Document(
      title: sale.id,
      author: company,
      creator: 'Riyopharma',
      subject: 'Sales receipt ${sale.id}',
    );

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
          theme: theme,
        ),
        header: (context) => _buildDocumentHeader(
          companyName: company,
          sale: sale,
          customerName: customerName,
          cashierName: cashierName,
          issueLabel: issueFormat.format(sale.date),
        ),
        footer: (context) => _buildDocumentFooter(
          companyName: company,
          saleId: sale.id,
          generatedAt: generatedAt,
          pageNumber: context.pageNumber,
          pagesCount: context.pagesCount,
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildOverviewStrip(
            sale: sale,
            money: money,
            totalUnits: totalUnits,
            grandTotal: grandTotal,
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoSection(
                  title: 'Bill To',
                  rows: [
                    _ReceiptInfoRow('Customer', customerName),
                    _ReceiptInfoRow('Customer Type', 'Retail / Walk-in'),
                    _ReceiptInfoRow('Payment Status', 'Completed'),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _buildInfoSection(
                  title: 'Transaction Details',
                  rows: [
                    _ReceiptInfoRow('Invoice Number', sale.id),
                    _ReceiptInfoRow('Issued On', issueFormat.format(sale.date)),
                    _ReceiptInfoRow('Cashier', cashierName),
                    _ReceiptInfoRow('Line Count', '${sale.lines.length}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _buildItemsTable(sale: sale, money: money),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildTermsSection()),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: 220,
                child: _buildTotalsSection(
                  subtotal: subtotal,
                  vatAmount: vatAmount,
                  grandTotal: grandTotal,
                  vatRate: safeVatRate,
                  money: money,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          _buildAcknowledgement(company),
        ],
      ),
    );

    return document.save();
  }

  String fileNameForSale(String companyName, SaleRecord sale) {
    final invoiceId = sale.id.trim().isEmpty ? 'sales_invoice' : sale.id.trim();
    return '${_sanitizeFilePart(invoiceId)}.pdf';
  }

  String _resolveCashier(SaleRecord sale, String? cashierOverride) {
    final override = cashierOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    final fromSale = sale.cashier.trim();
    return fromSale.isEmpty ? 'System' : fromSale;
  }

  String _sanitizeFilePart(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  pw.Widget _buildDocumentHeader({
    required String companyName,
    required SaleRecord sale,
    required String customerName,
    required String cashierName,
    required String issueLabel,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.9),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 72, height: 5, color: PdfColors.teal700),
                pw.SizedBox(height: 12),
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 23,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Sales Receipt',
                  style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Official point-of-sale receipt for completed medicine sales.',
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
            width: 210,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.9),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaLine('Invoice Number', sale.id),
                _metaLine('Issue Date', issueLabel),
                _metaLine('Cashier', cashierName),
                _metaLine('Customer', customerName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDocumentFooter({
    required String companyName,
    required String saleId,
    required DateTime generatedAt,
    required int pageNumber,
    required int pagesCount,
  }) {
    final footerFormat = DateFormat('dd MMM yyyy HH:mm');
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$companyName | Invoice $saleId | Generated ${footerFormat.format(generatedAt)}',
            style: const pw.TextStyle(
              fontSize: 8.4,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.Text(
            'Page $pageNumber of $pagesCount',
            style: const pw.TextStyle(
              fontSize: 8.4,
              color: PdfColors.blueGrey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverviewStrip({
    required SaleRecord sale,
    required NumberFormat money,
    required int totalUnits,
    required double grandTotal,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      child: pw.Row(
        children: [
          _overviewItem('Items', '${sale.lines.length}'),
          pw.SizedBox(width: 24),
          _overviewItem('Units', '$totalUnits'),
          pw.SizedBox(width: 24),
          _overviewItem(
            'Transaction Date',
            DateFormat('dd MMM yyyy').format(sale.date),
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Amount Due',
                style: const pw.TextStyle(
                  fontSize: 9.2,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                money.format(grandTotal),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _overviewItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 8.2,
            color: PdfColors.blueGrey600,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoSection({
    required String title,
    required List<_ReceiptInfoRow> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 10),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 92,
                    child: pw.Text(
                      row.label,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row.value,
                      style: pw.TextStyle(
                        fontSize: 9.8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable({
    required SaleRecord sale,
    required NumberFormat money,
  }) {
    final dateOnly = DateFormat('yyyy-MM-dd');
    final rows = sale.lines.asMap().entries.map((entry) {
      final index = entry.key;
      final line = entry.value;
      final background = index.isEven ? PdfColors.white : PdfColors.grey100;

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: background),
        children: [
          _tableCell('${index + 1}', alignment: pw.Alignment.center),
          _tableCell(line.name),
          _tableCell(line.batchNo.isEmpty ? '-' : line.batchNo),
          _tableCell(dateOnly.format(line.manufacturedOn)),
          _tableCell(dateOnly.format(line.expiry)),
          _tableCell(line.unit.trim().isEmpty ? '-' : line.unit),
          _tableCell('${line.qty}', alignment: pw.Alignment.center),
          _tableCell(
            money.format(line.unitPrice),
            alignment: pw.Alignment.centerRight,
          ),
          _tableCell(
            money.format(line.total),
            alignment: pw.Alignment.centerRight,
            bold: true,
          ),
        ],
      );
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Items',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(2.6), // description
            2: pw.FlexColumnWidth(1.2), // batch
            3: pw.FlexColumnWidth(1.1), // mfg
            4: pw.FlexColumnWidth(1.1), // exp
            5: pw.FixedColumnWidth(42), // unit
            6: pw.FixedColumnWidth(40), // qty
            7: pw.FixedColumnWidth(74), // unit price
            8: pw.FixedColumnWidth(78), // total
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _headerCell('#', alignment: pw.Alignment.center),
                _headerCell('Description'),
                _headerCell('Batch'),
                _headerCell('Mfg', alignment: pw.Alignment.center),
                _headerCell('Exp', alignment: pw.Alignment.center),
                _headerCell('Unit', alignment: pw.Alignment.center),
                _headerCell('Qty', alignment: pw.Alignment.center),
                _headerCell('Unit Price', alignment: pw.Alignment.centerRight),
                _headerCell('Total', alignment: pw.Alignment.centerRight),
              ],
            ),
            ...rows,
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTermsSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Notes',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 10),
          _noteLine(
            'Verify medicine name, quantity, and amount before leaving the counter.',
          ),
          _noteLine(
            'Returns or exchanges are subject to pharmacy policy and applicable regulation.',
          ),
          _noteLine(
            'Retain this document as proof of purchase for audit and service follow-up.',
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalsSection({
    required double subtotal,
    required double vatAmount,
    required double grandTotal,
    required double vatRate,
    required NumberFormat money,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Totals',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 12),
          _totalLine('Subtotal', money.format(subtotal)),
          _totalLine(
            'VAT (${vatRate.toStringAsFixed(0)}%)',
            money.format(vatAmount),
          ),
          pw.Divider(color: PdfColors.grey400),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Grand Total',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.Text(
                  money.format(grandTotal),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAcknowledgement(String companyName) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Thank you for choosing $companyName.',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This document was generated by the Riyopharma sales system and is valid as a transaction record.',
            style: const pw.TextStyle(
              fontSize: 9.2,
              color: PdfColors.blueGrey600,
              lineSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    pw.Alignment alignment = pw.Alignment.centerLeft,
    bool bold = false,
    PdfColor textColor = PdfColors.blueGrey900,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Align(
        alignment: alignment,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9.2,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  pw.Widget _headerCell(
    String text, {
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Align(
        alignment: alignment,
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

  pw.Widget _totalLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9.3,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.6,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _metaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(
              fontSize: 7.6,
              color: PdfColors.blueGrey600,
            ),
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

  pw.Widget _noteLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '- ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal700,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 9.1,
                color: PdfColors.blueGrey700,
                lineSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptInfoRow {
  const _ReceiptInfoRow(this.label, this.value);

  final String label;
  final String value;
}
