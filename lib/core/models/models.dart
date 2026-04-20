class Medicine {
  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.batchNo,
    required this.manufacturedOn,
    required this.expiry,
    required this.unit,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.supplier,
    required this.category,
    required this.barcode,
    this.reorderLevel = 10,
  });

  final String id;
  String name;
  String genericName;
  String batchNo;
  DateTime manufacturedOn;
  DateTime expiry;
  String unit;
  int quantity;
  double purchasePrice;
  double sellingPrice;
  String supplier;
  String category;
  String barcode;
  int reorderLevel;

  bool get isLowStock => quantity <= reorderLevel;
  bool get isNearExpiry =>
      expiry.isBefore(DateTime.now().add(const Duration(days: 30)));

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "genericName": genericName,
    "batchNo": batchNo,
    "manufacturedOn": manufacturedOn.toIso8601String(),
    "expiry": expiry.toIso8601String(),
    "unit": unit,
    "quantity": quantity,
    "purchasePrice": purchasePrice,
    "sellingPrice": sellingPrice,
    "supplier": supplier,
    "category": category,
    "barcode": barcode,
    "reorderLevel": reorderLevel,
  };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
    id: json["id"] as String,
    name: json["name"] as String,
    genericName: json["genericName"] as String,
    batchNo: json["batchNo"] as String,
    manufacturedOn: json["manufacturedOn"] == null
        ? DateTime.now()
        : DateTime.parse(json["manufacturedOn"] as String),
    expiry: DateTime.parse(json["expiry"] as String),
    unit: (json["unit"] as String?)?.trim().isEmpty ?? true
        ? "pcs"
        : (json["unit"] as String),
    quantity: json["quantity"] as int,
    purchasePrice: (json["purchasePrice"] as num).toDouble(),
    sellingPrice: (json["sellingPrice"] as num).toDouble(),
    supplier: json["supplier"] as String,
    category: json["category"] as String,
    barcode: json["barcode"] as String,
    reorderLevel: (json["reorderLevel"] as int?) ?? 10,
  );
}

class SaleLine {
  SaleLine({
    required this.medicineId,
    required this.name,
    required this.batchNo,
    required this.manufacturedOn,
    required this.expiry,
    required this.unit,
    required this.qty,
    required this.unitPrice,
  });

  final String medicineId;
  final String name;
  final String batchNo;
  final DateTime manufacturedOn;
  final DateTime expiry;
  final String unit;
  final int qty;
  final double unitPrice;

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
    "medicineId": medicineId,
    "name": name,
    "batchNo": batchNo,
    "manufacturedOn": manufacturedOn.toIso8601String(),
    "expiry": expiry.toIso8601String(),
    "unit": unit,
    "qty": qty,
    "unitPrice": unitPrice,
  };

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
    medicineId: json["medicineId"] as String,
    name: json["name"] as String,
    batchNo: (json["batchNo"] as String?) ?? "",
    manufacturedOn: json["manufacturedOn"] == null
        ? DateTime.now()
        : DateTime.parse(json["manufacturedOn"] as String),
    expiry: json["expiry"] == null
        ? DateTime.now()
        : DateTime.parse(json["expiry"] as String),
    unit: (json["unit"] as String?)?.trim().isEmpty ?? true
        ? "pcs"
        : (json["unit"] as String),
    qty: json["qty"] as int,
    unitPrice: (json["unitPrice"] as num).toDouble(),
  );
}

class SaleRecord {
  SaleRecord({
    required this.id,
    required this.customer,
    required this.cashier,
    required this.date,
    required this.lines,
  });

  final String id;
  final String customer;
  final String cashier;
  final DateTime date;
  final List<SaleLine> lines;

  double get total => lines.fold(0, (sum, e) => sum + e.total);

  Map<String, dynamic> toJson() => {
    "id": id,
    "customer": customer,
    "cashier": cashier,
    "date": date.toIso8601String(),
    "lines": lines.map((e) => e.toJson()).toList(),
  };

  factory SaleRecord.fromJson(Map<String, dynamic> json) => SaleRecord(
    id: json["id"] as String,
    customer: json["customer"] as String,
    cashier: json["cashier"] as String? ?? "System",
    date: DateTime.parse(json["date"] as String),
    lines: (json["lines"] as List<dynamic>)
        .map((e) => SaleLine.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PurchaseRecord {
  PurchaseRecord({
    required this.id,
    required this.supplier,
    required this.medicineId,
    required this.qty,
    required this.unitCost,
    required this.date,
  });

  final String id;
  final String supplier;
  final String medicineId;
  final int qty;
  final double unitCost;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    "id": id,
    "supplier": supplier,
    "medicineId": medicineId,
    "qty": qty,
    "unitCost": unitCost,
    "date": date.toIso8601String(),
  };

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) => PurchaseRecord(
    id: json["id"] as String,
    supplier: json["supplier"] as String,
    medicineId: json["medicineId"] as String,
    qty: json["qty"] as int,
    unitCost: (json["unitCost"] as num).toDouble(),
    date: DateTime.parse(json["date"] as String),
  );
}

enum UserRole { admin, pharmacist, cashier }

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.pin,
    required this.role,
  });

  final String id;
  final String username;
  final String pin;
  final UserRole role;

  Map<String, dynamic> toJson() => {
    "id": id,
    "username": username,
    "pin": pin,
    "role": role.name,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json["id"] as String,
    username: json["username"] as String,
    pin: json["pin"] as String,
    role: UserRole.values.firstWhere(
      (e) => e.name == json["role"],
      orElse: () => UserRole.cashier,
    ),
  );
}

enum StockOperationKind { grn, damage, adjustment }

class StockOperationRecord {
  StockOperationRecord({
    required this.id,
    required this.kind,
    required this.medicineId,
    required this.qtyDelta,
    required this.date,
    this.supplier,
    this.unitCost,
    this.note,
  });

  final String id;
  final StockOperationKind kind;
  final String medicineId;
  final int qtyDelta;
  final DateTime date;
  final String? supplier;
  final double? unitCost;
  final String? note;

  Map<String, dynamic> toJson() => {
    "id": id,
    "kind": kind.name,
    "medicineId": medicineId,
    "qtyDelta": qtyDelta,
    "date": date.toIso8601String(),
    "supplier": supplier,
    "unitCost": unitCost,
    "note": note,
  };

  factory StockOperationRecord.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json["kind"] as String?) ?? StockOperationKind.adjustment.name;
    return StockOperationRecord(
      id: json["id"] as String,
      kind: StockOperationKind.values.firstWhere(
        (e) => e.name == kindRaw,
        orElse: () => StockOperationKind.adjustment,
      ),
      medicineId: json["medicineId"] as String,
      qtyDelta: (json["qtyDelta"] as num?)?.toInt() ?? 0,
      date: json["date"] == null
          ? DateTime.now()
          : DateTime.parse(json["date"] as String),
      supplier: json["supplier"] as String?,
      unitCost: (json["unitCost"] as num?)?.toDouble(),
      note: json["note"] as String?,
    );
  }
}
