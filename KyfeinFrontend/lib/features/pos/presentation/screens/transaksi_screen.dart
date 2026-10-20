import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/transaksi_provider.dart';

class TransaksiScreen extends StatelessWidget {
  const TransaksiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TransaksiProvider(auth: ctx.read<AuthProvider>())..loadInitialData(),
      child: const _TransaksiView(),
    );
  }
}

class _TransaksiView extends StatefulWidget {
  const _TransaksiView();

  @override
  State<_TransaksiView> createState() => _TransaksiViewState();
}

class _TransaksiViewState extends State<_TransaksiView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransaksiProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF5C3D2E),
          onRefresh: provider.loadTransaksi,
          child: CustomScrollView(
            slivers: [
              // ── Header Bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(provider, isDesktop),
                      const SizedBox(height: 16),
                      _buildDateFilters(provider),
                      const SizedBox(height: 20),
                      _buildKpiMetrics(provider, isDesktop),
                      const SizedBox(height: 24),
                      _buildHeroTabSection(provider, isDesktop),
                      const SizedBox(height: 24),
                      _buildDaftarTransaksiHeader(provider),
                    ],
                  ),
                ),
              ),

              // ── Transaction List Items ──────────────────────────────
              if (provider.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF5C3D2E),
                    ),
                  ),
                )
              else if (provider.errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          provider.errorMessage!,
                          style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: provider.loadTransaksi,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C3D2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (provider.filteredTransaksi.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C3D2E).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFF5C3D2E)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Transaksi',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tidak ada transaksi penjualan pada tanggal atau filter yang dipilih.',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trx = provider.filteredTransaksi[index];
                        return _buildTransaksiCard(trx, provider);
                      },
                      childCount: provider.filteredTransaksi.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Bar ──────────────────────────────────────────────────────────────
  Widget _buildHeader(TransaksiProvider provider, bool isDesktop) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF5C3D2E),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C3D2E).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riwayat & Rekap Transaksi',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F1F1F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pantau detail penjualan menu & estimasi pemakaian bahan untuk uji coba stok',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: provider.isLoading ? null : provider.loadTransaksi,
          icon: provider.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF5C3D2E),
          ),
          tooltip: 'Refresh Data',
        ),
      ],
    );
  }

  // ── Date Filters ────────────────────────────────────────────────────────────
  Widget _buildDateFilters(TransaksiProvider provider) {
    final now = DateTime.now();
    final isToday = provider.selectedDate != null &&
        provider.selectedDate!.year == now.year &&
        provider.selectedDate!.month == now.month &&
        provider.selectedDate!.day == now.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = provider.selectedDate != null &&
        provider.selectedDate!.year == yesterday.year &&
        provider.selectedDate!.month == yesterday.month &&
        provider.selectedDate!.day == yesterday.day;

    final isAll = provider.selectedDate == null;
    final isCustom = !isToday && !isYesterday && !isAll;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Hari Ini',
            icon: Icons.today_rounded,
            isSelected: isToday,
            onTap: () => provider.setDateFilter(DateTime.now()),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Kemarin',
            icon: Icons.history_rounded,
            isSelected: isYesterday,
            onTap: () => provider.setDateFilter(DateTime.now().subtract(const Duration(days: 1))),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Semua Waktu',
            icon: Icons.calendar_view_month_rounded,
            isSelected: isAll,
            onTap: () => provider.setDateFilter(null),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: isCustom
                ? DateFormat('d MMM yyyy', 'id_ID').format(provider.selectedDate!)
                : 'Pilih Tanggal',
            icon: Icons.edit_calendar_rounded,
            isSelected: isCustom,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: provider.selectedDate ?? DateTime.now(),
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF5C3D2E),
                        onPrimary: Colors.white,
                        onSurface: Color(0xFF1F1F1F),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                provider.setDateFilter(picked);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5C3D2E) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF5C3D2E) : Colors.grey.shade300,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF5C3D2E).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF5C3D2E),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── KPI Metrics ─────────────────────────────────────────────────────────────
  Widget _buildKpiMetrics(TransaksiProvider provider, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = isDesktop ? 4 : (constraints.maxWidth > 550 ? 4 : 2);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isDesktop ? 2.2 : (crossCount == 2 ? 1.6 : 1.9),
          children: [
            _buildKpiCard(
              title: 'Total Omset',
              value: currencyFormat.format(provider.totalOmset),
              icon: Icons.payments_rounded,
              color: const Color(0xFF1B4332),
              subtitle: 'Penjualan Selesai',
            ),
            _buildKpiCard(
              title: 'Menu Terjual',
              value: '${provider.totalItemTerjual} Cup / Item',
              icon: Icons.coffee_rounded,
              color: const Color(0xFF5C3D2E),
              subtitle: 'Total Kuantitas',
            ),
            _buildKpiCard(
              title: 'Total Transaksi',
              value: '${provider.totalTransaksiCount} Order',
              icon: Icons.receipt_rounded,
              color: const Color(0xFF2B5B84),
              subtitle: '${provider.allTransaksi.length} total tercatat',
            ),
            _buildKpiCard(
              title: 'Cash vs QRIS',
              value: currencyFormat.format(provider.totalCash),
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFB45309),
              subtitle: 'QRIS: ${currencyFormat.format(provider.totalQris)}',
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero Tab Section: Rekap Menu Terjual & Perkiraan Bahan BOM ──────────────
  Widget _buildHeroTabSection(TransaksiProvider provider, bool isDesktop) {
    final menuList = provider.rekapMenuTerjual;
    final bomList = provider.rekapBahanBOM;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF5C3D2E),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF5C3D2E),
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          children: [
                            const Icon(Icons.coffee_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Rekap Menu Terjual (${menuList.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            const Icon(Icons.calculate_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Perkiraan Bahan BOM (${bomList.length})'),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B4332),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'UJI STOK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Contents
          SizedBox(
            height: isDesktop ? 320 : 360,
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Rekap Menu Terjual
                _buildRekapMenuTab(menuList),

                // TAB 2: Perkiraan Bahan BOM
                _buildBOMTab(bomList),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 1 View: Menu Terjual
  Widget _buildRekapMenuTab(List<RekapMenuItem> menuList) {
    if (menuList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Belum ada menu yang terjual pada periode ini',
              style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: menuList.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final item = menuList[index];
        return Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF5C3D2E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.coffee, color: Color(0xFF5C3D2E), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaMenu,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Omset: ${currencyFormat.format(item.totalSubtotal)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF5C3D2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${item.totalQty} Terjual',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Tab 2 View: BOM Perkiraan Pengurangan Bahan
  Widget _buildBOMTab(List<RekapBahanBOMItem> bomList) {
    if (bomList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Belum Ada Resep BOM Terhubung',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pastikan Master Data Menu sudah memiliki resep bahan agar perkiraan stok akhir dapat dihitung secara otomatis.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Guidance Box
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F5E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1B4332).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF1B4332), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gunakan angka terpakai di bawah ini untuk menguji input Stok Akhir pada menu Catat Opname (Stok Awal Fisik dikurangi estimasi BOM).',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B4332),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of materials used
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: bomList.length,
            separatorBuilder: (_, __) => const Divider(height: 14),
            itemBuilder: (context, index) {
              final item = bomList[index];
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      color: Color(0xFF1B4332),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.namaBahan,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sumber: ${item.sumberMenu.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F5E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1B4332).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${item.estimasiTerpakai % 1 == 0 ? item.estimasiTerpakai.toInt() : item.estimasiTerpakai.toStringAsFixed(1)} ${item.satuan}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF1B4332),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Daftar Transaksi Header & Filter ────────────────────────────────────────
  Widget _buildDaftarTransaksiHeader(TransaksiProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daftar Transaksi',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F1F1F),
              ),
            ),
            Text(
              '${provider.filteredTransaksi.length} transaksi',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search & Status filters
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: provider.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Cari no. trx, menu, kasir...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Status dropdown / chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.selectedStatus,
                  icon: const Icon(Icons.filter_list, size: 18),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'semua', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                    DropdownMenuItem(value: 'dibatalkan', child: Text('Dibatalkan')),
                  ],
                  onChanged: (val) {
                    if (val != null) provider.setStatusFilter(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Transaksi Card ──────────────────────────────────────────────────────────
  Widget _buildTransaksiCard(TransaksiModel trx, TransaksiProvider provider) {
    final isSelesai = trx.status == 'selesai';
    final waktuFormatted = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(trx.waktuTransaksi);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelesai ? Colors.grey.shade200 : Colors.red.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelesai
                ? (trx.metodeBayar == 'cash'
                    ? const Color(0xFF1B4332).withValues(alpha: 0.1)
                    : const Color(0xFF5C3D2E).withValues(alpha: 0.1))
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            trx.metodeBayar == 'cash' ? Icons.money_rounded : Icons.qr_code_2_rounded,
            color: isSelesai
                ? (trx.metodeBayar == 'cash' ? const Color(0xFF1B4332) : const Color(0xFF5C3D2E))
                : Colors.redAccent,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                trx.nomorTransaksi,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelesai ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelesai ? Colors.green.shade300 : Colors.red.shade300,
                ),
              ),
              child: Text(
                trx.status.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isSelesai ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$waktuFormatted • ${trx.namaKasir}',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(trx.totalHarga),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelesai ? const Color(0xFF1B4332) : Colors.grey.shade600,
                decoration: isSelesai ? null : TextDecoration.lineThrough,
              ),
            ),
            Text(
              trx.metodeBayar.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5C3D2E),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rincian Menu Penjualan:',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),

                // Details item list
                ...trx.details.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C3D2E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.qty}x',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5C3D2E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaMenu,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F1F1F),
                                ),
                              ),
                              if (item.catatan != null && item.catatan!.isNotEmpty)
                                Text(
                                  'Catatan: ${item.catatan}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.subtotal),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2B2B2B),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Payment Breakdown
                if (trx.metodeBayar == 'cash' && trx.uangDiterima != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Uang Diterima:', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700)),
                      Text(currencyFormat.format(trx.uangDiterima), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Kembalian:', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700)),
                      Text(currencyFormat.format(trx.kembalian ?? 0), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                // Action buttons (Void / Cancel)
                if (isSelesai) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _showVoidDialog(context, trx, provider),
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                      label: Text(
                        'Batalkan Transaksi',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVoidDialog(BuildContext context, TransaksiModel trx, TransaksiProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'Batalkan Transaksi?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi ${trx.nomorTransaksi} senilai ${currencyFormat.format(trx.totalHarga)}?\n\nTransaksi yang dibatalkan tidak akan dihitung dalam omset dan audit BOM.',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.batalkanTransaksi(trx.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Transaksi ${trx.nomorTransaksi} berhasil dibatalkan.'
                          : 'Gagal membatalkan transaksi. Pastikan shift aktif belum ditutup.',
                    ),
                    backgroundColor: success ? Colors.green : Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }
}
