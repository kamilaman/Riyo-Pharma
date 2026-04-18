import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../viewmodels/auth_view_model.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController(text: "admin");
  final pin = TextEditingController(text: "1234");

  @override
  void dispose() {
    user.dispose();
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        "assets/images/riyopharma_logo.png",
                        height: 120,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          "RiyoPharma",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          "Sign in to continue",
                          style: TextStyle(color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: user,
                    decoration: const InputDecoration(labelText: "Username"),
                    onChanged: (_) => viewModel.clearError(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pin,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "PIN"),
                    onChanged: (_) => viewModel.clearError(),
                  ),
                  const SizedBox(height: 10),
                  if (viewModel.errorMessage != null) ...[
                    Text(
                      viewModel.errorMessage!,
                      style: TextStyle(color: cs.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        viewModel.signIn(user.text, pin.text);
                      },
                      child: const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
