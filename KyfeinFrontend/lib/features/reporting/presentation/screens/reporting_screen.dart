import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/page_refresh_scope.dart';
import '../../../stok/presentation/widgets/rekap_barang_masuk_section.dart';
import '../../providers/reporting_provider.dart';

class ReportingScreen extends StatefulWidget {
  final int initialSection;

  const ReportingScreen({super.key, this.initialSection = 0});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  late int _currentSection;

  // Filter state for Period Reports (Sections 0, 1, 2)
  String _selectedFilter = 'harian'; // harian | range | bulanan | tahunan
  DateTime _selectedDate = DateTime.now();
  DateTime _rangeStart = DateTime.now().subtract(const Duration(days: 6));
  DateTime _rangeEnd = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Form state for Section 3 (Input Pengeluaran)
  String _formTipe = 'mendadak';
  String? _formKategoriId;
  DateTime _formTanggal = DateTime.now();
  final TextEditingController _namaMendadakCtrl = TextEditingController();
  final TextEditingController _nominalCtrl = TextEditingController();
  final TextEditingController _ketCtrl = TextEditingController();
  String _filterPengeluaranTipe = ''; // '' | 'bulanan' | 'mendadak' | 'belanja_bahan'
  bool _breakdownIncludeBahan = true;

  // Form state for Section 4 (Kategori Pengeluaran)
  final TextEditingController _namaKategoriCtrl = TextEditingController();

  // State for Section 2 (Laporan Absensi Per Karyawan)
  String _absensiDivisiFilter = 'semua'; // semua | kasir | bar | kitchen
  String _absensiSortBy = 'masalah'; // masalah | telat_menit | alpha | nama
  String _absensiSearchQuery = '';
  final Set<String> _expandedAbsensiIds = {};

  // State for Section 5 (HPP & Margin Menu)
  String _hppAreaFilter = 'semua'; // semua | bar | kitchen
  String _hppSearchQuery = '';
  String _hppSortBy = 'kode'; // kode | margin_asc | margin_desc | hpp_desc | harga_desc
  bool _hppShowBahanMonitor = false;
  final Set<String> _expandedHppMenuIds = {};

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _unitPriceFormat = NumberFormat('#,##0.##', 'id_ID');
  final _qtyFormat = NumberFormat('#,##0.###', 'id_ID');

