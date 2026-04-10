import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "app.dart";
import "app_state.dart";
import "database_service.dart";
import "notification_service.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(DatabaseService(), NotificationService());
  await state.init();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const PharmaCoreApp()),
  );
}
