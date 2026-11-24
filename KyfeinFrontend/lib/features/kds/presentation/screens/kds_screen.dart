import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/on_duty_guard.dart';
import '../../../../core/widgets/page_refresh_scope.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../providers/kds_provider.dart';

class KdsScreen extends StatefulWidget {
  final String areaProduksi; // 'kitchen', 'bar', or 'all'
  const KdsScreen({super.key, this.areaProduksi = 'kitchen'});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _activeArea;
  KdsProvider? _kdsProvider;

  bool _canAccessKds() {
    try {
      final auth = context.read<AuthProvider>();
      if (auth.role != 'karyawan') return true;
      return context.read<DashboardProvider>().isOnDuty;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _activeArea = widget.areaProduksi;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canAccessKds()) {
        context.read<KdsProvider>().initArea(_activeArea);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kdsProvider = context.read<KdsProvider>();
  }

  @override
  void didUpdateWidget(covariant KdsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.areaProduksi != widget.areaProduksi) {
      _switchArea(widget.areaProduksi);
    }
  }

  @override
  void dispose() {
    _kdsProvider?.stopRealtime();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _switchArea(String area) async {
    if (_activeArea == area) return;
    setState(() => _activeArea = area);
    await context.read<KdsProvider>().initArea(area);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<KdsProvider>();

    return OnDutyGuard(
      featureName: 'Layar Pesanan KDS',
      child: PageRefreshRegistrar(
        onRefresh: () => prov.loadOrders(area: _activeArea),
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: buildStandaloneAppBar(
            context,
            title: 'Layar Pesanan KDS',
            onRefresh: () => prov.loadOrders(area: _activeArea),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: prov.isConnected
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: prov.isConnected
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: prov.isConnected
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            prov.isConnected ? 'REALTIME LIVE' : 'POLLING',
                            style: TextStyle(
                              color: prov.isConnected
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 215),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _tabController.index,
                                isDense: true,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textColor,
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    _tabController.animateTo(val);
                                    setState(() {});
                                  }
                                },
                                items: [
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text(
                                      'Menunggu (${prov.menungguOrders.length})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text(
                                      'Diproses (${prov.diprosesOrders.length})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text(
                                      'Selesai (${prov.selesaiOrders.length})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text(
                                      'Semua Status (${prov.orders.length})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (context.watch<AuthProvider>().role != 'karyawan')
                _buildAreaHeader(prov),
              Expanded(
                child: prov.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOrderList(prov, prov.menungguOrders, 'Belum ada pesanan baru berstatus Menunggu.'),
                          _buildOrderList(prov, prov.diprosesOrders, 'Belum ada pesanan yang sedang Diproses.'),
                          _buildOrderList(prov, prov.selesaiOrders, 'Belum ada pesanan yang Selesai dibuat.'),
                          _buildOrderList(prov, prov.orders, 'Belum ada antrian pesanan di area ini.'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaHeader(KdsProvider prov) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Filter Area Produksi:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          _buildAreaChip('kitchen', 'Kitchen (Makanan)', Icons.soup_kitchen_rounded),
          _buildAreaChip('bar', 'Bar (Minuman)', Icons.local_cafe_rounded),
          _buildAreaChip('all', 'Semua Area (Monitor Admin)', Icons.grid_view_rounded),
        ],
      ),
    );
  }

  Widget _buildAreaChip(String area, String label, IconData icon) {
    final selected = _activeArea == area;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12.5,
      ),
      onSelected: (val) {
        if (val) _switchArea(area);
      },
    );
  }

  Widget _buildOrderList(
    KdsProvider prov,
    List<KdsOrderItem> items,
    String emptyMessage,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_rounded, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => prov.loadOrders(area: _activeArea),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 268,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (context, idx) {
          final order = items[idx];
          return _buildOrderCard(prov, order);
        },
      ),
    );
  }

  Widget _buildOrderCard(KdsProvider prov, KdsOrderItem order) {
    final isMenunggu = order.statusItem == 'menunggu';
    final isDiproses = order.statusItem == 'diproses';

    final statusColor = isMenunggu
        ? Colors.orange.shade800
        : isDiproses
            ? Colors.blue.shade700
            : Colors.green.shade700;

    final statusLabel = isMenunggu
        ? 'MENUNGGU'
        : isDiproses
            ? 'DIPROSES'
            : 'SELESAI';

    final timeStr = order.waktuTransaksi != null
        ? DateFormat('HH:mm').format(order.waktuTransaksi!)
        : '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nomor Transaksi & Status Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  order.nomorTransaksi,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          // Body: Kode Menu + Qty + Nama Menu + Catatan
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (order.kodeMenu.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.kodeMenu,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          '${order.qty}x ${order.namaMenu}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (order.catatan != null && order.catatan!.trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        'Catatan: ${order.catatan}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.amber.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      'Area: ${order.areaProduksi.toUpperCase()} • Tanpa catatan khusus',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Action Button (Menunggu -> Diproses -> Selesai)
          SizedBox(
            width: double.infinity,
            child: isMenunggu
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: prov.isUpdatingDetail(order.id)
                        ? null
                        : () => _handleUpdateStatus(prov, order, 'diproses'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Mulai Proses (Diproses)'),
                  )
                : isDiproses
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: prov.isUpdatingDetail(order.id)
                            ? null
                            : () => _handleUpdateStatus(prov, order, 'selesai'),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Tandai Selesai'),
                      )
                    : OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.done_all_rounded, size: 18, color: Colors.green.shade700),
                        label: Text(
                          'Pesanan Selesai',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdateStatus(
    KdsProvider prov,
    KdsOrderItem order,
    String targetStatus,
  ) async {
    final ok = await prov.updateStatusItem(order.id, targetStatus);
    if (!mounted) return;
    if (ok) {
      final isDone = targetStatus == 'selesai';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDone
                ? '${order.qty}x ${order.namaMenu} telah SELESAI dibuat!'
                : '${order.qty}x ${order.namaMenu} diubah ke DIPROSES',
          ),
          backgroundColor: isDone ? Colors.green.shade700 : Colors.blue.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.errorMessage ?? 'Gagal memperbarui status pesanan'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
