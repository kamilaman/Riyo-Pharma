import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/state/app_state.dart";
import "../../../shared/widgets/ui_kit.dart";

class MastersPage extends StatefulWidget {
  const MastersPage({super.key});

  @override
  State<MastersPage> createState() => _MastersPageState();
}

class _MastersPageState extends State<MastersPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _animations;
  String _selectedTab = 'Suppliers';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animations = List.generate(6, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.1,
            (index + 1) * 0.1 + 0.3,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return PageSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ui.pageTitle(
              context,
              "Masters Management",
              subtitle:
                  "Manage suppliers, customers, categories, and system data",
            ),

            // Tab Selector
            _buildTabSelector(context),
            Ui.sectionGap,

            // Master Content
            _buildMasterContent(context, s),
            Ui.sectionGap,

            // Quick Actions
            _buildQuickActions(context, s),
            Ui.sectionGap,

            // Statistics Cards
            _buildStatisticsCards(context, s),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Row(
        children: ['Suppliers', 'Customers', 'Categories'].map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMasterContent(BuildContext context, AppState s) {
    switch (_selectedTab) {
      case 'Suppliers':
        return _EnhancedMaster(
          animation: _animations[0],
          title: "Suppliers",
          kind: "supplier",
          values: s.suppliers,
          icon: Icons.business,
          color: Colors.blue,
          description: "Manage your pharmaceutical suppliers and vendors",
        );
      case 'Customers':
        return _EnhancedMaster(
          animation: _animations[1],
          title: "Customers",
          kind: "customer",
          values: s.customers,
          icon: Icons.people,
          color: Colors.green,
          description: "Manage your customer database and relationships",
        );
      case 'Categories':
        return _EnhancedMaster(
          animation: _animations[2],
          title: "Categories",
          kind: "category",
          values: s.categories,
          icon: Icons.category,
          color: Colors.orange,
          description: "Organize medicines by categories and types",
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildQuickActions(BuildContext context, AppState s) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ActionCard(
                animation: _animations[3],
                title: "Import Data",
                subtitle: "Import from CSV or Excel",
                icon: Icons.upload_file,
                color: Colors.purple,
                onTap: () => _showImportDialog(context),
              ),
              _ActionCard(
                animation: _animations[4],
                title: "Export Data",
                subtitle: "Export to CSV or Excel",
                icon: Icons.download,
                color: Colors.teal,
                onTap: () => _showExportDialog(context, s),
              ),
              _ActionCard(
                animation: _animations[5],
                title: "Backup",
                subtitle: "Create system backup",
                icon: Icons.backup,
                color: Colors.red,
                onTap: () => _showBackupDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, AppState s) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          title: "Total Suppliers",
          value: "${s.suppliers.length}",
          icon: Icons.business,
          color: Colors.blue,
          subtitle: "Active vendors",
        ),
        _StatCard(
          title: "Total Customers",
          value: "${s.customers.length}",
          icon: Icons.people,
          color: Colors.green,
          subtitle: "Registered customers",
        ),
        _StatCard(
          title: "Categories",
          value: "${s.categories.length}",
          icon: Icons.category,
          color: Colors.orange,
          subtitle: "Medicine categories",
        ),
        _StatCard(
          title: "System Health",
          value: "Good",
          icon: Icons.health_and_safety,
          color: Colors.purple,
          subtitle: "All systems operational",
        ),
      ],
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Import Data"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select file to import:"),
            SizedBox(height: 16),
            Text("Supported formats: CSV, Excel"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Select File"),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, AppState s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Export Data"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select data to export:"),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text("Suppliers"),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text("Customers"),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text("Categories"),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Export"),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Backup"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Create a backup of your system data?"),
            SizedBox(height: 16),
            Text("This will backup all masters and transaction data."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Create Backup"),
          ),
        ],
      ),
    );
  }
}

class _EnhancedMaster extends StatefulWidget {
  const _EnhancedMaster({
    required this.animation,
    required this.title,
    required this.kind,
    required this.values,
    required this.icon,
    required this.color,
    required this.description,
  });

