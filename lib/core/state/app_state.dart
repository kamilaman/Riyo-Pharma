import "dart:math";
import "dart:convert";
import "dart:io";
import "dart:async";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "package:flutter/foundation.dart";

import "../models/models.dart";
import "../services/database_service.dart";
import "../services/network_service.dart";
import "../services/notification_service.dart";

class AppState extends ChangeNotifier {
  AppState(this._db, this._notifications, this.network);

  final DatabaseService _db;
  final NotificationService _notifications;
  final NetworkService network;
  final Random _rng = Random();

  final List<Medicine> medicines = [];
  final List<PurchaseRecord> purchases = [];
  final List<SaleRecord> sales = [];
  final List<String> suppliers = ["Default Supplier"];
  final List<String> customers = ["Company"];
  final List<String> categories = ["General"];
  final List<AppUser> users = [];
  AppUser? currentUser;
  String companyName = "Riyo Pharma";
  String printerName = "Default Printer";
  Timer? _syncTimer;

  Future<void> _migrateFromOldDatabase() async {
    try {
      final support = await getApplicationSupportDirectory();
      final oldDir = Directory(p.join(support.path, "pharmacore"));

      // Delete old pharmacore database completely
      if (await oldDir.exists()) {
        await oldDir.delete(recursive: true);
      }

      // Ensure riyopharma directory exists (it will be created by database service)
    } catch (e) {
      debugPrint("Skipping old database migration: $e");
    }
  }

  Future<void> init() async {
    await _db.init();
    await _notifications.init();

    // Check if we need to migrate from old "pharmacore" directory
    await _migrateFromOldDatabase();

    // Check if we already have an app identity
    final data = await _db.loadSnapshot();

    String? cid = data["client_id"] as String?;
    if (cid == null) {
      cid = _id("CLIENT");
      _db.enqueueOperation(
        "UPSERT",
        "settings",
        "client_id",
        payload: {"k": "client_id", "v": cid},
      );
    }
    await network.init(cid);

    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _syncLocalQueue(),
    );