  static const int _sectionCount = 6;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection.clamp(0, _sectionCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void didUpdateWidget(covariant ReportingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _currentSection = widget.initialSection.clamp(0, _sectionCount - 1);
      });
    }
  }

  @override
  void dispose() {
    _namaMendadakCtrl.dispose();
    _nominalCtrl.dispose();
    _ketCtrl.dispose();
    _namaKategoriCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtMonth(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _refreshAll() async {
    final prov = context.read<ReportingProvider>();
    await prov.loadAll(
      filter: _selectedFilter,
      tanggal: _selectedFilter == 'harian' ? _fmtDate(_selectedDate) : null,
      tanggalMulai: _selectedFilter == 'range' ? _fmtDate(_rangeStart) : null,
      tanggalSelesai: _selectedFilter == 'range' ? _fmtDate(_rangeEnd) : null,
      bulan: _selectedFilter == 'bulanan'
          ? _fmtMonth(_selectedYear, _selectedMonth)
          : null,
      tahun: _selectedFilter == 'tahunan' ? _selectedYear : null,
    );
    if (mounted && _formKategoriId == null && prov.activeKategoriList.isNotEmpty) {
      setState(() {
        _formKategoriId = prov.activeKategoriList.first.id;
      });
    }
  }

  Future<void> _reloadProfitAndBreakdown() async {
    await context.read<ReportingProvider>().loadProfitAndBreakdown(
          filter: _selectedFilter,
          tanggal: _selectedFilter == 'harian' ? _fmtDate(_selectedDate) : null,
          tanggalMulai: _selectedFilter == 'range' ? _fmtDate(_rangeStart) : null,
          tanggalSelesai: _selectedFilter == 'range' ? _fmtDate(_rangeEnd) : null,
          bulan: _selectedFilter == 'bulanan'
              ? _fmtMonth(_selectedYear, _selectedMonth)
              : null,
          tahun: _selectedFilter == 'tahunan' ? _selectedYear : null,
        );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ReportingProvider>();

    return PageRefreshRegistrar(
      onRefresh: _refreshAll,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: buildStandaloneAppBar(
          context,
          title: 'Laporan & Biaya',
          onRefresh: _refreshAll,
        ),
        body: prov.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _refreshAll,
                child: _buildCurrentSectionContent(prov),
              ),
      ),
    );
  }

  Widget _buildCurrentSectionContent(ReportingProvider prov) {
    switch (_currentSection) {
      case 0:
        return _buildProfitAndSalesView(prov);
      case 1:
        return _buildStokReportView(prov);
      case 2:
        return _buildAbsensiReportView(prov);
      case 3:
        return _buildPengeluaranView(prov);
      case 4:
        return _buildKategoriView(prov);
      case 5:
        return _buildHppMarginView(prov);
      default:
        return _buildProfitAndSalesView(prov);
    }
  }

  Widget _wrapCenteredList({required List<Widget> children}) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 0: LABA RUGI, OMZET, HPP & TRANSAKSI PERIODE
  // ===========================================================================
  Widget _buildProfitAndSalesView(ReportingProvider prov) {
    final report = prov.profitReport;
    final breakdown = prov.breakdownReport;

    return _wrapCenteredList(
      children: [
        _buildFilterCard(),
        const SizedBox(height: 20),
        _buildNetProfitHeroCard(report),
        const SizedBox(height: 20),
        _buildCorporateFinancialStatementCard(report),
        const SizedBox(height: 20),
        _buildMetricGrid(report),
        if (report != null && report.menuTanpaResep.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildMenuTanpaResepBanner(report.menuTanpaResep),
        ],
        const SizedBox(height: 20),
        _buildTransaksiSummaryCard(report),
        const SizedBox(height: 20),
        _buildBreakdownSection(breakdown),
      ],
    );
  }

  // ===========================================================================
  // SECTION 1: LAPORAN STOK, OPNAME & BAHAN MENIPIS PERIODE
  // ===========================================================================
  Widget _buildStokReportView(ReportingProvider prov) {
    final report = prov.profitReport;
    final stokMenipis = prov.stokMenipisList;

    return _wrapCenteredList(
      children: [
        _buildFilterCard(),
        const SizedBox(height: 20),
        _buildStokSummaryCard(report),
        const SizedBox(height: 20),
        RekapBarangMasukSection(
          rekap: prov.barangMasukRekap,
          isLoading: prov.isLoading,
          onShowBulanIni: _selectedFilter == 'bulanan'
              ? null
              : () {
                  setState(() {
                    _selectedFilter = 'bulanan';
                    _selectedMonth = DateTime.now().month;
                    _selectedYear = DateTime.now().year;
                  });
                  _reloadProfitAndBreakdown();
                },
        ),
        const SizedBox(height: 20),
        _buildStokMenipisSection(stokMenipis),
      ],
    );
  }

  // ===========================================================================
  // SECTION 2: LAPORAN ABSENSI & KEDISIPLINAN PERIODE
  // ===========================================================================
  Widget _buildAbsensiReportView(ReportingProvider prov) {
    final report = prov.profitReport;

    return _wrapCenteredList(
      children: [
        _buildFilterCard(),
        const SizedBox(height: 16),
        _buildAbsensiSummaryCard(report),
        const SizedBox(height: 16),
        _buildAbsensiPerKaryawanSection(report),
      ],
    );
  }

  Widget _buildFilterCard() {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - 2 + i);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filter Periode Laporan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF1A1D1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFilterChip('harian', 'Harian', Icons.today_rounded),
              _buildFilterChip('range', 'Rentang Tanggal', Icons.date_range_rounded),
              _buildFilterChip('bulanan', 'Bulanan', Icons.calendar_month_rounded),
              _buildFilterChip('tahunan', 'Tahunan', Icons.event_note_rounded),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedFilter == 'harian')
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  await _reloadProfitAndBreakdown();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          if (_selectedFilter == 'range')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _rangeStart,
                        firstDate: DateTime(2023),
                        lastDate: _rangeEnd,
                      );
                      if (picked != null) {
                        setState(() => _rangeStart = picked);
                        await _reloadProfitAndBreakdown();
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'Mulai: ${_fmtDate(_rangeStart)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _rangeEnd,
                        firstDate: _rangeStart,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _rangeEnd = picked);
                        await _reloadProfitAndBreakdown();
                      }
                    },
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                      'Selesai: ${_fmtDate(_rangeEnd)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          if (_selectedFilter == 'bulanan')
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bulan'),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(months[i], overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() => _selectedMonth = val);
                        await _reloadProfitAndBreakdown();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tahun'),
                    items: years
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() => _selectedYear = val);
                        await _reloadProfitAndBreakdown();
                      }
                    },
                  ),
                ),
              ],
            ),
          if (_selectedFilter == 'tahunan')
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Pilih Tahun'),
              items: years
                  .map(
                    (y) => DropdownMenuItem(
                      value: y,
                      child: Text('Tahun $y', overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  await _reloadProfitAndBreakdown();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final selected = _selectedFilter == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: const Color(0xFFFAFBF9),
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF2D312E),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      onSelected: (val) async {
        if (val && _selectedFilter != value) {
          setState(() => _selectedFilter = value);
          await _reloadProfitAndBreakdown();
        }
      },
    );
  }

  Widget _buildNetProfitHeroCard(ProfitReportModel? report) {
    final netProfit = report?.netProfit ?? 0.0;
    final isPositive = netProfit >= 0;
    final periodeText = report == null
        ? '-'
        : (report.periodeMulai == report.periodeSelesai
            ? report.periodeMulai
            : '${report.periodeMulai} s/d ${report.periodeSelesai}');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [AppTheme.primaryColor, const Color(0xFF2D6A4F)]
              : [const Color(0xFF7F1D1D), const Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Periode: $periodeText',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${report?.jumlahTransaksi ?? 0} Transaksi Selesai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'NET PROFIT USAHA (LABA RUGI AKRUAL)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currencyFormat.format(netProfit),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pendapatan − HPP Bahan Terpakai − Biaya Bulanan Pro-Rata − Biaya Mendadak',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _heroMiniStat(
                  'Pendapatan (Omzet)',
                  _currencyFormat.format(report?.totalPenjualan ?? 0),
                ),
                _heroMiniStat(
                  'Pengeluaran Kas (Bahan + Ops)',
                  _currencyFormat.format(report?.totalPengeluaranKas ?? 0),
                ),
                _heroMiniStat(
                  'Arus Kas Bersih',
                  _currencyFormat.format(report?.arusKasBersih ?? 0),
                ),
                _heroMiniStat(
                  'Nilai Aset Stok Tersisa',
                  _currencyFormat.format(report?.nilaiAsetStokSaatIni ?? 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCorporateFinancialStatementCard(ProfitReportModel? report) {
    final omzet = report?.totalPenjualan ?? 0.0;
    final hpp = report?.totalHppTeoritis ?? 0.0;
    final labaKotor = report?.labaKotor ?? (omzet - hpp);
    final grossMargin = report?.grossMarginPersen ??
        (omzet > 0 ? (labaKotor / omzet) * 100.0 : 0.0);
    final opBulanan = report?.pengeluaranBulananProRata ?? 0.0;
    final opMendadak = report?.pengeluaranMendadak ?? 0.0;
    final totalOps = report?.totalOperasional ?? (opBulanan + opMendadak);
    final netProfit = report?.netProfit ?? (labaKotor - totalOps);
    final netMargin = report?.netMarginPersen ??
        (omzet > 0 ? (netProfit / omzet) * 100.0 : 0.0);

    final belanjaBahan = report?.totalBelanjaBarangMasuk ?? 0.0;
    final totalKasKeluar = report?.totalPengeluaranKas ?? (totalOps + belanjaBahan);
    final arusKas = report?.arusKasBersih ?? (omzet - totalKasKeluar);

    final stokGudangVal = report?.nilaiAsetStokGudang ?? 0.0;
    final stokTitikVal = report?.nilaiAsetStokTitik ?? 0.0;
    final stokTotalVal = report?.nilaiAsetStokSaatIni ?? (stokGudangVal + stokTitikVal);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Laporan Keuangan Cafe (Standar Laba Rugi, Arus Kas & Aset)',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Memisahkan biaya pemakaian harian (Laba Rugi) dari belanja stok multi-bulan (Arus Kas & Aset Persediaan) agar tidak terjadi pencatatan ganda.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
          ),
          const Divider(height: 26),

          // A. LABA RUGI USAHA
          _statementSectionHeader('A. Laporan Laba Rugi (Basis Pemakaian / Akrual)'),
          const SizedBox(height: 8),
          _statementRow('Pendapatan Penjualan (Omzet)', omzet, positivePrefix: true),
          _statementRow('(−) HPP Bahan Terpakai (Resep Terjual)', -hpp, isDeduction: true),
          _statementSubtotalRow(
            '(=) Laba Kotor (Gross Profit · Margin ${grossMargin.toStringAsFixed(1)}%)',
            labaKotor,
            highlightColor: labaKotor >= 0 ? Colors.green.shade800 : Colors.red.shade800,
          ),
          _statementRow('(−) Biaya Operasional Bulanan (Pro-Rata)', -opBulanan, isDeduction: true),
          _statementRow('(−) Biaya Operasional Mendadak', -opMendadak, isDeduction: true),
          _statementTotalRow(
            '(=) Laba Bersih Usaha (Margin ${netMargin.toStringAsFixed(1)}%)',
            netProfit,
            isPositive: netProfit >= 0,
          ),
          const Divider(height: 28),

          // B. ARUS KAS RIIL (TERMASUK MODAL BELANJA BAHAN)
          _statementSectionHeader('B. Laporan Arus Kas Riil (Pendapatan vs Seluruh Pengeluaran)'),
          const SizedBox(height: 8),
          _statementRow('Kas Masuk dari Penjualan', omzet, positivePrefix: true),
          _statementRow('(−) Belanja Stok Bahan Gudang (Barang Masuk)', -belanjaBahan, isDeduction: true),
          _statementRow('(−) Beban Operasional Periode', -totalOps, isDeduction: true),
          _statementSubtotalRow(
            '(−) Total Seluruh Pengeluaran Kas',
            -totalKasKeluar,
            highlightColor: Colors.red.shade800,
          ),
          _statementTotalRow(
            arusKas >= 0
                ? '(=) Arus Kas Bersih (Surplus Kas)'
                : '(=) Arus Kas Bersih (Belum Balik Modal)',
            arusKas,
            isPositive: arusKas >= 0,
          ),
          const Divider(height: 28),

          // C. VALUASI ASET PERSEDIAAN MULTI-BULAN
          _statementSectionHeader('C. Nilai Aset Persediaan Stok Saat Ini (Stok Multi-Bulan)'),
          const SizedBox(height: 8),
          _statementRow('Nilai Persediaan Gudang Utama', stokGudangVal),
          _statementRow('Nilai Persediaan Titik Bar & Kitchen', stokTitikVal),
          _statementSubtotalRow(
            '(=) Total Nilai Aset Stok Tersisa',
            stokTotalVal,
            highlightColor: AppTheme.primaryColor,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF3EF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC7DEC9)),
            ),
            child: Text(
              'Penjelasan Akuntansi Multi-Bulan: Modal pembelian bahan masuk dicatat pada Arus Kas Keluar dan langsung membentuk Aset Persediaan Stok sebesar ${_currencyFormat.format(stokTotalVal)}. Saat stok dipakai berjualan selama beberapa bulan ke depan, nilainya berpindah bertahap ke HPP di Laba Rugi.',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF1B4332),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _statementRow(
    String label,
    double amount, {
    bool isDeduction = false,
    bool positivePrefix = false,
  }) {
    final absAmt = amount.abs();
    final formatted = _currencyFormat.format(absAmt);
    final textVal = isDeduction
        ? (absAmt > 0 ? '- $formatted' : formatted)
        : (positivePrefix && amount > 0 ? '+ $formatted' : _currencyFormat.format(amount));
    final color = isDeduction && absAmt > 0
        ? Colors.red.shade700
        : (positivePrefix && amount > 0
            ? Colors.green.shade700
            : AppTheme.textColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            textVal,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementSubtotalRow(
    String label,
    double amount, {
    required Color highlightColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount < 0
                ? '- ${_currencyFormat.format(amount.abs())}'
                : _currencyFormat.format(amount),
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementTotalRow(
    String label,
    double amount, {
    required bool isPositive,
  }) {
    final bg = isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final border = isPositive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);
    final fg = isPositive ? const Color(0xFF065F46) : const Color(0xFF991B1B);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(ProfitReportModel? report) {
    final items = [
      _MetricCardData(
        title: 'Total Penjualan (Omzet)',
        value: _currencyFormat.format(report?.totalPenjualan ?? 0),
        subtitle: 'Transaksi berstatus selesai',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF15803D),
      ),
      _MetricCardData(
        title: 'Laba Kotor (Omzet − HPP)',
        value: _currencyFormat.format(report?.labaKotor ?? 0),
        subtitle: 'HPP terpakai: ${_currencyFormat.format(report?.totalHppTeoritis ?? 0)}',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFB45309),
      ),
      _MetricCardData(
        title: 'Beban Operasional',
        value: _currencyFormat.format(report?.totalOperasional ?? 0),
        subtitle:
            'Bulanan ${_currencyFormat.format(report?.pengeluaranBulananProRata ?? 0)} · Mendadak ${_currencyFormat.format(report?.pengeluaranMendadak ?? 0)}',
        icon: Icons.calendar_view_month_rounded,
        color: const Color(0xFF1D4ED8),
      ),
      _MetricCardData(
        title: 'Belanja Stok Bahan',
        value: _currencyFormat.format(report?.totalBelanjaBarangMasuk ?? 0),
        subtitle: '${report?.jumlahBarangMasuk ?? 0} nota barang masuk gudang',
        icon: Icons.shopping_cart_checkout_rounded,
        color: const Color(0xFF0F766E),
      ),
      _MetricCardData(
        title: 'Total Pengeluaran Kas',
        value: _currencyFormat.format(report?.totalPengeluaranKas ?? 0),
        subtitle: 'Gabungan Belanja Bahan + Ops',
        icon: Icons.payments_outlined,
        color: const Color(0xFFB91C1C),
      ),
      _MetricCardData(
        title: 'Nilai Aset Stok Tersisa',
        value: _currencyFormat.format(report?.nilaiAsetStokSaatIni ?? 0),
        subtitle: 'Stok gudang + bar & kitchen',
        icon: Icons.warehouse_rounded,
        color: AppTheme.primaryColor,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 132,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, idx) {
        final item = items[idx];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 18, color: item.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D312E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                item.value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.subtitle,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuTanpaResepBanner(List<String> menus) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perhatian: Menu Terjual Tanpa Resep (HPP = Rp 0)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Menu berikut terjual pada periode ini namun belum memiliki resep BOM: ${menus.join(", ")}. Silakan lengkapi resep di Master Data.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaksiSummaryCard(ProfitReportModel? report) {
    final selesai = report?.jumlahTransaksi ?? 0;
    final batal = report?.jumlahTransaksiDibatalkan ?? 0;
    final cash = report?.totalCash ?? 0.0;
    final qris = report?.totalQris ?? 0.0;
    final totalBayar = cash + qris;
    final cashPct = totalBayar > 0 ? (cash / totalBayar) * 100 : 0.0;
    final qrisPct = totalBayar > 0 ? (qris / totalBayar) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIconBadge(Icons.receipt_long_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transaksi & Pembayaran',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: const Color(0xFF111815),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$selesai Nota',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAEEEB)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _cleanMetricCell(
                        label: 'Tunai (Cash)',
                        value: _currencyFormat.format(cash),
                        subLabel: totalBayar > 0
                            ? '${cashPct.toStringAsFixed(0)}% dari total'
                            : 'Pembayaran tunai',
                        dotColor: const Color(0xFF0F766E),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: const Color(0xFFE3E9E5),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: _cleanMetricCell(
                        label: 'QRIS Statis',
                        value: _currencyFormat.format(qris),
                        subLabel: totalBayar > 0
                            ? '${qrisPct.toStringAsFixed(0)}% dari total'
                            : 'Pembayaran QRIS',
                        dotColor: const Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
                if (totalBayar > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          if (cash > 0)
                            Expanded(
                              flex: (cashPct * 10).round().clamp(1, 1000),
                              child: Container(color: const Color(0xFF0F766E)),
                            ),
                          if (qris > 0)
                            Expanded(
                              flex: (qrisPct * 10).round().clamp(1, 1000),
                              child: Container(color: const Color(0xFF4338CA)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _inlineKeyValue(
                  dotColor: const Color(0xFF15803D),
                  label: 'Selesai',
                  value: '$selesai Nota',
                  valueColor: const Color(0xFF15803D),
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: const Color(0xFFE6ECE8),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                child: _inlineKeyValue(
                  dotColor: batal > 0 ? Colors.red.shade700 : Colors.grey.shade400,
                  label: 'Void / Batal',
                  value: '$batal Nota',
                  valueColor: batal > 0 ? Colors.red.shade700 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStokSummaryCard(ProfitReportModel? report) {
    final jmlMasuk = report?.jumlahBarangMasuk ?? 0;
    final totalBelanja = report?.totalBelanjaBarangMasuk ?? 0.0;
    final jmlKeluar = report?.jumlahBarangKeluar ?? 0;
    final jmlOpname = report?.jumlahSesiOpname ?? 0;
    final jmlMenipis = report?.jumlahStokMenipis ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIconBadge(Icons.warehouse_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pergerakan Stok & Opname',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: const Color(0xFF111815),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: jmlMenipis > 0 ? Colors.red.shade50 : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: jmlMenipis > 0 ? Colors.red.shade200 : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  jmlMenipis > 0 ? '$jmlMenipis Menipis' : 'Stok Aman',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: jmlMenipis > 0 ? Colors.red.shade700 : const Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAEEEB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Belanja Barang Masuk',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(totalBelanja),
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    '$jmlMasuk Nota Masuk',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _cleanMetricCell(
                  label: 'Transfer Keluar',
                  value: '$jmlKeluar',
                  subLabel: 'Ke Bar/Kitchen',
                  dotColor: const Color(0xFFD97706),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: const Color(0xFFE6ECE8),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                child: _cleanMetricCell(
                  label: 'Sesi Opname',
                  value: '$jmlOpname',
                  subLabel: 'Sesi tercatat',
                  dotColor: AppTheme.primaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: const Color(0xFFE6ECE8),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                child: _cleanMetricCell(
                  label: 'Stok Menipis',
                  value: '$jmlMenipis',
                  subLabel: 'Di bawah min',
                  dotColor: jmlMenipis > 0 ? Colors.red.shade600 : Colors.grey.shade400,
                  valueColor: jmlMenipis > 0 ? Colors.red.shade700 : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbsensiSummaryCard(ProfitReportModel? report) {
    final totalShift = report?.totalShiftTerjadwal ?? 0;
    final totalHadir = report?.totalHadir ?? 0;
    final totalTepat = report?.totalTepatWaktu ?? 0;
    final totalTelat = report?.totalTerlambat ?? 0;
    final totalMenitTelat = report?.totalMenitTelat ?? 0;
    final totalAlpha = report?.totalTanpaKeterangan ?? 0;
    final totalIzinTelat = report?.totalIzinTelat ?? 0;
    final totalIzinTdkMasuk = report?.totalIzinTidakMasuk ?? 0;
    final totalLupaPulang = report?.totalLupaAbsenPulang ?? 0;
    final ketepatan = report?.tingkatKetepatanPersen ?? 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIconBadge(Icons.fingerprint_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ringkasan Kedisiplinan Tim',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: const Color(0xFF111815),
                  ),
                ),
              ),
              if (totalHadir > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ketepatan >= 85
                        ? const Color(0xFFECFDF5)
                        : (ketepatan >= 70 ? Colors.amber.shade50 : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ketepatan >= 85
                          ? const Color(0xFFA7F3D0)
                          : (ketepatan >= 70 ? Colors.amber.shade300 : Colors.red.shade200),
                    ),
                  ),
                  child: Text(
                    'Tepat ${ketepatan.toStringAsFixed(ketepatan % 1 == 0 ? 0 : 1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ketepatan >= 85
                          ? const Color(0xFF065F46)
                          : (ketepatan >= 70 ? Colors.amber.shade900 : Colors.red.shade800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary 2-column hero strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAEEEB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _cleanMetricCell(
                    label: 'Kehadiran Masuk',
                    value: totalShift > 0 ? '$totalHadir / $totalShift' : '$totalHadir Shift',
                    subLabel: '$totalTepat shift tepat waktu',
                    dotColor: AppTheme.primaryColor,
                    valueColor: AppTheme.primaryColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFE3E9E5),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _cleanMetricCell(
                    label: 'Keterlambatan',
                    value: '$totalTelat× · $totalMenitTelat mnt',
                    subLabel: totalTelat > 0 ? 'Akumulasi telat tim' : 'Tidak ada telat',
                    dotColor: totalTelat > 0 ? Colors.red.shade600 : Colors.grey.shade400,
                    valueColor: totalTelat > 0 ? Colors.red.shade700 : const Color(0xFF111815),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Secondary 2x2 minimalist hairline grid
          _buildMinimalMetricMatrix([
            _CompactMetric(
              label: 'Tidak Hadir (Alpha)',
              value: '$totalAlpha kali',
              dotColor: totalAlpha > 0 ? Colors.red.shade700 : Colors.grey.shade400,
              valueColor: totalAlpha > 0 ? Colors.red.shade700 : null,
            ),
            _CompactMetric(
              label: 'Izin Tidak Masuk',
              value: '$totalIzinTdkMasuk kali',
              dotColor: totalIzinTdkMasuk > 0 ? Colors.purple.shade600 : Colors.grey.shade400,
              valueColor: totalIzinTdkMasuk > 0 ? Colors.purple.shade700 : null,
            ),
            _CompactMetric(
              label: 'Izin Terlambat',
              value: '$totalIzinTelat kali',
              dotColor: totalIzinTelat > 0 ? Colors.amber.shade800 : Colors.grey.shade400,
              valueColor: totalIzinTelat > 0 ? Colors.amber.shade900 : null,
            ),
            _CompactMetric(
              label: 'Lupa Absen Pulang',
              value: '$totalLupaPulang kali',
              dotColor: totalLupaPulang > 0 ? Colors.deepOrange.shade600 : Colors.grey.shade400,
              valueColor: totalLupaPulang > 0 ? Colors.deepOrange.shade700 : null,
            ),
          ]),

          if (_selectedFilter == 'harian' && totalShift == 0 && totalHadir == 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Belum ada shift tercatat pada tanggal ini.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      setState(() {
                        _selectedFilter = 'bulanan';
                        _selectedMonth = DateTime.now().month;
                        _selectedYear = DateTime.now().year;
                      });
                      await _reloadProfitAndBreakdown();
                    },
                    child: const Text(
                      'Bulan Ini →',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbsensiPerKaryawanSection(ProfitReportModel? report) {
    final allStaff = report?.absensiPerKaryawan ?? const <AbsensiKaryawanItemModel>[];
    final q = _absensiSearchQuery.trim().toLowerCase();

    final filtered = allStaff.where((e) {
      final matchDiv = _absensiDivisiFilter == 'semua' ||
          e.divisi.toLowerCase() == _absensiDivisiFilter;
      final matchQuery = q.isEmpty ||
          e.nama.toLowerCase().contains(q) ||
          e.divisi.toLowerCase().contains(q);
      return matchDiv && matchQuery;
    }).toList();

    if (_absensiSortBy == 'telat_menit') {
      filtered.sort((a, b) {
        final c = b.totalMenitTelat.compareTo(a.totalMenitTelat);
        if (c != 0) return c;
        return b.telatCount.compareTo(a.telatCount);
      });
    } else if (_absensiSortBy == 'alpha') {
      filtered.sort((a, b) {
        final c = b.tanpaKeteranganCount.compareTo(a.tanpaKeteranganCount);
        if (c != 0) return c;
        return b.izinTidakMasukCount.compareTo(a.izinTidakMasukCount);
      });
    } else if (_absensiSortBy == 'nama') {
      filtered.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rekap Kehadiran Per Karyawan',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${filtered.length} Karyawan',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _absensiSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan atau divisi...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _absensiDivChip('semua', 'Semua'),
                const SizedBox(width: 6),
                _absensiDivChip('kasir', 'Kasir'),
                const SizedBox(width: 6),
                _absensiDivChip('bar', 'Bar'),
                const SizedBox(width: 6),
                _absensiDivChip('kitchen', 'Kitchen'),
                const SizedBox(width: 12),
                _absensiSortChip('masalah', 'Prioritas'),
                const SizedBox(width: 6),
                _absensiSortChip('telat_menit', 'Menit Telat'),
                const SizedBox(width: 6),
                _absensiSortChip('alpha', 'Tidak Hadir'),
                const SizedBox(width: 6),
                _absensiSortChip('nama', 'Nama A-Z'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                allStaff.isEmpty
                    ? 'Belum ada data karyawan aktif pada laporan ini.'
                    : 'Tidak ada karyawan yang cocok dengan filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            ...filtered.map(_buildAbsensiKaryawanCard),
        ],
      ),
    );
  }

  Widget _absensiDivChip(String value, String label) {
    final selected = _absensiDivisiFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _absensiDivisiFilter = value),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppTheme.primaryColor : const Color(0xFF2D312E),
      ),
    );
  }

  Widget _absensiSortChip(String value, String label) {
    final selected = _absensiSortBy == value;
    return ChoiceChip(
      avatar: Icon(
        Icons.sort_rounded,
        size: 14,
        color: selected ? Colors.white : Colors.grey.shade700,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _absensiSortBy = value),
      backgroundColor: const Color(0xFFF6F8F6),
      selectedColor: AppTheme.primaryColor,
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF2D312E),
      ),
    );
  }

  Widget _buildAbsensiKaryawanCard(AbsensiKaryawanItemModel emp) {
    final isExpanded = _expandedAbsensiIds.contains(emp.karyawanId);

    Color badgeBg;
    Color badgeFg;
    String badgeLabel;
    switch (emp.kategoriPerilaku) {
      case 'perlu_perhatian':
        badgeBg = Colors.red.shade50;
        badgeFg = Colors.red.shade800;
        badgeLabel = 'Perlu Perhatian';
        break;
      case 'waspada':
        badgeBg = Colors.amber.shade50;
        badgeFg = Colors.amber.shade900;
        badgeLabel = 'Waspada';
        break;
      case 'disiplin':
        badgeBg = Colors.green.shade50;
        badgeFg = Colors.green.shade800;
        badgeLabel = 'Disiplin';
        break;
      default:
        badgeBg = Colors.grey.shade100;
        badgeFg = Colors.grey.shade700;
        badgeLabel = 'Belum Ada Data';
    }

    final divLabel = emp.divisi.toUpperCase();
    final rataStr = emp.rataMenitTelat % 1 == 0
        ? emp.rataMenitTelat.toInt().toString()
        : emp.rataMenitTelat.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emp.kategoriPerilaku == 'perlu_perhatian'
              ? Colors.red.shade200
              : (emp.kategoriPerilaku == 'waspada'
                  ? Colors.amber.shade300
                  : AppTheme.borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Nama + Divisi + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  emp.nama.isNotEmpty ? emp.nama[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          emp.nama,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: const Color(0xFF1A1D1B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Text(
                            divLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (emp.ringkasanPerilaku.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        emp.ringkasanPerilaku,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metric Grid: 2 baris x 3 kolom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _empMetricCell(
                      'Hadir / Shift',
                      '${emp.totalHadir}/${emp.totalShiftTerjadwal}',
                      AppTheme.primaryColor,
                    ),
                    _empMetricDivider(),
                    _empMetricCell(
                      'Tepat Waktu',
                      emp.totalHadir > 0
                          ? '${emp.tepatWaktuCount}× (${emp.tingkatKetepatanPersen.toStringAsFixed(0)}%)'
                          : '0×',
                      Colors.green.shade700,
                    ),
                    _empMetricDivider(),
                    _empMetricCell(
                      'Total Telat',
                      emp.telatCount > 0
                          ? '${emp.totalMenitTelat} mnt (${emp.telatCount}×)'
                          : '0 mnt',
                      emp.telatCount > 0
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                    ),
                  ],
                ),
                Divider(height: 16, color: Colors.grey.shade200),
                Row(
                  children: [
                    _empMetricCell(
                      'Alpha / Tdk Hadir',
                      '${emp.tanpaKeteranganCount} kali',
                      emp.tanpaKeteranganCount > 0
                          ? Colors.red.shade800
                          : Colors.grey.shade700,
                    ),
                    _empMetricDivider(),
                    _empMetricCell(
                      'Izin Tdk Masuk',
                      '${emp.izinTidakMasukCount} kali',
                      emp.izinTidakMasukCount > 0
                          ? Colors.purple.shade700
                          : Colors.grey.shade700,
                    ),
                    _empMetricDivider(),
                    _empMetricCell(
                      'Lupa Pulang',
                      '${emp.lupaAbsenPulangCount} kali',
                      emp.lupaAbsenPulangCount > 0
                          ? Colors.deepOrange.shade700
                          : Colors.grey.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Extra chips: rata-rata menit telat, izin telat, tukar shift
          if (emp.telatCount > 0 ||
              emp.izinTelatCount > 0 ||
              emp.tukarShiftCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (emp.telatCount > 0)
                  _tinyInfoTag(
                    'Rata-rata telat: $rataStr mnt/kejadian',
                    Colors.red.shade50,
                    Colors.red.shade800,
                  ),
                if (emp.izinTelatCount > 0)
                  _tinyInfoTag(
                    'Izin Telat: ${emp.izinTelatCount}×',
                    Colors.amber.shade50,
                    Colors.amber.shade900,
                  ),
                if (emp.tukarShiftCount > 0)
                  _tinyInfoTag(
                    'Tukar Shift: ${emp.tukarShiftCount}×',
                    Colors.blue.shade50,
                    Colors.blue.shade800,
                  ),
              ],
            ),
          ],

          // Expandable per-date shift log
          if (emp.riwayatShift.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedAbsensiIds.remove(emp.karyawanId);
                } else {
                  _expandedAbsensiIds.add(emp.karyawanId);
                }
              }),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppTheme.primaryColor.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isExpanded
                        ? AppTheme.primaryColor.withValues(alpha: 0.25)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 15, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rincian Log Shift (${emp.riwayatShift.length} Shift)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < emp.riwayatShift.length; i++) ...[
                      if (i > 0) Divider(height: 12, color: Colors.grey.shade200),
                      _buildAbsensiLogRow(emp.riwayatShift[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _empMetricCell(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empMetricDivider() => Container(
        width: 1,
        height: 26,
        color: Colors.grey.shade200,
        margin: const EdgeInsets.symmetric(horizontal: 6),
      );

  Widget _tinyInfoTag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );

  Widget _buildAbsensiLogRow(AbsensiLogItemModel log) {
    String fmtJam(String? iso) {
      if (iso == null || iso.isEmpty) return '-';
      final dt = DateTime.tryParse(iso);
      return dt != null ? DateFormat('HH:mm').format(dt) : '-';
    }

    Color stBg;
    Color stFg;
    String stLabel;
    switch (log.statusKehadiran) {
      case 'tepat_waktu':
        stBg = Colors.green.shade50;
        stFg = Colors.green.shade800;
        stLabel = 'Tepat Waktu';
        break;
      case 'terlambat':
        stBg = Colors.red.shade50;
        stFg = Colors.red.shade800;
        stLabel = 'Telat +${log.menitTelat} mnt';
        break;
      case 'izin_tidak_masuk':
        stBg = Colors.purple.shade50;
        stFg = Colors.purple.shade800;
        stLabel = 'Izin';
        break;
      case 'alpha':
        stBg = Colors.red.shade100;
        stFg = Colors.red.shade900;
        stLabel = 'Alpha';
        break;
      default:
        stBg = Colors.grey.shade100;
        stFg = Colors.grey.shade700;
        stLabel = 'Terjadwal';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${log.tanggal} · ${log.shift.replaceAll('_', ' ').toUpperCase()} (${log.jamMulai}–${log.jamSelesai})',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D1B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                log.jamMasuk != null
                    ? 'Masuk ${fmtJam(log.jamMasuk)} · Pulang ${fmtJam(log.jamPulang)}'
                    : 'Tidak ada catatan check-in',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (log.keterangan != null && log.keterangan!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  log.keterangan!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: stBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            stLabel,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: stFg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection(ExpenseBreakdownReportModel? breakdown) {
    final bool hasBahan = (breakdown?.totalBelanjaBahan ?? 0.0) > 0 ||
        (breakdown?.itemsDenganBahan.isNotEmpty ?? false);
    final bool pakaiGabungan = _breakdownIncludeBahan && hasBahan;
    final items = pakaiGabungan
        ? (breakdown?.itemsDenganBahan ?? const <ExpenseBreakdownItemModel>[])
        : (breakdown?.items ?? const <ExpenseBreakdownItemModel>[]);
    final total = pakaiGabungan
        ? (breakdown?.totalSemuaPengeluaran ?? 0.0)
        : (breakdown?.totalPengeluaran ?? 0.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIconBadge(Icons.pie_chart_outline_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proporsi Pengeluaran',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: const Color(0xFF111815),
                      ),
                    ),
                    Text(
                      pakaiGabungan
                          ? 'Operasional & belanja bahan'
                          : 'Khusus beban operasional',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currencyFormat.format(total),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Modern full-width 2-segment control
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segmentTabButton(
                    label: 'Semua (Bahan + Ops)',
                    selected: _breakdownIncludeBahan,
                    onTap: () => setState(() => _breakdownIncludeBahan = true),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _segmentTabButton(
                    label: 'Operasional Saja',
                    selected: !_breakdownIncludeBahan,
                    onTap: () => setState(() => _breakdownIncludeBahan = false),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 22),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Belum ada pengeluaran tercatat pada periode ini.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ...items.map((item) {
              final pct = (item.persentase.clamp(0.0, 100.0)) / 100.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.namaKategori,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currencyFormat.format(item.totalNominal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF111815),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6F3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.persentase.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF1F5F2),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sectionIconBadge(IconData icon) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 17, color: AppTheme.primaryColor),
      );

  Widget _segmentTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primaryColor : const Color(0xFF64746B),
          ),
        ),
      ),
    );
  }

  Widget _cleanMetricCell({
    required String label,
    required String value,
    String? subLabel,
    Color? dotColor,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF111815),
          ),
        ),
        if (subLabel != null && subLabel.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }

  Widget _inlineKeyValue({
    required Color dotColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalMetricMatrix(List<_CompactMetric> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 4 : 2;
        final rows = <Widget>[];
        for (int i = 0; i < items.length; i += cols) {
          final slice = items.sublist(i, (i + cols).clamp(0, items.length));
          if (rows.isNotEmpty) {
            rows.add(const Divider(height: 20, color: Color(0xFFEDF2EE)));
          }
          rows.add(
            Row(
              children: [
                for (int j = 0; j < cols; j++) ...[
                  if (j > 0)
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFEDF2EE),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  Expanded(
                    child: j < slice.length
                        ? _cleanMetricCell(
                            label: slice[j].label,
                            value: slice[j].value,
                            dotColor: slice[j].dotColor,
                            valueColor: slice[j].valueColor,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildStokMenipisSection(List<StokMenipisItemModel> list) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: list.isEmpty ? Colors.green : Colors.orange.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daftar Bahan Baku di Bawah Stok Minimum (${list.length})',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Seluruh stok bahan baku berada pada batas aman.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...list.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.red.shade50,
                        child: Icon(Icons.warning_rounded, size: 18, color: Colors.red.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.nama,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.isiPerKemasan > 0
                                  ? 'Batas Minimum: ${b.batasStokMinimum.toStringAsFixed(0)} kemasan (${b.batasMinimumKecil.toStringAsFixed(0)} ${b.satuanDasar})'
                                  : 'Batas Minimum: ${b.batasStokMinimum.toStringAsFixed(0)} ${b.satuanDasar}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sisa: ${b.totalStok.toStringAsFixed(1)} ${b.satuanDasar}',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: INPUT & RIWAYAT PENGELUARAN
  // ===========================================================================
  static const List<String> _bulanNamaList = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  Widget _buildPengeluaranView(ReportingProvider prov) {
    final activeKategoris = prov.activeKategoriList;
    final now = DateTime.now();
    final currentMonthKey = _fmtMonth(now.year, now.month);
    final currentMonthLabel = '${_bulanNamaList[now.month - 1]} ${now.year}';

    final usedKategoriIdsThisMonth = prov.pengeluaranList
        .where((e) =>
            e.tipe == 'bulanan' &&
            e.kategoriId != null &&
            e.kategoriId!.isNotEmpty &&
            (e.bulan ?? '').startsWith(currentMonthKey))
        .map((e) => e.kategoriId!)
        .toSet();

    final availableKategorisThisMonth = activeKategoris
        .where((k) => !usedKategoriIdsThisMonth.contains(k.id))
        .toList();

    final selectedBulananKategoriId = activeKategoris.isEmpty
        ? null
        : (activeKategoris.any((k) => k.id == _formKategoriId)
            ? _formKategoriId
            : (availableKategorisThisMonth.isNotEmpty
                ? availableKategorisThisMonth.first.id
                : activeKategoris.first.id));
    final isSelectedBulananAlreadyPaid = selectedBulananKategoriId != null &&
        usedKategoriIdsThisMonth.contains(selectedBulananKategoriId);

    final filteredList = _filterPengeluaranTipe.isEmpty
        ? prov.pengeluaranList
        : prov.pengeluaranList
            .where((e) => e.tipe == _filterPengeluaranTipe)
            .toList();

    final totalOpsBulanan = prov.pengeluaranList
        .where((e) => e.tipe == 'bulanan')
        .fold<double>(0.0, (acc, e) => acc + e.nominal);
    final totalOpsMendadak = prov.pengeluaranList
        .where((e) => e.tipe == 'mendadak')
        .fold<double>(0.0, (acc, e) => acc + e.nominal);
    final totalBelanjaBahan = prov.pengeluaranList
        .where((e) => e.tipe == 'belanja_bahan' || e.sumber == 'barang_masuk')
        .fold<double>(0.0, (acc, e) => acc + e.nominal);

    return _wrapCenteredList(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF3EF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7DEC9)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pembelian bahan baku via Stok Gudang → Barang Masuk otomatis tercatat di riwayat pengeluaran & arus kas di bawah ini tanpa terhitung ganda di HPP.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1B4332), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catat Pengeluaran Operasional Baru',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'Pengeluaran Bulanan otomatis untuk bulan ini (maks. 1x per kategori) dan dialokasikan pro-rata per hari, sedangkan Pengeluaran Mendadak dibebankan pada tanggal kejadian.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _formTipe,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipe Pengeluaran'),
                items: const [
                  DropdownMenuItem(
                    value: 'mendadak',
                    child: Text('Pengeluaran Mendadak (Insidental Harian)'),
                  ),
                  DropdownMenuItem(
                    value: 'bulanan',
                    child: Text('Pengeluaran Bulanan (Pro-Rata Bulanan)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _formTipe = val;
                      if (val == 'bulanan') {
                        if (availableKategorisThisMonth.isNotEmpty &&
                            (_formKategoriId == null ||
                                usedKategoriIdsThisMonth.contains(_formKategoriId))) {
                          _formKategoriId = availableKategorisThisMonth.first.id;
                        }
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_formTipe == 'mendadak')
                TextField(
                  controller: _namaMendadakCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama / Keperluan Pengeluaran',
                    hintText: 'Contoh: Beli galon air, es batu, servis kompor',
                  ),
                )
              else if (activeKategoris.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Belum ada Kategori Biaya aktif. Silakan tambah kategori terlebih dahulu.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _currentSection = 4),
                          child: const Text('Kelola Kategori'),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('kat_${selectedBulananKategoriId}_${usedKategoriIdsThisMonth.length}'),
                  initialValue: selectedBulananKategoriId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori Pengeluaran'),
                  items: activeKategoris.map((k) {
                    final alreadyPaid = usedKategoriIdsThisMonth.contains(k.id);
                    return DropdownMenuItem(
                      value: k.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              alreadyPaid ? '${k.nama} (Sudah dicatat bulan ini)' : k.nama,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: alreadyPaid ? Colors.grey.shade500 : null,
                              ),
                            ),
                          ),
                          if (alreadyPaid)
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: Colors.green.shade600),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _formKategoriId = val),
                ),
                if (isSelectedBulananAlreadyPaid) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kategori ini sudah dicatat untuk bulan $currentMonthLabel (maks. 1x per bulan). Pilih kategori lain atau gunakan tombol Edit pada riwayat untuk mengubah nominal.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              if (_formTipe == 'mendadak')
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _formTanggal,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _formTanggal = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Pengeluaran',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_fmtDate(_formTanggal)),
                  ),
                )
              else
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Periode Bulan (Otomatis Bulan Ini)',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    prefixIcon: const Icon(Icons.lock_rounded,
                        size: 18, color: AppTheme.primaryColor),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        currentMonthLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D1B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Maks. 1x / Kategori',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _nominalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixText: 'Rp ',
                  hintText: 'Contoh: 150000',
                ),
              ),
              if (_formTipe == 'bulanan')
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nominalCtrl,
                  builder: (_, val, __) {
                    final daysInMonth =
                        DateUtils.getDaysInMonth(now.year, now.month);
                    final raw = val.text.replaceAll('.', '').replaceAll(',', '').trim();
                    final nom = double.tryParse(raw) ?? 0;
                    final perDay = nom > 0 ? nom / daysInMonth : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        nom > 0
                            ? 'Alokasi harian di Laba Rugi: ${_currencyFormat.format(perDay)} / hari ($daysInMonth hari · $currentMonthLabel)'
                            : 'Nominal bulanan dibagi $daysInMonth hari secara otomatis ke Laba Rugi Harian ($currentMonthLabel).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _ketCtrl,
                decoration: InputDecoration(
                  labelText: 'Keterangan (Opsional)',
                  hintText: _formTipe == 'mendadak'
                      ? 'Catatan tambahan (opsional, misal: 2 galon Aqua)'
                      : 'Contoh: Tagihan listrik bulanan cafe',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_formTipe == 'bulanan' &&
                          (activeKategoris.isEmpty || isSelectedBulananAlreadyPaid))
                      ? null
                      : () => _handleSubmitPengeluaran(
                            prov,
                            activeKategoris,
                            resolvedBulananKategoriId: selectedBulananKategoriId,
                            usedKategoriIdsThisMonth: usedKategoriIdsThisMonth,
                          ),
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    (_formTipe == 'bulanan' && isSelectedBulananAlreadyPaid)
                        ? 'Kategori Sudah Dicatat Bulan Ini'
                        : 'Simpan Pengeluaran',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _sectionIconBadge(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Seluruh Pengeluaran',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                        Text(
                          _currencyFormat.format(
                              totalOpsBulanan + totalOpsMendadak + totalBelanjaBahan),
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 22, color: Color(0xFFEDF2EE)),
              _buildMinimalMetricMatrix([
                _CompactMetric(
                  label: 'Ops. Bulanan',
                  value: _currencyFormat.format(totalOpsBulanan),
                  dotColor: const Color(0xFF1D4ED8),
                ),
                _CompactMetric(
                  label: 'Ops. Mendadak',
                  value: _currencyFormat.format(totalOpsMendadak),
                  dotColor: const Color(0xFFB91C1C),
                ),
                _CompactMetric(
                  label: 'Belanja Bahan',
                  value: _currencyFormat.format(totalBelanjaBahan),
                  dotColor: const Color(0xFF0F766E),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Riwayat Pengeluaran Tercatat',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 230),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterPengeluaranTipe,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: '',
                        child: Text('Semua (Ops + Bahan)', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'mendadak',
                        child: Text('Mendadak', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'bulanan',
                        child: Text('Bulanan', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'belanja_bahan',
                        child: Text('Belanja Stok Bahan', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterPengeluaranTipe = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Center(
              child: Text(
                'Belum ada riwayat pengeluaran.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...filteredList.map((item) => _buildPengeluaranItemCard(prov, item)),
      ],
    );
  }

  String _pengeluaranTitle(PengeluaranModel item) {
    final namaMendadak = item.namaPengeluaran?.trim() ?? '';
    if (namaMendadak.isNotEmpty) return namaMendadak;
    return item.namaKategori;
  }

  Future<void> _handleSubmitPengeluaran(
    ReportingProvider prov,
    List<KategoriPengeluaranModel> activeKategoris, {
    String? resolvedBulananKategoriId,
    Set<String> usedKategoriIdsThisMonth = const {},
  }) async {
    final rawNominal = _nominalCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    final nominal = double.tryParse(rawNominal) ?? 0;
    if (nominal <= 0) {
      _showSnack('Nominal pengeluaran harus lebih dari 0', isError: true);
      return;
    }

    final now = DateTime.now();
    String? katId;
    String? namaMendadak;
    if (_formTipe == 'mendadak') {
      namaMendadak = _namaMendadakCtrl.text.trim();
      if (namaMendadak.isEmpty) {
        _showSnack('Nama / keperluan pengeluaran mendadak wajib diisi', isError: true);
        return;
      }
    } else {
      if (activeKategoris.isEmpty) {
        _showSnack('Pilih atau buat kategori pengeluaran bulanan terlebih dahulu', isError: true);
        return;
      }
      katId = resolvedBulananKategoriId ??
          (activeKategoris.any((k) => k.id == _formKategoriId)
              ? _formKategoriId!
              : activeKategoris.first.id);
      if (usedKategoriIdsThisMonth.contains(katId)) {
        _showSnack(
          'Pengeluaran bulanan kategori ini sudah dicatat di bulan ini (maks. 1x per bulan).',
          isError: true,
        );
        return;
      }
    }

    final res = await prov.createPengeluaran(
      tipe: _formTipe,
      kategoriId: katId,
      namaPengeluaran: namaMendadak,
      nominal: nominal,
      bulan: _formTipe == 'bulanan' ? _fmtMonth(now.year, now.month) : null,
      tanggal: _formTipe == 'mendadak' ? _fmtDate(_formTanggal) : null,
      keterangan: _ketCtrl.text,
    );

    _showSnack(res.message, isError: !res.success);
    if (res.success) {
      _namaMendadakCtrl.clear();
      _nominalCtrl.clear();
      _ketCtrl.clear();
      await _reloadProfitAndBreakdown();
    }
  }

  Widget _buildPengeluaranItemCard(ReportingProvider prov, PengeluaranModel item) {
    final displayTitle = _pengeluaranTitle(item);
    final isBulanan = item.tipe == 'bulanan';
    final isBelanjaBahan = item.sumber == 'barang_masuk' || item.tipe == 'belanja_bahan';

    final avatarBg = isBelanjaBahan
        ? Colors.teal.shade50
        : (isBulanan ? Colors.blue.shade50 : Colors.red.shade50);
    final avatarFg = isBelanjaBahan
        ? Colors.teal.shade700
        : (isBulanan ? Colors.blue.shade700 : Colors.red.shade700);
    final avatarIcon = isBelanjaBahan
        ? Icons.inventory_2_rounded
        : (isBulanan ? Icons.calendar_month_rounded : Icons.bolt_rounded);

    final badgeBg = avatarBg;
    final badgeFg = isBelanjaBahan
        ? Colors.teal.shade800
        : (isBulanan ? Colors.blue.shade800 : Colors.red.shade800);
    final badgeLabel = isBelanjaBahan
        ? 'Stok Bahan (${item.tanggal ?? "-"})'
        : (isBulanan ? 'Bulanan (${item.bulan ?? "-"})' : 'Mendadak (${item.tanggal ?? "-"})');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: avatarBg,
            child: Icon(avatarIcon, color: avatarFg),
          ),
          title: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                displayTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                _currencyFormat.format(item.nominal),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                  fontSize: 15,
                ),
              ),
              if (isBulanan && (item.proRataHarian != null && item.proRataHarian! > 0))
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Alokasi Harian: ${_currencyFormat.format(item.proRataHarian)} / hari'
                    '${item.jumlahHariBulan != null ? " (${item.jumlahHariBulan} hari)" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              if (isBelanjaBahan)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Tercatat otomatis dari Barang Masuk Gudang${item.jumlahItem != null ? " · ${item.jumlahItem} item" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
              if (item.keterangan != null && item.keterangan!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.keterangan!,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                ),
            ],
          ),
          trailing: !item.editable
              ? null
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Pengeluaran',
                onPressed: () => _showEditPengeluaranDialog(prov, item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Hapus',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Pengeluaran?'),
                      content: Text(
                        'Yakin ingin menghapus pengeluaran "$displayTitle" sebesar ${_currencyFormat.format(item.nominal)}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final res = await prov.deletePengeluaran(item.id);
                    _showSnack(res.message, isError: !res.success);
                    if (res.success) {
                      await _reloadProfitAndBreakdown();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditPengeluaranDialog(
    ReportingProvider prov,
    PengeluaranModel item,
  ) async {
    final isFreeTextMendadak =
        item.tipe == 'mendadak' && (item.kategoriId == null || item.kategoriId!.isEmpty);
    final displayTitle = _pengeluaranTitle(item);
    final namaCtrl = TextEditingController(text: displayTitle);
    final nomCtrl = TextEditingController(text: item.nominal.toStringAsFixed(0));
    final ketCtrl = TextEditingController(text: item.keterangan ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Pengeluaran ($displayTitle)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFreeTextMendadak) ...[
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama / Keperluan Pengeluaran',
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: nomCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ketCtrl,
              decoration: const InputDecoration(labelText: 'Keterangan'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final rawNom = nomCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
      final nom = double.tryParse(rawNom) ?? 0;
      if (nom <= 0) {
        _showSnack('Nominal harus lebih dari 0', isError: true);
        return;
      }
      final updatedNama = isFreeTextMendadak ? namaCtrl.text.trim() : null;
      if (isFreeTextMendadak && (updatedNama == null || updatedNama.isEmpty)) {
        _showSnack('Nama / keperluan pengeluaran mendadak wajib diisi', isError: true);
        return;
      }
      final res = await prov.updatePengeluaran(
        item.id,
        namaPengeluaran: updatedNama,
        nominal: nom,
        keterangan: ketCtrl.text.trim(),
      );
      _showSnack(res.message, isError: !res.success);
      if (res.success) {
        await _reloadProfitAndBreakdown();
      }
    }
  }

  // ===========================================================================
  // SECTION 4: MASTER KATEGORI PENGELUARAN
  // ===========================================================================
  Widget _buildKategoriView(ReportingProvider prov) {
    final kategoris = prov.kategoriList;

    return _wrapCenteredList(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah Kategori Biaya Operasional',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'Contoh: Listrik & Air, Sewa Tempat, Gaji Karyawan, Perawatan Alat, Bahan Darurat',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _namaKategoriCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kategori Biaya',
                        hintText: 'Misal: Listrik & Internet',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final nama = _namaKategoriCtrl.text.trim();
                      if (nama.isEmpty) {
                        _showSnack('Nama kategori wajib diisi', isError: true);
                        return;
                      }
                      final res = await prov.createKategori(nama);
                      _showSnack(res.message, isError: !res.success);
                      if (res.success) {
                        _namaKategoriCtrl.clear();
                        if (_formKategoriId == null &&
                            prov.activeKategoriList.isNotEmpty) {
                          setState(() {
                            _formKategoriId = prov.activeKategoriList.first.id;
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Daftar Kategori Biaya (${kategoris.length})',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 12),
        if (kategoris.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Center(
              child: Text(
                'Belum ada kategori pengeluaran terdaftar.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...kategoris.map(
            (k) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: k.statusAktif
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    child: Icon(
                      Icons.category_rounded,
                      color: k.statusAktif ? AppTheme.primaryColor : Colors.grey,
                    ),
                  ),
                  title: Text(
                    k.nama,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: k.statusAktif ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    k.statusAktif ? 'Status: Aktif' : 'Status: Nonaktif',
                    style: TextStyle(
                      fontSize: 12,
                      color: k.statusAktif ? Colors.green.shade700 : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Ubah Nama',
                        onPressed: () => _showEditKategoriDialog(prov, k),
                      ),
                      Switch(
                        value: k.statusAktif,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: (val) async {
                          final res = await prov.updateKategori(
                            k.id,
                            statusAktif: val,
                          );
                          _showSnack(res.message, isError: !res.success);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showEditKategoriDialog(
    ReportingProvider prov,
    KategoriPengeluaranModel k,
  ) async {
    final ctrl = TextEditingController(text: k.nama);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama Kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved != null && saved.isNotEmpty && saved != k.nama) {
      final res = await prov.updateKategori(k.id, nama: saved);
      _showSnack(res.message, isError: !res.success);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: HPP PER CUP/PORSI & MARGIN KEUNTUNGAN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHppMarginView(ReportingProvider prov) {
    final report = prov.hppMenuReport;
    final allItems = report?.items ?? [];
    final allBahanMonitor = report?.bahanMonitor ?? [];

    final q = _hppSearchQuery.trim().toLowerCase();
    final filteredMenus = allItems.where((m) {
      if (_hppAreaFilter != 'semua' && m.areaProduksi != _hppAreaFilter) {
        return false;
      }
      if (q.isNotEmpty &&
          !m.namaMenu.toLowerCase().contains(q) &&
          !m.kodeMenu.toLowerCase().contains(q) &&
          !m.kategoriNama.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    filteredMenus.sort((a, b) {
      switch (_hppSortBy) {
        case 'margin_asc':
          return a.marginPersen.compareTo(b.marginPersen);
        case 'margin_desc':
          return b.marginPersen.compareTo(a.marginPersen);
        case 'hpp_desc':
          return b.hppSaatIni.compareTo(a.hppSaatIni);
        case 'harga_desc':
          return b.hargaJual.compareTo(a.hargaJual);
        default:
          return a.kodeMenu.compareTo(b.kodeMenu);
      }
    });

    final filteredBahans = allBahanMonitor.where((b) {
      if (_hppAreaFilter != 'semua' && b.area != 'semua' && b.area != _hppAreaFilter) {
        return false;
      }
      if (q.isNotEmpty && !b.namaBahan.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    return _wrapCenteredList(
      children: [
          // 1. Info Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF3EF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7DEC9)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'HPP dihitung otomatis dari resep BOM × Harga Rata-rata (AVG) bahan gudang terkini. '
                    'Setiap barang masuk yang lebih murah atau lebih mahal otomatis memperbarui HPP & margin profit.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1B4332), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 680 ? 4 : 2;
              const gap = 12.0;
              final cardW = ((constraints.maxWidth - (cols - 1) * gap) / cols)
                  .clamp(120.0, 500.0);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _buildHppKpiBox(
                    width: cardW,
                    title: 'Menu Beresep',
                    value: '${report?.totalMenuBeresep ?? 0} / ${report?.totalMenu ?? 0}',
                    color: AppTheme.primaryColor,
                    icon: Icons.restaurant_menu_rounded,
                  ),
                  _buildHppKpiBox(
                    width: cardW,
                    title: 'Rata-rata Margin',
                    value: '${(report?.rataRataMarginPersen ?? 0).toStringAsFixed(1)}%',
                    color: Colors.green.shade700,
                    icon: Icons.trending_up_rounded,
                  ),
                  _buildHppKpiBox(
                    width: cardW,
                    title: 'Margin Tipis (<30%)',
                    value: '${report?.jumlahMenuMarginTipis ?? 0} Menu',
                    color: (report?.jumlahMenuMarginTipis ?? 0) > 0
                        ? Colors.orange.shade800
                        : Colors.grey.shade700,
                    icon: Icons.warning_amber_rounded,
                  ),
                  _buildHppKpiBox(
                    width: cardW,
                    title: 'Tanpa Resep',
                    value: '${report?.totalMenuTanpaResep ?? 0} Menu',
                    color: (report?.totalMenuTanpaResep ?? 0) > 0
                        ? Colors.red.shade700
                        : Colors.grey.shade700,
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Controls Card (Sub-tab + Area + Search + Sort)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('HPP & Margin Menu (${filteredMenus.length})'),
                      selected: !_hppShowBahanMonitor,
                      onSelected: (_) => setState(() => _hppShowBahanMonitor = false),
                    ),
                    ChoiceChip(
                      label: Text('Harga AVG Bahan (${filteredBahans.length})'),
                      selected: _hppShowBahanMonitor,
                      onSelected: (_) => setState(() => _hppShowBahanMonitor = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Semua Area'),
                      selected: _hppAreaFilter == 'semua',
                      onSelected: (_) => setState(() => _hppAreaFilter = 'semua'),
                    ),
                    FilterChip(
                      label: const Text('Bar (Minuman)'),
                      selected: _hppAreaFilter == 'bar',
                      onSelected: (_) => setState(() => _hppAreaFilter = 'bar'),
                    ),
                    FilterChip(
                      label: const Text('Kitchen (Makanan)'),
                      selected: _hppAreaFilter == 'kitchen',
                      onSelected: (_) => setState(() => _hppAreaFilter = 'kitchen'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _hppSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: _hppShowBahanMonitor
                        ? 'Cari nama bahan baku...'
                        : 'Cari kode atau nama menu...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (!_hppShowBahanMonitor) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _hppSortBy,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Urutkan Berdasarkan',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'kode', child: Text('Kode Menu (A–Z)')),
                      DropdownMenuItem(value: 'margin_asc', child: Text('Margin Terendah (Prioritas Cek)')),
                      DropdownMenuItem(value: 'margin_desc', child: Text('Margin Tertinggi (Paling Untung)')),
                      DropdownMenuItem(value: 'hpp_desc', child: Text('HPP Tertinggi')),
                      DropdownMenuItem(value: 'harga_desc', child: Text('Harga Jual Tertinggi')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _hppSortBy = val);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Content List
          if (report == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Data analisis HPP belum tersedia.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else if (!_hppShowBahanMonitor) ...[
            if (filteredMenus.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Tidak ada menu yang sesuai filter.')),
              )
            else
              ...filteredMenus.map(_buildHppMenuCard),
          ] else ...[
            if (filteredBahans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Tidak ada bahan baku yang sesuai filter.')),
              )
            else
              ...filteredBahans.map(_buildBahanHargaMonitorCard),
          ],
      ],
    );
  }

  Widget _buildHppKpiBox({
    required double width,
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHppMenuCard(MenuHppItemModel item) {
    final isExpanded = _expandedHppMenuIds.contains(item.menuId);
    final Color marginColor;
    final Color marginBg;
    final String marginLabel;
    if (!item.punyaResep) {
      marginColor = Colors.grey.shade700;
      marginBg = Colors.grey.shade200;
      marginLabel = 'Tanpa Resep';
    } else if (item.marginPersen >= 40) {
      marginColor = Colors.green.shade800;
      marginBg = Colors.green.shade50;
      marginLabel = 'Margin ${item.marginPersen.toStringAsFixed(1)}%';
    } else if (item.marginPersen >= 15) {
      marginColor = Colors.orange.shade900;
      marginBg = Colors.orange.shade50;
      marginLabel = 'Margin ${item.marginPersen.toStringAsFixed(1)}%';
    } else {
      marginColor = Colors.red.shade800;
      marginBg = Colors.red.shade50;
      marginLabel = item.labaKotor < 0
          ? 'Rugi (${item.marginPersen.toStringAsFixed(1)}%)'
          : 'Tipis ${item.marginPersen.toStringAsFixed(1)}%';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: item.resepItems.isEmpty
                ? null
                : () {
                    setState(() {
                      if (isExpanded) {
                        _expandedHppMenuIds.remove(item.menuId);
                      } else {
                        _expandedHppMenuIds.add(item.menuId);
                      }
                    });
                  },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.kodeMenu,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.namaMenu,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1A1D1B),
                              ),
                            ),
                            Text(
                              '${item.kategoriNama} • ${item.areaProduksi.toUpperCase()}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: marginBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            marginLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: marginColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      _buildHppStatPair('Harga Jual', _currencyFormat.format(item.hargaJual), AppTheme.textColor),
                      _buildHppStatPair('HPP (AVG Gudang)', _currencyFormat.format(item.hppSaatIni), Colors.orange.shade800),
                      _buildHppStatPair(
                        'Laba / Unit',
                        '${item.labaKotor >= 0 ? '+' : ''}${_currencyFormat.format(item.labaKotor)}',
                        item.labaKotor >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ],
                  ),
                  if (item.hppTerjualRataRata != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Rata-rata HPP terjual (${item.qtyTerjual}x): ${_currencyFormat.format(item.hppTerjualRataRata)}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                          ),
                          if (item.selisihHppVsRataTerjual != null &&
                              item.selisihHppVsRataTerjual != 0)
                            Text(
                              item.selisihHppVsRataTerjual! > 0
                                  ? 'HPP Naik +${_currencyFormat.format(item.selisihHppVsRataTerjual)}'
                                  : 'HPP Turun -${_currencyFormat.format(item.selisihHppVsRataTerjual!.abs())}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: item.selisihHppVsRataTerjual! > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (item.resepItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isExpanded
                                ? 'Sembunyikan Rincian BOM (${item.resepItems.length} bahan)'
                                : 'Lihat Rincian BOM (${item.resepItems.length} bahan)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded && item.resepItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBF9),
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.resepItems.map((r) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.namaBahan,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                              Text(
                                '${_qtyFormat.format(r.jumlahTerpakai)} ${r.satuan} × Rp ${_unitPriceFormat.format(r.hargaRataRata)}/${r.satuan}',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${_currencyFormat.format(r.subtotalHpp)} (${r.persentaseKontribusi.toStringAsFixed(0)}%)',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHppStatPair(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBahanHargaMonitorCard(BahanHargaMonitorModel b) {
    final diff = b.selisihTerakhirVsAvg;
    final bool naik = diff != null && diff > 0;
    final bool turun = diff != null && diff < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
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
                      b.namaBahan,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    Text(
                      'Area: ${b.area.toUpperCase()} • Dipakai di ${b.jumlahMenuTerkait} menu',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (diff != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: naik
                          ? Colors.red.shade50
                          : turun
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      naik
                          ? 'Beli Naik +Rp ${_unitPriceFormat.format(diff)}'
                          : turun
                              ? 'Beli Turun -Rp ${_unitPriceFormat.format(diff.abs())}'
                              : 'Stabil (Sama AVG)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: naik
                            ? Colors.red.shade700
                            : turun
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildHppStatPair(
                'Harga AVG Gudang',
                'Rp ${_unitPriceFormat.format(b.hargaRataRata)} / ${b.satuan}',
                AppTheme.primaryColor,
              ),
              _buildHppStatPair(
                'Harga Beli Terakhir',
                b.hargaBeliTerakhir != null
                    ? 'Rp ${_unitPriceFormat.format(b.hargaBeliTerakhir)} / ${b.satuan}'
                    : 'Belum ada masuk',
                Colors.grey.shade800,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetric {
  final String label;
  final String value;
  final Color? dotColor;
  final Color? valueColor;

  const _CompactMetric({
    required this.label,
    required this.value,
    this.dotColor,
    this.valueColor,
  });
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
