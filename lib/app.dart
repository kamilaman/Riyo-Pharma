import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "core/state/app_state.dart";
import "features/auth/views/login_page.dart";
import "features/shell/views/home_shell_view.dart";

class RiyoPharmaApp extends StatelessWidget {
  const RiyoPharmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 2, 114, 174),
      primary: const Color(0xFF003B5A),
      secondary: const Color.fromARGB(191, 0, 109, 54),
    );
    return MaterialApp(
      title: "RiyoPharma",
      theme: ThemeData(
        colorScheme: base,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        cardTheme: CardThemeData(
          elevation: 0,
          color: base.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: base.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: base.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: base.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: base.primary, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: Consumer<AppState>(
        builder: (context, state, child) {
          if (state.currentUser == null) {
            return const LoginPage();
          }

          return const HomeShell();
        },
      ),
    );
  }
}
