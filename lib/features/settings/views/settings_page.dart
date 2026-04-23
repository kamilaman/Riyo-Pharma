import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";

import "../../../core/models/models.dart";
import "../../../core/state/app_state.dart";
import "../../../shared/widgets/ui_kit.dart";

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final company = TextEditingController(text: state.companyName);
    final printer = TextEditingController(text: state.printerName);
    return PageSurface(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ui.pageTitle(
                  context,
                  "Settings",
                  subtitle:
                      "Manage company profile, printer, backup and restore.",
                ),
                Ui.sectionGap,
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: "Company Name"),
                  onSubmitted: state.updateCompanyName,
                ),
                Ui.itemGap,
                TextField(
                  controller: printer,
                  decoration: const InputDecoration(labelText: "Printer Name"),
                  onSubmitted: state.updatePrinterName,
                ),
                Ui.sectionGap,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _backup(context),
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text("Backup DB"),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _restore(context),
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text("Restore DB"),
                    ),
                  ],
                ),
                if (state.currentUser?.role == UserRole.admin) ...[
                  Ui.sectionGap,
                  Text(
                    "LAN Server Initialization",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ServerSyncPanel(),
                  Ui.sectionGap,
                  Text(
                    "User Management",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _UserManagementPanel(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _backup(BuildContext context) async {
    final state = context.read<AppState>();
    final docs = await getApplicationDocumentsDirectory();
    final path =
        "${docs.path}/riyopharma_backup_${DateTime.now().millisecondsSinceEpoch}.json";
    await state.backup(path);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Backup created: $path")));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ctrl = TextEditingController();
    final p = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Restore"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Backup path"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text("Restore"),
          ),
        ],
      ),
    );
    if (p == null || p.trim().isEmpty || !context.mounted) return;
    await context.read<AppState>().restore(p.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Restored")));
    }
  }
}

class _UserManagementPanel extends StatelessWidget {
  const _UserManagementPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: () => _openUserForm(context, null),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text("Add User"),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.users.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = state.users[i];
            return ListTile(
              title: Text(u.username),
              subtitle: Text("Role: ${u.role.name} â€¢ PIN: ${u.pin}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _openUserForm(context, u),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: state.currentUser?.id == u.id
                        ? null
                        : () => state.deleteUser(u.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openUserForm(BuildContext context, AppUser? existing) async {
    final state = context.read<AppState>();
    final userCtrl = TextEditingController(text: existing?.username ?? "");
    final pinCtrl = TextEditingController(text: existing?.pin ?? "");
    UserRole role = existing?.role ?? UserRole.cashier;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? "Add User" : "Edit User"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: "PIN"),
              ),
              const SizedBox(height: 10),
              DropdownButton<UserRole>(
                isExpanded: true,
                value: role,
                items: UserRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialog(() => role = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                if (userCtrl.text.trim().isEmpty ||
                    pinCtrl.text.trim().isEmpty) {
                  return;
                }
                final u = AppUser(
                  id:
                      existing?.id ??
                      "USR-${DateTime.now().microsecondsSinceEpoch}",
                  username: userCtrl.text.trim(),
                  pin: pinCtrl.text.trim(),
                  role: role,
                );
                if (existing == null) {
                  state.addUser(u);
                } else {
                  state.updateUser(u);
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSyncPanel extends StatefulWidget {
  const _ServerSyncPanel();

  @override
  State<_ServerSyncPanel> createState() => _ServerSyncPanelState();
}

class _ServerSyncPanelState extends State<_ServerSyncPanel> {
  final ipCtrl = TextEditingController();
  final portCtrl = TextEditingController(text: "3000");
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _useHttps = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final net = context.read<AppState>().network;
    ipCtrl.text = net.serverIp ?? ipCtrl.text;
    portCtrl.text = "${net.serverPort}";
    _useHttps = net.useHttps;
  }

  @override
  void dispose() {
    ipCtrl.dispose();
    portCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final net = state.network;

    final isConnected = net.serverIp != null;
    final isLoggedIn = net.token != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isConnected) ...[
          Text(
            "Connected to: ${net.scheme}://${net.serverIp}:${net.serverPort}",
          ),
          Text("Status: ${isLoggedIn ? 'Authenticated' : 'Requires Login'}"),
          const SizedBox(height: 12),
        ],
        if (!isLoggedIn) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    labelText: "Server host or domain",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(labelText: "Port"),
                ),
              ),
              const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final port =
                        int.tryParse(portCtrl.text.trim()) ??
                        (_useHttps ? 443 : 3000);
                    net.configureEndpoint(
                      ipCtrl.text.trim(),
                      port,
                      useHttps: _useHttps,
                    );
                    final ok = await net.connectManual(
                      ipCtrl.text.trim(),
                      port,
                    );
                    if (ok) {
                      state.updateSyncEndpoint(
                        host: ipCtrl.text.trim(),
                        port: port,
                        useHttps: _useHttps,
                      );
                    }
                    if (ok && mounted) setState(() {});
                  },
                  child: const Text("Connect"),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useHttps,
            title: const Text("Use HTTPS for hosted server"),
            subtitle: const Text(
              "Enable this for domain-based internet hosting with SSL.",
            ),
            onChanged: (value) {
              setState(() {
                _useHttps = value;
                if (value && portCtrl.text.trim() == "3000") {
                  portCtrl.text = "443";
                } else if (!value && portCtrl.text.trim() == "443") {
                  portCtrl.text = "3000";
                }
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final ip = await net.discoverServer();
              if (ip != null && mounted) {
                setState(() {
                  ipCtrl.text = ip;
                  portCtrl.text = "${net.serverPort}";
                  _useHttps = false;
                });
              }
            },
            icon: const Icon(Icons.radar),
            label: const Text("Auto-detect LAN Server"),
          ),
          const SizedBox(height: 12),
          if (isConnected) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(labelText: "Sync User"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Sync password or PIN",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final ok = await net.login(
                      userCtrl.text.trim(),
                      passCtrl.text.trim(),
                    );
                    if (ok && mounted) setState(() {});
                  },
                  child: const Text("Login"),
                ),
              ],
            ),
          ],
        ],
        if (isLoggedIn) ...[
          OutlinedButton.icon(
            onPressed: () {
              net.token = null; // Logout
              setState(() {});
            },
            icon: const Icon(Icons.logout),
            label: const Text("Disconnect Sync"),
          ),
        ],
      ],
    );
  }
}
