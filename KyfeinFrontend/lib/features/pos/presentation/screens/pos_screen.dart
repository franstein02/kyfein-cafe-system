import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/pos_provider.dart';
import '../../../../core/constants/api_endpoints.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _brown = Color(0xFF1B4332);
const _cream = Color(0xFFE9F5E6);
const _gold = Color(0xFFD4A373);
const _surface = Colors.white;
const _textDim = Color(0xFF7A7A7A);

final _idr =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

// ─── POS Screen ───────────────────────────────────────────────────────────────
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return const _WebPosLayout();
        }
        return const _MobilePosLayout();
      },
    );
  }
}

// ─── Web/Tablet POS Layout ────────────────────────────────────────────────────
class _WebPosLayout extends StatelessWidget {
  const _WebPosLayout();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _cream,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Menu grid (65%)
          Expanded(flex: 65, child: _MenuPanel()),
          // Right: Cart (35%)
          SizedBox(width: 360, child: _CartPanel()),
        ],
      ),
    );
  }
}

// ─── Mobile POS Layout ────────────────────────────────────────────────────────
class _MobilePosLayout extends StatelessWidget {
  const _MobilePosLayout();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _cream,
      body: SafeArea(child: _MobileKasirView()),
    );
  }
}

// ─── Mobile Kasir View ────────────────────────────────────────────────────────
class _MobileKasirView extends StatelessWidget {
  const _MobileKasirView();

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    return Stack(
      children: [
        const _MenuPanel(),
        // Floating cart bar
        if (pos.cartItemCount > 0)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: _brown,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showCartBottomSheet(context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_rounded,
                          color: Colors.white),
                      const SizedBox(width: 12),
                      Text('${pos.cartItemCount} item',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        _idr.format(pos.cartTotal),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_arrow_up_rounded,
                          color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const _CartPanel(),
        ),
      ),
    );
  }
}

// ─── Menu Panel ───────────────────────────────────────────────────────────────
class _MenuPanel extends StatelessWidget {
  const _MenuPanel();

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
          child: Autocomplete<MenuItem>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<MenuItem>.empty();
              }
              final query = textEditingValue.text.toLowerCase();
              return pos.allMenu.where((m) => m.nama.toLowerCase().contains(query));
            },
            displayStringForOption: (MenuItem option) => option.nama,
            onSelected: (MenuItem selection) {
              pos.addToCart(selection);
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                onChanged: (value) => pos.setSearchQuery(value),
                decoration: InputDecoration(
                  hintText: 'Cari nama produk...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () {
                      textEditingController.clear();
                      pos.setSearchQuery('');
                      focusNode.unfocus();
                    },
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (String value) {
                  onFieldSubmitted();
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final MenuItem option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.nama),
                          subtitle: Text(_idr.format(option.harga)),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Category chips
        if (pos.kategori.isNotEmpty)
          Container(
            width: double.infinity,
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _KategoriChip(
                    label: 'Semua',
                    selected: pos.selectedKategoriId == null,
                    onTap: () => pos.selectKategori(null),
                  ),
                  ...pos.kategori.map((k) => _KategoriChip(
                        label: k.nama,
                        selected: pos.selectedKategoriId == k.id,
                        onTap: () => pos.selectKategori(k.id),
                      )),
                ],
              ),
            ),
          ),
        // Menu grid
        Expanded(
          child: pos.isLoadingMenu
              ? const Center(
                  child: CircularProgressIndicator(color: _brown))
              : Column(
                  children: [

                    Expanded(
                      child: pos.menu.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.coffee_rounded,
                                      size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text('Tidak ada menu tersedia',
                                      style: TextStyle(color: Colors.grey.shade500)),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = constraints.maxWidth > 600 ? 4 : 2;
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    childAspectRatio: 0.85,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: pos.menu.length,
                                  itemBuilder: (_, i) =>
                                      _MenuCard(item: pos.menu[i]),
                                );
                              },
                            ),
                    ),

                  ],
                ),
        ),
      ],
    );
  }
}

