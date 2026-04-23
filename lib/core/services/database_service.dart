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
    final dir = Directory(p.join(support.path, "riyopharma"));
    // Recommendation:
    // - SQLite/sqflite per device
    // - One local server (Node.js + PostgreSQL)
    // - Sync using operation queue
    // - LAN-based communication
    // - Optional cloud sync later
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final dbPath = p.join(dir.path, "riyopharma.db");
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
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
            "CREATE TABLE stock_ops (id TEXT PRIMARY KEY, payload TEXT NOT NULL)",
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
          await db.execute(
            "CREATE TABLE operation_queue (seq_id INTEGER PRIMARY KEY AUTOINCREMENT, operation TEXT NOT NULL, table_name TEXT NOT NULL, record_id TEXT NOT NULL, payload TEXT)",
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "CREATE TABLE stock_ops (id TEXT PRIMARY KEY, payload TEXT NOT NULL)",
            );
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> loadSnapshot() async {
    final db = _db!;
    final medicineRows = await db.query("medicines");
    final purchaseRows = await db.query("purchases");
    final saleRows = await db.query("sales");
    final stockOpsRows = await db.query("stock_ops");
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
      "stock_ops": stockOpsRows
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
      "client_id": settings["client_id"],
      "last_sync_seq_id": settings["last_sync_seq_id"],
      "sync_server_host": settings["sync_server_host"],
      "sync_server_port": settings["sync_server_port"],
      "sync_server_scheme": settings["sync_server_scheme"],
      "sync_server_user": settings["sync_server_user"],
      "last_sync_at": settings["last_sync_at"],
    };
  }

  Future<void> saveSnapshot(Map<String, dynamic> payload) async {
    final db = _db!;
    await db.transaction((txn) async {
      await txn.delete("medicines");
      await txn.delete("purchases");
      await txn.delete("sales");
      await txn.delete("stock_ops");
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
      for (final raw in (payload["stock_ops"] as List<dynamic>? ?? const [])) {
        final item = raw as Map<String, dynamic>;
        await txn.insert("stock_ops", {
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

      final extraSettings =
          (payload["settings"] as Map<String, dynamic>? ?? const {});
      for (final entry in extraSettings.entries) {
        final value = entry.value;
        if (value == null) continue;
        await txn.insert("settings", {
          "k": entry.key,
          "v": value.toString(),
        });
      }

      for (final raw in (payload["users"] as List<dynamic>)) {
        final item = raw as Map<String, dynamic>;
        await txn.insert("users", {
          "id": item["id"] as String,
          "payload": jsonEncode(item),
        });
      }
    });
  }

  Future<void> enqueueOperation(
    String operation,
    String tableName,
    String recordId, {
    Map<String, dynamic>? payload,
  }) async {
    final db = _db!;
    await db.insert("operation_queue", {
      "operation": operation,
      "table_name": tableName,
      "record_id": recordId,
      "payload": payload != null ? jsonEncode(payload) : null,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final rows = await _db!.query("operation_queue", orderBy: "seq_id ASC");
    return rows.map((row) {
      final payload = row["payload"] as String?;
      return {
        ...row,
        "payload": payload == null ? null : jsonDecode(payload),
      };
    }).toList();
  }

  Future<void> removeOperations(List<int> seqIds) async {
    if (seqIds.isEmpty) return;
    final db = _db!;
    await db.transaction((txn) async {
      for (final id in seqIds) {
        await txn.delete(
          "operation_queue",
          where: "seq_id = ?",
          whereArgs: [id],
        );
      }
    });
  }
}
