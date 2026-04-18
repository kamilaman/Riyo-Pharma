import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "app.dart";
import "core/services/database_service.dart";
import "core/services/network_service.dart";
import "core/services/notification_service.dart";
import "core/state/app_state.dart";
import "features/auth/viewmodels/auth_view_model.dart";
import "features/shell/viewmodels/home_shell_view_model.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    DatabaseService(),
    NotificationService(),
    NetworkService(),
  );
  await state.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProxyProvider<AppState, AuthViewModel>(
          create: (context) => AuthViewModel(context.read<AppState>()),
          update: (context, appState, viewModel) =>
              (viewModel ?? AuthViewModel(appState))..bind(appState),
        ),
        ChangeNotifierProxyProvider<AppState, HomeShellViewModel>(
          create: (context) => HomeShellViewModel(context.read<AppState>()),
          update: (context, appState, viewModel) =>
              (viewModel ?? HomeShellViewModel(appState))..bind(appState),
        ),
      ],
      child: const RiyoPharmaApp(),
    ),
  );
}
