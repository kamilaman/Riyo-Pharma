import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/helpers/receipt_preview_helper.dart';
import '../../../shared/widgets/ui_kit.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  static const String _allCategories = 'All Categories';

  final Map<String, int> cart = {};
  final TextEditingController search = TextEditingController();
  final TextEditingController customer = TextEditingController(text: 'Company');
  final FocusNode keyboardFocus = FocusNode();

  DateTime _lastKeyAt = DateTime.now();
  String _barcodeBuffer = '';
  String _barcodeStatus =
      'Scanner ready. Exact barcode scans add items directly.';
  String _selectedCategory = _allCategories;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => keyboardFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    search.dispose();
    customer.dispose();
    keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
    final compactMoney = NumberFormat.compactCurrency(
      symbol: 'ETB ',
      decimalDigits: 1,
    );
    final category = _selectedCategory == _allCategories
        ? null
        : _selectedCategory;
    final catalog = state.filterMedicines(
      query: search.text,
      category: category,
    );
    final cartItems = _buildCartItems(state);
    final subtotal = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    final totalUnits = cartItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final vatAmount = subtotal * (ReceiptService.defaultVatRate / 100);
    final grandTotal = subtotal + vatAmount;
    final activeCustomer = customer.text.trim().isEmpty
        ? 'Company'
        : customer.text.trim();

    return KeyboardListener(
      focusNode: keyboardFocus,
      onKeyEvent: (event) => _handleKeyboard(event, state),
      child: PageSurface(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1220;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(
                  context,
                  state: state,
                  compactMoney: compactMoney,
                  activeCustomer: activeCustomer,
                  totalUnits: totalUnits,
                  grandTotal: grandTotal,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildControlPanel(context, state),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _buildCatalogPanel(
                                      context,
                                      catalog: catalog,
                                      money: money,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 410,
                              child: _buildInvoicePanel(
                                context,
                                state: state,
                                cartItems: cartItems,
                                money: money,
                                subtotal: subtotal,
                                vatAmount: vatAmount,
                                grandTotal: grandTotal,
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildControlPanel(context, state),
                              const SizedBox(height: 16),
                              _buildCatalogPanel(
                                context,
                                catalog: catalog,
                                money: money,
                                expandContent: false,
                              ),
                              const SizedBox(height: 16),
                              _buildInvoicePanel(
                                context,
                                state: state,
                                cartItems: cartItems,
                                money: money,
                                subtotal: subtotal,
                                vatAmount: vatAmount,
                                grandTotal: grandTotal,
                                expandContent: false,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleKeyboard(KeyEvent event, AppState state) {
    if (event is! KeyDownEvent) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastKeyAt).inMilliseconds > 350) {
      _barcodeBuffer = '';
    }
    _lastKeyAt = now;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_barcodeBuffer.length >= 4) {
        final code = _barcodeBuffer;
        final exact = state.findByBarcode(code);
        setState(() {
          if (exact == null) {
            search.text = code;
            _barcodeStatus =
                'No exact barcode match for $code. Showing filtered results.';
          } else {
            final reserved = cart[exact.id] ?? 0;
            if (reserved >= exact.quantity) {
              _barcodeStatus =
                  'Barcode $code matched ${exact.name}, but stock is fully allocated.';
            } else {
              cart[exact.id] = reserved + 1;
              search.clear();
              _barcodeStatus = '${exact.name} added from barcode $code.';
            }
          }
        });
      }
      _barcodeBuffer = '';
      return;
    }

    final label = event.character ?? '';
    if (label.isNotEmpty && RegExp(r'[0-9A-Za-z-]').hasMatch(label)) {
      _barcodeBuffer += label;
    }
  }

  List<_CartItemViewData> _buildCartItems(AppState state) {
    final items = <_CartItemViewData>[];

    for (final entry in cart.entries) {
      final matches = state.medicines.where(
        (medicine) => medicine.id == entry.key,
      );
      if (matches.isEmpty) {
        continue;
      }

      final medicine = matches.first;
      items.add(_CartItemViewData(medicine: medicine, quantity: entry.value));
    }

    return items;
  }

  Widget _buildHeroSection(
    BuildContext context, {
    required AppState state,
    required NumberFormat compactMoney,
    required String activeCustomer,
    required int totalUnits,
    required double grandTotal,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2D3A), Color(0xFF144E63), Color(0xFF1A6A73)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical = constraints.maxWidth < 760;
                return Flex(
                  direction: vertical ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vertical)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales Command Center',
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Process pharmacy sales with scanner support, a cleaner billing workspace, and invoice-first receipt delivery.',
                            style: textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.4,
                            ),
                          ),
                        ],
                      )
                    else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales Command Center',
                              style: textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Process pharmacy sales with scanner support, a cleaner billing workspace, and invoice-first receipt delivery.',
                              style: textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: vertical ? 0 : 18,
                      height: vertical ? 18 : 0,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active cashier',
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.currentUser?.username ?? 'System',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildHeroMetric(
                  context,
                  label: 'Catalog Ready',
                  value: '${state.medicines.length}',
                  note: 'Medicines available',
                ),
                _buildHeroMetric(
                  context,
                  label: 'Cart Value',
                  value: compactMoney.format(grandTotal),
                  note: 'VAT included',
                ),
                _buildHeroMetric(
                  context,
                  label: 'Units in Cart',
                  value: '$totalUnits',
                  note: 'Prepared for checkout',
                ),
                _buildHeroMetric(
                  context,
                  label: 'Today Sales',
                  value: compactMoney.format(state.todaySales),
                  note: 'Recorded revenue',
                ),
                _buildHeroMetric(
                  context,
                  label: 'Customer',
                  value: activeCustomer,
                  note: 'Billing profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetric(
    BuildContext context, {
    required String label,
    required String value,
    required String note,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white60,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, AppState state) {
    final categories = <String>[_allCategories, ...state.categories];
    final tone = _barcodeStatus.contains('added')
        ? const Color(0xFFDCFCE7)
        : _barcodeStatus.contains('No exact') ||
              _barcodeStatus.contains('fully allocated')
        ? const Color(0xFFFFEDD5)
        : const Color(0xFFE0F2FE);
    final toneText = _barcodeStatus.contains('added')
        ? const Color(0xFF166534)
        : _barcodeStatus.contains('No exact') ||
              _barcodeStatus.contains('fully allocated')
        ? const Color(0xFF9A3412)
        : const Color(0xFF0F4C81);

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              final scannerWidth = constraints.maxWidth > 380
                  ? 360.0
                  : constraints.maxWidth;

              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Discovery',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search by medicine, generic name, or batch. Barcode scans still work in the background.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );

              final scannerPanel = SizedBox(
                width: stacked ? scannerWidth : 360,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: toneText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _barcodeStatus,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: toneText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stacked) copy else Expanded(child: copy),
                  SizedBox(width: stacked ? 0 : 16, height: stacked ? 12 : 0),
                  scannerPanel,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final searchWidth = constraints.maxWidth > 760
                  ? 420.0
                  : constraints.maxWidth;
              final filterWidth = constraints.maxWidth > 560
                  ? 220.0
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: searchWidth,
                    child: TextField(
                      controller: search,
                      decoration: InputDecoration(
                        labelText: 'Search catalog',
                        hintText: 'Medicine, generic name, batch, or barcode',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () => setState(() => search.clear()),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: categories
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry,
                              child: Text(entry),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedCategory = value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        search.clear();
                        _selectedCategory = _allCategories;
                        _barcodeStatus =
                            'Scanner ready. Exact barcode scans add items directly.';
                      });
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset filters'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel(
    BuildContext context, {
    required List<Medicine> catalog,
    required NumberFormat money,
    bool expandContent = true,
  }) {
    return ContentCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool scrollable = !expandContent || constraints.maxHeight < 300;

          final children = [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Inventory',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${catalog.length} medicines ready for dispensing',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!scrollable)
              Expanded(
                child: _buildCatalogContent(context, catalog, money, true),
              )
            else
              _buildCatalogContent(context, catalog, money, false),
          ];

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );

          return scrollable ? SingleChildScrollView(child: content) : content;
        },
      ),
    );
  }

  Widget _buildCatalogContent(
    BuildContext context,
    List<Medicine> catalog,
    NumberFormat money,
    bool expandContent,
  ) {
    if (catalog.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No catalog matches',
        message:
            'Try a broader search term or clear the active category filter.',
      );
    }
    return GridView.builder(
      shrinkWrap: !expandContent,
      physics: expandContent ? null : const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 400,
      ),
      itemCount: catalog.length,
      itemBuilder: (context, index) {
        final medicine = catalog[index];
        final reserved = cart[medicine.id] ?? 0;
        final available = medicine.quantity - reserved;

        return _buildMedicineCard(
          context,
          medicine: medicine,
          available: available,
          reserved: reserved,
          money: money,
        );
      },
    );
  }

  Widget _buildMedicineCard(
    BuildContext context, {
    required Medicine medicine,
    required int available,
    required int reserved,
    required NumberFormat money,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOut = available <= 0;
    final isLow = !isOut && available <= medicine.reorderLevel;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOut
              ? const Color(0xFFFECACA)
              : isLow
              ? const Color(0xFFFCD34D)
              : const Color(0xFFD6DEE7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            isOut
                ? const Color(0xFFFFF5F5)
                : isLow
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF7FAFC),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicine.genericName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusBadge(
                  context,
                  label: isOut
                      ? 'Out'
                      : isLow
                      ? 'Low'
                      : 'Ready',
                  background: isOut
                      ? const Color(0xFFFEE2E2)
                      : isLow
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  foreground: isOut
                      ? const Color(0xFFB91C1C)
                      : isLow
                      ? const Color(0xFF92400E)
                      : const Color(0xFF166534),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPill(
                  context,
                  icon: Icons.sell_outlined,
                  label: medicine.category,
                ),
                _buildPill(
                  context,
                  icon: Icons.qr_code_2_rounded,
                  label: medicine.barcode,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMedicineMetric(
                    context,
                    label: 'Unit Price',
                    value: money.format(medicine.sellingPrice),
                  ),
                  const SizedBox(height: 10),
                  _buildMedicineMetric(
                    context,
                    label: 'Available Stock',
                    value: '$available units',
                  ),
                  const SizedBox(height: 10),
                  _buildMedicineMetric(
                    context,
                    label: 'Batch / Expiry',
                    value:
                        '${medicine.batchNo}  |  ${DateFormat('dd MMM yyyy').format(medicine.expiry)}',
                  ),
                  if (reserved > 0) ...[
                    const SizedBox(height: 10),
                    _buildMedicineMetric(
                      context,
                      label: 'Reserved in Cart',
                      value: '$reserved units',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isOut
                    ? null
                    : () {
                        setState(() {
                          cart[medicine.id] = (cart[medicine.id] ?? 0) + 1;
                          _barcodeStatus = '${medicine.name} added to cart.';
                        });
                      },
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(isOut ? 'Unavailable' : 'Add to invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineMetric(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF335C67)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInvoicePanel(
    BuildContext context, {
    required AppState state,
    required List<_CartItemViewData> cartItems,
    required NumberFormat money,
    required double subtotal,
    required double vatAmount,
    required double grandTotal,
    bool expandContent = true,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return ContentCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool scrollable = !expandContent || constraints.maxHeight < 550;

          final children = [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFAFCFF), Color(0xFFF0F7FA)],
                ),
                border: Border.all(color: const Color(0xFFD6E4EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice Workspace',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Receipt file name follows the final sales invoice ID.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(
                        context,
                        label: cartItems.isEmpty ? 'Draft' : 'Ready',
                        background: cartItems.isEmpty
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFDCFCE7),
                        foreground: cartItems.isEmpty
                            ? const Color(0xFF0F4C81)
                            : const Color(0xFF166534),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: customer,
                    decoration: const InputDecoration(
                      labelText: 'Customer name',
                      hintText: 'Company',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.customers.take(4).map((entry) {
                      return ActionChip(
                        label: Text(entry),
                        onPressed: () => setState(() => customer.text = entry),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSummaryLine(
                    context,
                    label: 'Subtotal',
                    value: money.format(subtotal),
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryLine(
                    context,
                    label:
                        'VAT (${ReceiptService.defaultVatRate.toStringAsFixed(0)}%)',
                    value: money.format(vatAmount),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _buildSummaryLine(
                    context,
                    label: 'Grand Total',
                    value: money.format(grandTotal),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Invoice Lines',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (!scrollable)
              Expanded(
                child: _buildInvoiceContent(
                  context,
                  cartItems,
                  money,
                  true,
                  textTheme,
                ),
              )
            else
              _buildInvoiceContent(context, cartItems, money, false, textTheme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: cartItems.isEmpty
                        ? null
                        : () => setState(() => cart.clear()),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear invoice'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: cartItems.isEmpty
                        ? null
                        : () => _completeCheckout(context, state),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Finalize and Preview'),
                  ),
                ),
              ],
            ),
          ];

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );

          return scrollable ? SingleChildScrollView(child: content) : content;
        },
      ),
    );
  }

  Widget _buildInvoiceContent(
    BuildContext context,
    List<_CartItemViewData> cartItems,
    NumberFormat money,
    bool expandContent,
    TextTheme textTheme,
  ) {
    if (cartItems.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Invoice is empty',
        message:
            'Add medicines from the catalog to prepare a clean sales receipt.',
      );
    }
    return ListView.separated(
      shrinkWrap: !expandContent,
      physics: expandContent ? null : const NeverScrollableScrollPhysics(),
      itemCount: cartItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = cartItems[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.medicine.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity} x ${money.format(item.medicine.sellingPrice)}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money.format(item.lineTotal),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final next = (cart[item.medicine.id] ?? 1) - 1;
                        if (next <= 0) {
                          cart.remove(item.medicine.id);
                        } else {
                          cart[item.medicine.id] = next;
                        }
                      });
                    },
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('Reduce'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: item.quantity >= item.medicine.quantity
                        ? null
                        : () {
                            setState(() {
                              cart[item.medicine.id] =
                                  (cart[item.medicine.id] ?? 0) + 1;
                            });
                          },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add one'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryLine(
    BuildContext context, {
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: emphasize
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }

  Future<void> _completeCheckout(BuildContext context, AppState state) async {
    final customerName = customer.text.trim().isEmpty
        ? 'Company'
        : customer.text.trim();

    final lines = cart.entries.map((entry) {
      final medicine = state.medicines.firstWhere((m) => m.id == entry.key);
      return SaleLine(
        medicineId: medicine.id,
        name: medicine.name,
        qty: entry.value,
        unitPrice: medicine.sellingPrice,
      );
    }).toList();

    final nextInvoiceId = state.getNextInvoiceId();

    final draftSale = SaleRecord(
      id: nextInvoiceId,
      date: DateTime.now(),
      cashier: state.currentUser?.username ?? 'System',
      customer: customerName,
      lines: lines,
    );

    final confirmed = await openSaleReceiptPreview(
      context,
      draftSale,
      isDraft: true,
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    if (!state.customers.contains(customerName)) {
      state.addCustomer(customerName);
    }

    final result = state.completeSale(
      customerName,
      cart,
      invoiceId: nextInvoiceId,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result == 'OK' ? 'Sale completed successfully.' : result),
      ),
    );

    if (result != 'OK') {
      return;
    }

    final sale = state.sales.last;

    // Automatically print since they confirmed the draft preview
    await ReceiptService().printReceipt(
      companyName: state.companyName,
      sale: sale,
    );

    if (!context.mounted) return;

    setState(() {
      cart.clear();
      customer.text = 'Company';
      _barcodeStatus = 'Sale ${sale.id} completed. Receipt sent to printer.';
    });
  }
}

class _CartItemViewData {
  const _CartItemViewData({required this.medicine, required this.quantity});

  final Medicine medicine;
  final int quantity;

  double get lineTotal => quantity * medicine.sellingPrice;
}
