import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

class DatabaseService {
  Database? _db;

  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, "pharmacore"));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final dbPath = p.join(dir.path, "pharmacore.db");
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            "CREATE TABLE medicines (id TEXT PRIMARY KEY, payload TEXT NOT NULL)",
          );
          await db.execute(
            "CREATE TABLE purchases (id TEXT PRIMARY KEY, payload TEXT NOT NULL)",
          );
          await db.execute(
            "CREATE TABLE sales (id TEXT PRIMARY KEY, payload TEXT NOT NULL)",
          );
          await db.execute(
            "CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT NOT NULL)",
          );
          await db.execute(
            "CREATE TABLE masters (kind TEXT NOT NULL, value TEXT NOT NULL)",
          );
          await db.execute(
            "CREATE TABLE users (id TEXT PRIMARY KEY, payload TEXT NOT NULL)",
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> loadSnapshot() async {
    final db = _db!;
    final medicineRows = await db.query("medicines");
    final purchaseRows = await db.query("purchases");
    final saleRows = await db.query("sales");
    final settingRows = await db.query("settings");
    final masterRows = await db.query("masters");
    final userRows = await db.query("users");

    final settings = <String, String>{};
    for (final row in settingRows) {
      settings[row["k"] as String] = row["v"] as String;
    }

    List<String> master(String kind) => masterRows
        .where((row) => row["kind"] == kind)
        .map((e) => e["value"] as String)
        .toList();

    return {
      "medicines": medicineRows
          .map(
            (e) => jsonDecode(e["payload"] as String) as Map<String, dynamic>,
          )
          .toList(),
      "purchases": purchaseRows
          .map(
            (e) => jsonDecode(e["payload"] as String) as Map<String, dynamic>,
          )
          .toList(),
      "sales": saleRows
          .map(
            (e) => jsonDecode(e["payload"] as String) as Map<String, dynamic>,
          )
          .toList(),
      "suppliers": master("supplier"),
      "customers": master("customer"),
      "categories": master("category"),
      "users": userRows
          .map(
            (e) => jsonDecode(e["payload"] as String) as Map<String, dynamic>,
          )
          .toList(),
      "companyName": settings["companyName"],
      "printerName": settings["printerName"],
    };
  }

  Future<void> saveSnapshot(Map<String, dynamic> payload) async {
    final db = _db!;
    await db.transaction((txn) async {
      await txn.delete("medicines");
      await txn.delete("purchases");
      await txn.delete("sales");
      await txn.delete("settings");
      await txn.delete("masters");
      await txn.delete("users");

      for (final raw in (payload["medicines"] as List<dynamic>)) {
        final item = raw as Map<String, dynamic>;
        await txn.insert("medicines", {
          "id": item["id"] as String,
          "payload": jsonEncode(item),
        });
      }
      for (final raw in (payload["purchases"] as List<dynamic>)) {
        final item = raw as Map<String, dynamic>;
        await txn.insert("purchases", {
          "id": item["id"] as String,
          "payload": jsonEncode(item),
        });
      }
      for (final raw in (payload["sales"] as List<dynamic>)) {
        final item = raw as Map<String, dynamic>;
        await txn.insert("sales", {
          "id": item["id"] as String,
          "payload": jsonEncode(item),
        });
      }
      Future<void> putMasters(String kind, List<String> values) async {
        for (final value in values) {
          await txn.insert("masters", {"kind": kind, "value": value});
        }
      }

      await putMasters(
        "supplier",
        (payload["suppliers"] as List<dynamic>).cast<String>(),
      );
      await putMasters(
        "customer",
        (payload["customers"] as List<dynamic>).cast<String>(),
      );
      await putMasters(
        "category",
        (payload["categories"] as List<dynamic>).cast<String>(),
      );

      await txn.insert("settings", {
        "k": "companyName",
        "v": payload["companyName"] as String,
      });
      await txn.insert("settings", {
        "k": "printerName",
        "v": payload["printerName"] as String,
      });

      for (final raw in (payload["users"] as List<dynamic>)) {
        final item = raw as Map<String, dynamic>;
        await txn.insert("users", {
          "id": item["id"] as String,
          "payload": jsonEncode(item),
        });
      }
    });
  }
}
