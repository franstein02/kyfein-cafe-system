import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/stok_models.dart';
import '../../providers/stok_opname_hub_models.dart';
import '../../providers/stok_opname_hub_provider.dart';

class StokOpnameHubScreen extends StatelessWidget {
  const StokOpnameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          StokOpnameHubProvider(auth: ctx.read<AuthProvider>())..loadData(),
      child: const _StokOpnameHubView(),
    );
  }
}

class _StokOpnameHubView extends StatefulWidget {
  const _StokOpnameHubView();

  @override
  State<_StokOpnameHubView> createState() => _StokOpnameHubViewState();
}

const List<String> _namaHari = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
];
const List<String> _namaBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String _formatTanggalIndonesia(DateTime dt) {
  final hari = _namaHari[dt.weekday - 1];
  final bulan = _namaBulan[dt.month - 1];
  return '$hari, ${dt.day} $bulan ${dt.year}';
}

String _formatTanggalPendek(DateTime dt) {
  final bulan = _namaBulan[dt.month - 1];
  return '${dt.day} $bulan';
}

class _StokOpnameHubViewState extends State<_StokOpnameHubView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _pilihTanggal(BuildContext context, StokOpnameHubProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Color(0xFF2D312E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.setTanggal(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StokOpnameHubProvider>();
    final isHariIni = DateUtils.isSameDay(provider.selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Stok Opname'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan data',
            onPressed: provider.isLoading ? null : provider.loadData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.calendar_view_day_rounded, size: 20),
                  text: 'Stok Harian',
                ),
                Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.fact_check_rounded, size: 20),
                  text: 'Audit Pemakaian BOM',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Header Bar: Date Selector & Titik Filter ────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: provider.previousDay,
                            tooltip: 'Hari Sebelumnya',
                          ),
                          InkWell(
                            onTap: () => _pilihTanggal(context, provider),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded,
                                      size: 17, color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    isHariIni
                                        ? 'Hari Ini (${_formatTanggalPendek(provider.selectedDate)})'
                                        : _formatTanggalIndonesia(provider.selectedDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF2D312E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: provider.nextDay,
                            tooltip: 'Hari Berikutnya',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!isHariIni)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: () => provider.setTanggal(DateTime.now()),
                        icon: const Icon(Icons.today_rounded, size: 16),
                        label: const Text('Ke Hari Ini', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterTitikChip(context, provider, 'Semua'),
                    const SizedBox(width: 8),
                    _filterTitikChip(context, provider, 'Bar'),
                    const SizedBox(width: 8),
                    _filterTitikChip(context, provider, 'Kitchen'),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: provider.setQuery,
                    decoration: InputDecoration(
                      hintText: 'Cari nama bahan...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                provider.setQuery('');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── Tab Views ────────────────────────────────────────────────────────
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: const [
                      _TabStokHarianView(),
                      _TabAuditView(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterTitikChip(
      BuildContext context, StokOpnameHubProvider provider, String label) {
    final isSelected = provider.selectedTitik.toLowerCase() == label.toLowerCase();
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => provider.setTitik(label),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
        width: isSelected ? 1.4 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : const Color(0xFF2D312E),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1: STOK HARIAN (STOK AWAL, STOK AKHIR & SELISIH PER HARI)
// ═════════════════════════════════════════════════════════════════════════════
class _TabStokHarianView extends StatelessWidget {
  const _TabStokHarianView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StokOpnameHubProvider>();
    final items = provider.harianItems;
    final sesi = provider.harianSesi;

    final lengkapCount = items.where((i) => i.status == 'lengkap').length;
    final awalSajaCount = items.where((i) => i.status == 'hanya_awal').length;
    final belumOpnameCount = items.where((i) => i.status == 'belum_opname').length;

    return RefreshIndicator(
      onRefresh: provider.loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sesi Opname Banner
          if (sesi.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_toggle_off_rounded,
                          size: 18, color: Color(0xFF1B4332)),
                      const SizedBox(width: 8),
                      Text(
                        'Sesi Opname Tercatat (${sesi.length} Sesi)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: sesi.map((s) {
                      final isAwal = s.tipe == 'awal_shift';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAwal ? Colors.blue.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAwal ? Colors.blue.shade200 : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAwal ? Icons.login_rounded : Icons.logout_rounded,
                              size: 14,
                              color: isAwal ? Colors.blue.shade800 : Colors.green.shade800,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${s.titik.toUpperCase()} • ${isAwal ? 'Awal' : 'Akhir'} Shift '
                              '(${DateFormat('HH:mm').format(s.waktuOpname)})'
                              '${s.karyawanNama != null ? ' - ${s.karyawanNama}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAwal ? Colors.blue.shade900 : Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Mini summary bar
          Row(
            children: [
              _metricPill('Total Bahan', '${items.length}', Colors.grey.shade700, Colors.grey.shade100),
              const SizedBox(width: 8),
              _metricPill('Lengkap', '$lengkapCount', Colors.green.shade700, Colors.green.shade50),
              const SizedBox(width: 8),
              _metricPill('Awal Saja', '$awalSajaCount', Colors.amber.shade800, Colors.amber.shade50),
              const SizedBox(width: 8),
              _metricPill('Belum Ada', '$belumOpnameCount', Colors.grey.shade600, Colors.grey.shade200),
            ],
          ),
          const SizedBox(height: 14),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Tidak ada data bahan untuk filter ini',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else
            ...items.map((item) => _HarianItemCard(item: item)),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor)),
            Text(label, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _HarianItemCard extends StatelessWidget {
  final OpnameHarianItem item;
  const _HarianItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isBar = item.titik.toLowerCase() == 'bar';
    final hasAwal = item.stokAwal != null;
    final hasAkhir = item.stokAkhir != null;
    final hasSelisih = item.selisih != null;

    Color statusColor;
    String statusText;
    if (item.status == 'lengkap') {
      statusColor = Colors.green;
      statusText = 'Lengkap';
    } else if (item.status == 'hanya_awal') {
      statusColor = Colors.amber.shade800;
      statusText = 'Belum Akhir';
    } else if (item.status == 'hanya_akhir') {
      statusColor = Colors.orange.shade800;
      statusText = 'Tanpa Awal';
    } else {
      statusColor = Colors.grey.shade500;
      statusText = 'Belum Opname';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Row 1: Nama, Titik badge, Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.namaBahan,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isBar ? const Color(0xFFF1E9DE) : const Color(0xFFFDE8E1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.titik.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isBar ? const Color(0xFF7A4E2B) : const Color(0xFFC0441C),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Values (Stok Awal, Transfer Masuk, Stok Akhir, Selisih)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _colValue('Stok Awal', hasAwal ? '${formatAngka(item.stokAwal!)} ${item.satuan}' : '-'),
                  if (item.transferMasuk > 0) ...[
                    const Text('+', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    _colValue('Transfer', '+${formatAngka(item.transferMasuk)} ${item.satuan}',
                        color: Colors.blue.shade700),
                  ],
                  const Text('→', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  _colValue('Stok Akhir', hasAkhir ? '${formatAngka(item.stokAkhir!)} ${item.satuan}' : '-'),
                  Container(width: 1, height: 28, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  _colValue(
                    'Selisih Fisik',
                    hasSelisih ? '${formatAngka(item.selisih!)} ${item.satuan}' : '-',
                    color: hasSelisih ? AppTheme.primaryColor : Colors.grey,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colValue(String label, String value, {Color? color, bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? const Color(0xFF2D312E),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2: AUDIT PEMAKAIAN (BOM POS vs SELISIH OPNAME FISIK)
// ═════════════════════════════════════════════════════════════════════════════
class _TabAuditView extends StatelessWidget {
  const _TabAuditView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StokOpnameHubProvider>();
    final items = provider.auditItems;
    final summary = provider.auditSummary;

    return RefreshIndicator(
      onRefresh: provider.loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary KPI cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics_rounded, size: 20, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ringkasan Audit Bahan',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          '${summary.totalTransaksi} Transaksi POS Selesai • ${summary.totalItemTerjual} Cup/Porsi Terjual',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _kpiBox('Diaudit', '${summary.totalBahanDiaudit}', Colors.grey.shade700, Colors.grey.shade100),
                    const SizedBox(width: 8),
                    _kpiBox('Sesuai (Klop)', '${summary.bahanSesuai}', Colors.green.shade700, Colors.green.shade50),
                    const SizedBox(width: 8),
                    _kpiBox('Ada Selisih', '${summary.bahanSelisih}', Colors.red.shade700, Colors.red.shade50),
                    const SizedBox(width: 8),
                    _kpiBox('Belum Lengkap', '${summary.bahanBelumLengkap}', Colors.amber.shade800, Colors.amber.shade50),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Audit Explanatory Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF3EF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC7DEC9)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1B4332)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Audit membandingkan pemakaian fisik (Stok Awal + Transfer - Stok Akhir) dengan total BOM penjualan POS.\n• Varian Minus (−) : Barang hilang/tekor (pemakaian fisik melebihi penjualan POS)\n• Varian Plus (+) : Barang surplus/lebih (pemakaian fisik lebih sedikit dari penjualan POS)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1B4332), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.done_all_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Tidak ada data bahan untuk diaudit',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else
            ...items.map((item) => _AuditItemCard(item: item)),
        ],
      ),
    );
  }

  Widget _kpiBox(String title, String val, Color textC, Color bgC) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(color: bgC, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textC)),
            Text(title, style: TextStyle(fontSize: 10, color: textC, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AuditItemCard extends StatefulWidget {
  final OpnameAuditItem item;
  const _AuditItemCard({required this.item});

  @override
  State<_AuditItemCard> createState() => _AuditItemCardState();
}

class _AuditItemCardState extends State<_AuditItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isBar = item.titik.toLowerCase() == 'bar';

    Color cardBorder;
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    if (item.statusAudit == 'sesuai') {
      cardBorder = Colors.green.shade200;
      badgeBg = Colors.green.shade50;
      badgeText = Colors.green.shade800;
      badgeIcon = Icons.check_circle_rounded;
      badgeLabel = 'Sesuai (Klop)';
    } else if (item.statusAudit == 'lebih_boros') {
      // Pemakaian fisik melebihi penjualan POS -> Barang hilang / tekor (varians negatif)
      cardBorder = Colors.red.shade200;
      badgeBg = Colors.red.shade50;
      badgeText = Colors.red.shade800;
      badgeIcon = Icons.warning_amber_rounded;
      badgeLabel = 'Selisih Kurang (${formatAngka(item.varians ?? 0)} ${item.satuan})';
    } else if (item.statusAudit == 'lebih_hemat') {
      // Pemakaian fisik lebih sedikit dari penjualan POS -> Barang surplus / sisa lebih (varians positif)
      cardBorder = Colors.blue.shade200;
      badgeBg = Colors.blue.shade50;
      badgeText = Colors.blue.shade800;
      badgeIcon = Icons.info_outline_rounded;
      badgeLabel = 'Selisih Lebih (+${formatAngka(item.varians ?? 0)} ${item.satuan})';
    } else {
      cardBorder = Colors.grey.shade200;
      badgeBg = Colors.grey.shade100;
      badgeText = Colors.grey.shade700;
      badgeIcon = Icons.pending_outlined;
      badgeLabel = 'Opname Belum Lengkap';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorder, width: item.statusAudit != 'sesuai' ? 1.2 : 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Top Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.namaBahan,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBar ? const Color(0xFFF1E9DE) : const Color(0xFFFDE8E1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.titik.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isBar ? const Color(0xFF7A4E2B) : const Color(0xFFC0441C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Satuan: ${item.satuan}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeText.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeText),
                      const SizedBox(width: 5),
                      Text(badgeLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeText)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Comparison Metrics Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('Selisih Fisik (Aktual)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          item.pemakaianFisik != null
                              ? '${formatAngka(item.pemakaianFisik!)} ${item.satuan}'
                              : '-',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Text('vs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Teoritis BOM POS',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatAngka(item.pemakaianBom)} ${item.satuan}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B4332)),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Varian Audit',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          item.varians != null
                              ? '${item.varians! > 0 ? '+' : ''}${formatAngka(item.varians!)} ${item.satuan}'
                              : '-',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: item.varians == null
                                ? Colors.grey
                                : (item.varians == 0
                                    ? Colors.green.shade700
                                    : (item.varians! < 0 ? Colors.red.shade700 : Colors.blue.shade700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expandable menu breakdown
            if (item.detailMenu.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expanded
                            ? 'Sembunyikan Rincian Penjualan'
                            : 'Lihat Rincian BOM Penjualan (${item.detailMenu.length} menu)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Menu POS',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Terjual',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Takaran',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Subtotal BOM',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...item.detailMenu.map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(m.namaMenu,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('${m.qtyTerjual}x',
                                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('${formatAngka(m.takaran)} ${item.satuan}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('${formatAngka(m.subtotalBom)} ${item.satuan}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B4332))),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