class _KategoriChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KategoriChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _brown.withValues(alpha: 0.15),
        checkmarkColor: _brown,
        labelStyle: TextStyle(
          color: selected ? _brown : _textDim,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
        side: BorderSide(color: selected ? _brown : Colors.grey.shade300),
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final qty = pos.qtyInCart(item.id);

    return Stack(
      children: [
        Material(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => pos.addToCart(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: qty > 0
                      ? _brown.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: _cream,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: item.foto != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              child: Image.network(
                                item.foto!.startsWith('http') ? item.foto! : '${ApiConfig.baseUrl}/foto/${item.foto}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.coffee_rounded,
                                        size: 32, color: _gold)),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.coffee_rounded,
                                  size: 32, color: _gold)),
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nama,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _idr.format(item.harga),
                          style: const TextStyle(
                              color: _brown,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Qty badge
        if (qty > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration:
                  const BoxDecoration(color: _brown, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$qty',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Cart Panel ───────────────────────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Container(
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded, color: _brown),
                const SizedBox(width: 10),
                Text(
                  'Keranjang',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (pos.cart.isNotEmpty)
                  TextButton(
                    onPressed: pos.clearCart,
                    child: const Text('Hapus Semua',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Cart items
          Expanded(
            child: pos.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Keranjang kosong',
                            style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pos.cart.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) => _CartItemTile(item: pos.cart[i]),
                  ),
          ),
          // Total + Pay button
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      _idr.format(pos.cartTotal),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _brown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: pos.cart.isEmpty
                        ? null
                        : () => _showPaymentDialog(context, pos),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: pos.isSubmitting
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text('Bayar',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, PosProvider pos) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: pos,
        child: _PaymentDialog(total: pos.cartTotal),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final pos = context.read<PosProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.menuItem.nama,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              // Qty controls
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => pos.decreaseQty(item.menuItem.id),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '${item.qty}',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => pos.addToCart(item.menuItem),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: () => pos.removeFromCart(item.menuItem.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          // Subtotal
          Text(
            _idr.format(item.subtotal),
            style: const TextStyle(
                color: _brown, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          // Varian
          if (pos.kategori.isNotEmpty) ...[
            Builder(builder: (context) {
              final kategoriName = pos.kategori.firstWhere(
                  (k) => k.id == item.menuItem.kategoriId, 
                  orElse: () => KategoriMenu(id: '', nama: '')).nama.toLowerCase();
              
              if (kategoriName == 'minuman') {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VarianSelector(
                        title: 'Suhu',
                        options: const ['Hot', 'Ice'],
                        selectedValue: item.suhu,
                        onChanged: (v) => pos.updateVarianMinuman(item.menuItem.id, suhu: v),
                      ),
                      _VarianSelector(
                        title: 'Sugar',
                        options: const ['No Sugar', 'Less Sugar', 'Normal Sugar'],
                        selectedValue: item.sugarLevel,
                        onChanged: (v) => pos.updateVarianMinuman(item.menuItem.id, sugarLevel: v),
                      ),
                      _VarianSelector(
                        title: 'Beans',
                        options: const ['Robusta', 'Arabica'],
                        selectedValue: item.beansType,
                        onChanged: (v) => pos.updateVarianMinuman(item.menuItem.id, beansType: v),
                      ),
                      const SizedBox(height: 4),
                      const Text('Adds on', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDim)),
                      _AddonCheckbox(
                        label: 'Oat Milk',
                        value: item.oatMilk,
                        onChanged: (v) => pos.updateVarianMinuman(item.menuItem.id, oatMilk: v),
                      ),
                      _AddonCheckbox(
                        label: 'Extra Syrup (+4000)',
                        value: item.extraSyrup,
                        onChanged: (v) => pos.updateVarianMinuman(item.menuItem.id, extraSyrup: v),
                      ),
                      _AddonCheckbox(
                        label: 'Extra Shot (+4000)',
                        value: item.extraShot,
                        onChanged: (v) => pos.updateVarianMinuman(item.menuItem.id, extraShot: v),
                      ),
                    ],
                  ),
                );
              } else if (kategoriName == 'makanan') {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: _VarianSelector(
                    title: 'Level Pedas',
                    options: const ['Tidak Pedas', 'Sedang', 'Pedas'],
                    selectedValue: item.levelPedas,
                    onChanged: (v) => pos.updateVarianMakanan(item.menuItem.id, levelPedas: v),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
          // Catatan field
          const SizedBox(height: 6),
          TextFormField(
            initialValue: item.catatan,
            decoration: InputDecoration(
              hintText: 'Catatan tambahan...',
              hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (v) => pos.updateCatatan(item.menuItem.id, v),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cream,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: _brown),
        ),
      ),
    );
  }
}

class _VarianSelector extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _VarianSelector({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDim)),
          Wrap(
            spacing: 0,
            runSpacing: 0,
            children: options.map((opt) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: opt,
                    groupValue: selectedValue,
                    onChanged: onChanged,
                    activeColor: _brown,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                  GestureDetector(
                    onTap: () => onChanged(opt),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(opt, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AddonCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _AddonCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: _brown,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

// ─── Payment Dialog ───────────────────────────────────────────────────────────
class _PaymentDialog extends StatefulWidget {
  final double total;
  const _PaymentDialog({required this.total});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _metode = 'cash';
  final _uangController = TextEditingController();
  double _uangDiterima = 0;

  static const _presets = [20000.0, 50000.0, 100000.0, 150000.0];

  @override
  void dispose() {
    _uangController.dispose();
    super.dispose();
  }

  double get _kembalian =>
      (_uangDiterima - widget.total).clamp(0, double.infinity);

  bool get _canSubmit {
    if (_metode == 'cash') return _uangDiterima >= widget.total;
    return true; // QRIS: always can submit (validation done server-side)
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Pembayaran',
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              // Total display
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Total Bayar',
                        style: TextStyle(fontSize: 13, color: _textDim)),
                    const SizedBox(height: 4),
                    Text(
                      _idr.format(widget.total),
                      style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _brown),
                    ),
                  ],
                ),
              ),
              // Method toggle
              Row(
                children: [
                  Expanded(
                    child: _MethodButton(
                      label: 'Cash',
                      icon: Icons.payments_rounded,
                      selected: _metode == 'cash',
                      onTap: () => setState(() => _metode = 'cash'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MethodButton(
                      label: 'QRIS',
                      icon: Icons.qr_code_scanner_rounded,
                      selected: _metode == 'qris',
                      onTap: () => setState(() => _metode = 'qris'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Cash fields
              if (_metode == 'cash') ...[
                Text('Uang Diterima',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _uangController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _brown, width: 2),
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _uangDiterima = double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 10),
                // Preset buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets
                      .map((p) => OutlinedButton(
                            onPressed: () {
                              _uangController.text = p.toInt().toString();
                              setState(() => _uangDiterima = p);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _brown),
                              foregroundColor: _brown,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_idr.format(p),
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                // Kembalian
                if (_uangDiterima >= widget.total)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _idr.format(_kembalian),
                          style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ),
              ],
              // QRIS fields
              if (_metode == 'qris') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // QRIS placeholder
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.qr_code_2_rounded,
                              size: 100, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scan & bayar ${_idr.format(widget.total)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cek mutasi rekening, lalu klik Konfirmasi',
                        style: TextStyle(fontSize: 12, color: _textDim),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_canSubmit && !pos.isSubmitting)
                      ? () => _submit(context, pos)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: pos.isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text('Konfirmasi Pembayaran',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, PosProvider pos) async {
    final result = await pos.submitTransaksi(
      metodeBayar: _metode,
      uangDiterima: _metode == 'cash' ? _uangDiterima : widget.total,
    );

    if (!context.mounted) return;

    if (result != null) {
      Navigator.pop(context); // close payment dialog
      _showStrukDialog(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pos.lastError ?? 'Gagal menyimpan transaksi'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Coba Lagi',
            textColor: Colors.white,
            onPressed: () => _submit(context, pos),
          ),
        ),
      );
    }
  }
}

void _showStrukDialog(BuildContext context, Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            Text('Transaksi Berhasil',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'No. ${data['nomor_transaksi'] ?? '-'}',
              style: const TextStyle(color: _textDim, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (data['kembalian'] != null && data['kembalian'] > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      _idr.format(data['kembalian']),
                      style: const TextStyle(
                          color: _brown,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Transaksi Baru'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? _brown : Colors.transparent,
          border: Border.all(color: selected ? _brown : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : _textDim, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: selected ? Colors.white : _textDim,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}


