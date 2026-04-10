import "dart:convert";
import "dart:io";

import "package:path_provider/path_provider.dart";

class StorageService {
  Future<File> _dataFile() async {
    final dir = await getApplicationSupportDirectory();
    final appDir = Directory("${dir.path}/pharmacore");
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File("${appDir.path}/data.json");
  }

  Future<Map<String, dynamic>> load() async {
    final file = await _dataFile();
    if (!await file.exists()) {
      return {};
    }
    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      return {};
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> save(Map<String, dynamic> payload) async {
    final file = await _dataFile();
    await file.writeAsString(jsonEncode(payload));
  }

  Future<void> backupToPath(
    String fullPath,
    Map<String, dynamic> payload,
  ) async {
    final file = File(fullPath);
    await file.writeAsString(jsonEncode(payload));
  }

  Future<Map<String, dynamic>> restoreFromPath(String fullPath) async {
    final file = File(fullPath);
    final text = await file.readAsString();
    return jsonDecode(text) as Map<String, dynamic>;
  }
}
