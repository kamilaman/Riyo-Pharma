import "package:intl/intl.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";

import "models.dart";

class ReceiptService {
  Future<void> printReceipt({
    required String companyName,
    required String cashier,
    required SaleRecord sale,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              companyName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text("Invoice: ${sale.id}"),
            pw.Text(
              "Date: ${DateFormat("yyyy-MM-dd HH:mm").format(sale.date)}",
            ),
            pw.Text("Cashier: $cashier"),
            pw.Text("Customer: ${sale.customer}"),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const ["Item", "Qty", "Rate", "Total"],
              data: sale.lines
                  .map(
                    (line) => [
                      line.name,
                      line.qty.toString(),
                      line.unitPrice.toStringAsFixed(2),
                      line.total.toStringAsFixed(2),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Grand Total: Birr ${sale.total.toStringAsFixed(2)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }
}