    if (data.isEmpty) {
      _seed();
      await _persist();
      return;
    }
    medicines
      ..clear()
      ..addAll(
        (data["medicines"] as List<dynamic>? ?? []).map(
          (e) => Medicine.fromJson(e as Map<String, dynamic>),
        ),
      );
    purchases
      ..clear()
      ..addAll(
        (data["purchases"] as List<dynamic>? ?? []).map(
          (e) => PurchaseRecord.fromJson(e as Map<String, dynamic>),
        ),
      );
    sales
      ..clear()
      ..addAll(
        (data["sales"] as List<dynamic>? ?? []).map(
          (e) => SaleRecord.fromJson(e as Map<String, dynamic>),
        ),
      );
    suppliers
      ..clear()
      ..addAll(
        (data["suppliers"] as List<dynamic>? ?? ["Default Supplier"])
            .cast<String>(),
      );
    customers
      ..clear()
      ..addAll(
        (data["customers"] as List<dynamic>? ?? ["Company"]).cast<String>(),
      );
    categories
      ..clear()
      ..addAll(
        (data["categories"] as List<dynamic>? ?? ["General"]).cast<String>(),
      );
    users
      ..clear()
      ..addAll(
        (data["users"] as List<dynamic>? ?? []).map(
          (e) => AppUser.fromJson(e as Map<String, dynamic>),
        ),
      );
    companyName = data["companyName"] as String? ?? "Riyo Pharma";
    printerName = data["printerName"] as String? ?? "Default Printer";
    if (users.isEmpty) {
      users.add(
        AppUser(
          id: _id("USR"),
          username: "admin",
          pin: "1234",
          role: UserRole.admin,
        ),
      );
      await _persist();
    }
    await runAlerts();
    notifyListeners();
  }

  bool login(String username, String pin) {
    final hit = users
        .where((u) => u.username == username.trim() && u.pin == pin.trim())
        .toList();
    if (hit.isEmpty) return false;
    currentUser = hit.first;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  void addUser(AppUser user) {
    users.add(user);
    _db.enqueueOperation("UPSERT", "users", user.id, payload: user.toJson());
    _persistAndNotify();
  }

  void updateUser(AppUser user) {
    final index = users.indexWhere((e) => e.id == user.id);
    if (index != -1) {
      users[index] = user;
      _db.enqueueOperation("UPSERT", "users", user.id, payload: user.toJson());
      _persistAndNotify();
    }
  }

  void deleteUser(String id) {
    if (currentUser?.id == id) return; // Prevent deleting self
    users.removeWhere((e) => e.id == id);
    _db.enqueueOperation("DELETE", "users", id);
    _persistAndNotify();
  }

  String _id(String prefix) =>
      "$prefix-${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(99999)}";

  double get totalStockValue => medicines.fold(
    0,
    (s, m) => s + (m.purchasePrice * m.quantity.toDouble()),
  );
  int get lowStockCount => medicines.where((e) => e.isLowStock).length;
  int get nearExpiryCount => medicines.where((e) => e.isNearExpiry).length;
  double get todaySales {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .fold(0, (sum, sale) => sum + sale.total);
  }

  void addMedicine(Medicine m) {
    medicines.add(m);
    _db.enqueueOperation("UPSERT", "medicines", m.id, payload: m.toJson());
    _persistAndNotify();
  }

  // CRUD operations for suppliers
  void addSupplier(String supplier) {
    if (!suppliers.contains(supplier)) {
      suppliers.add(supplier);
      _db.enqueueOperation(
        "UPSERT",
        "suppliers",
        supplier,
        payload: {'name': supplier},
      );
      _persistAndNotify();
    }
  }

  void updateSupplier(String oldSupplier, String newSupplier) {
    final index = suppliers.indexOf(oldSupplier);
    if (index != -1) {
      suppliers[index] = newSupplier;
      _db.enqueueOperation(
        "UPDATE",
        "suppliers",
        oldSupplier,
        payload: {'name': newSupplier},
      );
      _persistAndNotify();
    }
  }

  void deleteSupplier(String supplier) {
    if (suppliers.contains(supplier) && supplier != "Default Supplier") {
      suppliers.remove(supplier);
      _db.enqueueOperation("DELETE", "suppliers", supplier);
      _persistAndNotify();
    }
  }

  // CRUD operations for customers
  void addCustomer(String customer) {
    if (!customers.contains(customer)) {
      customers.add(customer);
      _db.enqueueOperation(
        "UPSERT",
        "customers",
        customer,
        payload: {'name': customer},
      );
      _persistAndNotify();
    }
  }

  void updateCustomer(String oldCustomer, String newCustomer) {
    final index = customers.indexOf(oldCustomer);
    if (index != -1) {
      customers[index] = newCustomer;
      _db.enqueueOperation(
        "UPDATE",
        "customers",
        oldCustomer,
        payload: {'name': newCustomer},
      );
      _persistAndNotify();
    }
  }

  void deleteCustomer(String customer) {
    if (customers.contains(customer) && customer != "Company") {
      customers.remove(customer);
      _db.enqueueOperation("DELETE", "customers", customer);
      _persistAndNotify();
    }
  }

  // CRUD operations for categories
  void addCategory(String category) {
    if (!categories.contains(category)) {
      categories.add(category);
      _db.enqueueOperation(
        "UPSERT",
        "categories",
        category,
        payload: {'name': category},
      );
      _persistAndNotify();
    }
  }

  void updateCategory(String oldCategory, String newCategory) {
    final index = categories.indexOf(oldCategory);
    if (index != -1) {
      categories[index] = newCategory;
      _db.enqueueOperation(
        "UPDATE",
        "categories",
        oldCategory,
        payload: {'name': newCategory},
      );
      _persistAndNotify();
    }
  }

  void deleteCategory(String category) {
    if (categories.contains(category) && category != "General") {
      categories.remove(category);
      _db.enqueueOperation("DELETE", "categories", category);
      _persistAndNotify();
    }
  }

  void updateMedicine(Medicine m) {
    final index = medicines.indexWhere((e) => e.id == m.id);
    if (index != -1) {
      medicines[index] = m;
      _db.enqueueOperation("UPSERT", "medicines", m.id, payload: m.toJson());
      _persistAndNotify();
    }
  }

  void deleteMedicine(String id) {
    medicines.removeWhere((e) => e.id == id);
    _db.enqueueOperation("DELETE", "medicines", id);
    _persistAndNotify();
  }

  void stockIn({
    required String medicineId,
    required int qty,
    required double unitCost,
    required String supplier,
  }) {
    final med = medicines.firstWhere((e) => e.id == medicineId);
    med.quantity += qty;
    final p = PurchaseRecord(
      id: _id("PUR"),
      supplier: supplier,
      medicineId: medicineId,
      qty: qty,
      unitCost: unitCost,
      date: DateTime.now(),
    );
    purchases.add(p);

    _db.enqueueOperation("UPSERT", "purchases", p.id, payload: p.toJson());
    _db.enqueueOperation("UPSERT", "medicines", med.id, payload: med.toJson());
    _persistAndNotify();
  }

  String getNextInvoiceId() {
    final year = DateTime.now().year;
    var maxSeq = 0;
    for (final s in sales) {
      if (s.date.year == year && s.id.startsWith('RP/PE/')) {
        final parts = s.id.split('/');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]);
          if (seq != null && seq > maxSeq) {
            maxSeq = seq;
          }
        }
      }
    }
    final nextSeq = maxSeq + 1;
    return 'RP/PE/${nextSeq.toString().padLeft(3, '0')}/$year';
  }

  String stockOut({
    required String medicineId,
    required int qty,
    required String reason,
  }) {
    final med = medicines.firstWhere((e) => e.id == medicineId);
    if (qty > med.quantity) {
      return "Not enough stock.";
    }
    med.quantity -= qty;
    if (reason == "sale") {
      final s = SaleRecord(
        id: getNextInvoiceId(),
        customer: "Company",
        cashier: currentUser?.username ?? "System",
        date: DateTime.now(),
        lines: [
          SaleLine(
            medicineId: med.id,
            name: med.name,
            qty: qty,
            unitPrice: med.sellingPrice,
          ),
        ],
      );
      sales.add(s);
      _db.enqueueOperation("UPSERT", "sales", s.id, payload: s.toJson());
    }
    _db.enqueueOperation("UPSERT", "medicines", med.id, payload: med.toJson());
    _persistAndNotify();
    return "OK";
  }

  String completeSale(
    String customer,
    Map<String, int> cart, {
    String? invoiceId,
  }) {
    final lines = <SaleLine>[];
    for (final entry in cart.entries) {
      final med = medicines.firstWhere((e) => e.id == entry.key);
      if (entry.value > med.quantity) {
        return "Insufficient stock for ${med.name}";
      }
      med.quantity -= entry.value;
      lines.add(
        SaleLine(
          medicineId: med.id,
          name: med.name,
          qty: entry.value,
          unitPrice: med.sellingPrice,
        ),
      );
      _db.enqueueOperation(
        "UPSERT",
        "medicines",
        med.id,
        payload: med.toJson(),
      );
    }
    final s = SaleRecord(
      id: invoiceId ?? getNextInvoiceId(),
      customer: customer,
      cashier: currentUser?.username ?? "System",
      date: DateTime.now(),
      lines: lines,
    );
    sales.add(s);
    _db.enqueueOperation("UPSERT", "sales", s.id, payload: s.toJson());
    _persistAndNotify();
    return "OK";
  }

  List<Medicine> filterMedicines({
    String? query,
    bool lowStockOnly = false,
    bool nearExpiryOnly = false,
    String? category,
  }) {
    return medicines.where((m) {
      final q = query?.trim().toLowerCase() ?? "";
      final matchQ =
          q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.genericName.toLowerCase().contains(q) ||
          m.batchNo.toLowerCase().contains(q) ||
          m.barcode.toLowerCase().contains(q);
      final matchLow = !lowStockOnly || m.isLowStock;
      final matchExp = !nearExpiryOnly || m.isNearExpiry;
      final matchCat =
          category == null || category.isEmpty || m.category == category;
      return matchQ && matchLow && matchExp && matchCat;
    }).toList();
  }

  /// Exact match on stored barcode (trimmed), for scanner / quick lookup.
  Medicine? findByBarcode(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return null;
    for (final m in medicines) {
      if (m.barcode.trim() == q) return m;
    }
    return null;
  }

  Future<void> runAlerts() async {
    final lows = medicines.where((e) => e.isLowStock).length;
    final expiries = medicines.where((e) => e.isNearExpiry).length;
    if (lows > 0) {
      await _notifications.showAlert(
        "Low Stock Alert",
        "$lows medicine items are low in stock.",
      );
    }
    if (expiries > 0) {
      await _notifications.showAlert(
        "Expiry Alert",
        "$expiries medicine items near expiry.",
      );
    }
  }

  Future<void> backup(String fullPath) async {
    final file = File(fullPath);
    await file.writeAsString(jsonEncode(_payload()));
  }

  Future<void> restore(String fullPath) async {
    final file = File(fullPath);
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    medicines
      ..clear()
      ..addAll(
        (data["medicines"] as List<dynamic>).map(
          (e) => Medicine.fromJson(e as Map<String, dynamic>),
        ),
      );
    purchases
      ..clear()
      ..addAll(
        (data["purchases"] as List<dynamic>).map(
          (e) => PurchaseRecord.fromJson(e as Map<String, dynamic>),
        ),
      );
    sales
      ..clear()
      ..addAll(
        (data["sales"] as List<dynamic>).map(
          (e) => SaleRecord.fromJson(e as Map<String, dynamic>),
        ),
      );
    suppliers
      ..clear()
      ..addAll((data["suppliers"] as List<dynamic>).cast<String>());
    customers
      ..clear()
      ..addAll((data["customers"] as List<dynamic>).cast<String>());
    categories
      ..clear()
      ..addAll((data["categories"] as List<dynamic>).cast<String>());
    users
      ..clear()
      ..addAll(
        (data["users"] as List<dynamic>).map(
          (e) => AppUser.fromJson(e as Map<String, dynamic>),
        ),
      );
    companyName = data["companyName"] as String;
    printerName = data["printerName"] as String;
    await _persist();
    notifyListeners();
  }

  void addMasterValue(String kind, List<String> collection, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (!collection.contains(v)) {
      collection.add(v);
      _db.enqueueOperation(
        "UPSERT",
        "masters",
        "$kind:$v",
        payload: {"kind": kind, "value": v},
      );
      _persistAndNotify();
    }
  }

  void updateMasterValue(
    String kind,
    List<String> collection,
    String previousValue,
    String nextValue,
  ) {
    final oldValue = previousValue.trim();
    final newValue = nextValue.trim();
    if (oldValue.isEmpty || newValue.isEmpty) return;
    final index = collection.indexOf(oldValue);
    if (index == -1) return;
    if (collection.contains(newValue) && newValue != oldValue) return;
    collection[index] = newValue;
    _db.enqueueOperation("DELETE", "masters", "$kind:$oldValue");
    _db.enqueueOperation(
      "UPSERT",
      "masters",
      "$kind:$newValue",
      payload: {"kind": kind, "value": newValue},
    );
    _persistAndNotify();
  }

  void removeMasterValue(String kind, List<String> collection, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    collection.remove(v);
    _db.enqueueOperation("DELETE", "masters", "$kind:$v");
    _persistAndNotify();
  }

  void updateCompanyName(String value) {
    companyName = value;
    _db.enqueueOperation(
      "UPSERT",
      "settings",
      "companyName",
      payload: {"k": "companyName", "v": value},
    );
    _persistAndNotify();
  }

  void updatePrinterName(String value) {
    printerName = value;
    _db.enqueueOperation(
      "UPSERT",
      "settings",
      "printerName",
      payload: {"k": "printerName", "v": value},
    );
    _persistAndNotify();
  }

  Map<String, dynamic> _payload() => {
    "medicines": medicines.map((e) => e.toJson()).toList(),
    "purchases": purchases.map((e) => e.toJson()).toList(),
    "sales": sales.map((e) => e.toJson()).toList(),
    "suppliers": suppliers,
    "customers": customers,
    "categories": categories,
    "users": users.map((e) => e.toJson()).toList(),
    "companyName": companyName,
    "printerName": printerName,
  };

  Future<void> _persist() => _db.saveSnapshot(_payload());

  Future<void> _persistAndNotify() async {
    await _persist();
    await runAlerts();
    notifyListeners();
  }

  void _seed() {
    medicines.add(
      Medicine(
        id: _id("MED"),
        name: "Paracetamol 500mg",
        genericName: "Acetaminophen",
        batchNo: "PCT-1001",
        expiry: DateTime.now().add(const Duration(days: 180)),
        quantity: 120,
        purchasePrice: 1.2,
        sellingPrice: 2.0,
        supplier: "Default Supplier",
        category: "General",
        barcode: "8901234567890",
      ),
    );
    users.add(
      AppUser(
        id: _id("USR"),
        username: "admin",
        pin: "1234",
        role: UserRole.admin,
      ),
    );
  }

  Future<void> _syncLocalQueue() async {
    if (network.serverIp == null || network.token == null) return;

    try {
      final ops = await _db.getPendingOperations();
      if (ops.isNotEmpty) {
        final success = await network.pushOperations(ops);
        if (success) {
          final seqIds = ops.map((e) => e["seq_id"] as int).toList();
          await _db.removeOperations(seqIds);
        }
      }
    } catch (e) {
      debugPrint("Local sync skipped: $e");
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
