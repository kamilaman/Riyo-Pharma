import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/models/models.dart";
import "../../core/services/receipt_service.dart";
import "../../core/state/app_state.dart";

Future<bool?> openSaleReceiptPreview(
  BuildContext context,
  SaleRecord sale, {
  bool isDraft = false,
}) {
  final state = context.read<AppState>();
  return ReceiptService().showReceiptPreview(
    context: context,
    companyName: state.companyName,
    sale: sale,
    isDraft: isDraft,
  );
}
