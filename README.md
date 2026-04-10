# PharmaCore Desktop

Desktop-first Flutter app for offline pharmacy operations.

## Implemented Core Modules

- Dashboard: total stock value, low stock count, near-expiry count, daily sales.
- Inventory / Warehouse: add/edit/delete medicines with batch, expiry, qty, prices, supplier, category, barcode.
- Stock movements: stock in (purchases) and stock out (via POS checkout).
- Search + filters: medicine search with barcode-friendly lookup.
- Purchases: purchase records update stock levels.
- Sales / POS: cart checkout, invoice-style sale record, automatic stock deduction.
- Reports: stock/expiry/sales summary, CSV export, PDF generation/print layout.
- Masters: suppliers, customers, categories.
- Alerts: low stock + near-expiry local notifications.
- Settings: backup/restore local data and basic company/printer fields.

## Tech

- Flutter desktop (`windows`, `linux`, `macos`)
- `provider` state management
- JSON local persistence using `path_provider`
- `flutter_local_notifications` for local alerts
- `csv`, `pdf`, `printing` for export and reports

## Run

```bash
flutter pub get
flutter run -d windows
```

## Important for Windows

If you get symlink/plugin errors on setup, enable Developer Mode:

```powershell
start ms-settings:developers
```

Then run `flutter pub get` again.