  final Animation<double> animation;
  final String title;
  final String kind;
  final List<String> values;
  final IconData icon;
  final Color color;
  final String description;

  @override
  State<_EnhancedMaster> createState() => _EnhancedMasterState();
}

class _EnhancedMasterState extends State<_EnhancedMaster> {
  final TextEditingController _controller = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animation.value,
          child: ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.color.withAlpha(38),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            widget.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "${widget.values.length}",
                        style: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Add New Item
                if (_isAdding) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: "New ${widget.kind}",
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(widget.icon, color: widget.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _addNewItem(context),
                        child: const Text("Add"),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isAdding = false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Items List
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      // List Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "All ${widget.title}",
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _isAdding = !_isAdding),
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                backgroundColor: widget.color.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: widget.color,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Items
                      if (widget.values.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "No ${widget.kind}s yet",
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              Text(
                                "Add your first ${widget.kind} to get started",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...widget.values.map(
                          (value) => _MasterItem(
                            value: value,
                            color: widget.color,
                            onEdit: () => _editItem(context, value),
                            onDelete: () => _deleteItem(context, value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addNewItem(BuildContext context) {
    if (_controller.text.trim().isNotEmpty) {
      final state = context.read<AppState>();
      final newValue = _controller.text.trim();

      // Add to appropriate list in state
      switch (widget.kind) {
        case 'supplier':
          state.addSupplier(newValue);
          break;
        case 'customer':
          state.addCustomer(newValue);
          break;
        case 'category':
          state.addCategory(newValue);
          break;
      }

      setState(() {
        _isAdding = false;
        _controller.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${widget.kind} added successfully")),
      );
    }
  }

  void _editItem(BuildContext context, String value) {
    final TextEditingController editController = TextEditingController(
      text: value,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit ${widget.kind}"),
        content: TextFormField(
          controller: editController,
          decoration: InputDecoration(
            labelText: widget.kind,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final newValue = editController.text.trim();
              if (newValue.isNotEmpty && newValue != value) {
                final state = context.read<AppState>();

                // Update in appropriate list in state
                switch (widget.kind) {
                  case 'supplier':
                    state.updateSupplier(value, newValue);
                    break;
                  case 'customer':
                    state.updateCustomer(value, newValue);
                    break;
                  case 'category':
                    state.updateCategory(value, newValue);
                    break;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${widget.kind} updated successfully"),
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteItem(BuildContext context, String value) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete ${widget.kind}"),
        content: Text("Are you sure you want to delete '$value'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final state = context.read<AppState>();

              // Delete from appropriate list in state
              switch (widget.kind) {
                case 'supplier':
                  state.deleteSupplier(value);
                  break;
                case 'customer':
                  state.deleteCustomer(value);
                  break;
                case 'category':
                  state.deleteCategory(value);
                  break;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${widget.kind} deleted successfully")),
              );
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

class _MasterItem extends StatefulWidget {
  const _MasterItem({
    required this.value,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final String value;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_MasterItem> createState() => _MasterItemState();
}

class _MasterItemState extends State<_MasterItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (_isHovered) ...[
              IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: widget.color.withValues(alpha: 0.1),
                  foregroundColor: widget.color,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Animation<double> animation;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.1),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleMaster extends StatefulWidget {
  const _SimpleMaster({
    required this.title,
    required this.kind,
    required this.values,
  });
  final String title;
  final String kind;
  final List<String> values;
  @override
  State<_SimpleMaster> createState() => _SimpleMasterState();
}

class _SimpleMasterState extends State<_SimpleMaster> {
  final ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: "Add"),
            ),
            FilledButton(
              onPressed: () {
                context.read<AppState>().addMasterValue(
                  widget.kind,
                  widget.values,
                  ctrl.text,
                );
                ctrl.clear();
              },
              child: const Text("Save"),
            ),
            Expanded(
              child: ListView(
                children: widget.values
                    .map(
                      (v) => ListTile(
                        title: Text(v),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            context.read<AppState>().removeMasterValue(
                              widget.kind,
                              widget.values,
                              v,
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
