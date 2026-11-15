import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
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
  int _formBulanMonth = DateTime.now().month;
  int _formBulanYear = DateTime.now().year;
  final TextEditingController _nominalCtrl = TextEditingController();
  final TextEditingController _ketCtrl = TextEditingController();
  String _filterPengeluaranTipe = ''; // '' | 'bulanan' | 'mendadak'

  // Form state for Section 4 (Kategori Pengeluaran)
  final TextEditingController _namaKategoriCtrl = TextEditingController();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static const List<_ReportSectionMeta> _sections = [
    _ReportSectionMeta(
      index: 0,
      title: 'Laba Rugi & Penjualan',
      subtitle: 'Ringkasan omzet, HPP teoritis, net profit, dan transaksi periode',
      icon: Icons.trending_up_rounded,
    ),
    _ReportSectionMeta(
      index: 1,
      title: 'Laporan Stok & Opname',
      subtitle: 'Ringkasan mutasi barang gudang, sesi opname, dan stok menipis',
      icon: Icons.inventory_2_outlined,
    ),
    _ReportSectionMeta(
      index: 2,
      title: 'Laporan Kedisiplinan Absensi',
      subtitle: 'Rekap kehadiran shift, keterlambatan, dan pengajuan izin periode',
      icon: Icons.fingerprint_rounded,
    ),
    _ReportSectionMeta(
      index: 3,
      title: 'Catat & Riwayat Pengeluaran',
      subtitle: 'Input biaya operasional bulanan (pro-rata) dan mendadak (insidental)',
      icon: Icons.receipt_long_outlined,
    ),
    _ReportSectionMeta(
      index: 4,
      title: 'Kategori Biaya Operasional',
      subtitle: 'Kelola master kategori pengeluaran cafe',
      icon: Icons.category_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection.clamp(0, _sections.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void didUpdateWidget(covariant ReportingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _currentSection = widget.initialSection.clamp(0, _sections.length - 1);
      });
    }
  }

  @override
  void dispose() {
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
    final meta = _sections[_currentSection];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // ── Minimalist Top Header with Dropdown Menu Selector ──────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          meta.title,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1D1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dropdown Sub-menu Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _currentSection,
                              icon: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                              items: _sections
                                  .map(
                                    (s) => DropdownMenuItem<int>(
                                      value: s.index,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(s.icon, size: 17, color: AppTheme.primaryColor),
                                          const SizedBox(width: 8),
                                          Text(s.title),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _currentSection = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.outlined(
                          onPressed: prov.isLoading ? null : _refreshAll,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: 'Muat Ulang Data',
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Page Content ───────────────────────────────────────────────────
          Expanded(
            child: prov.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCurrentSectionContent(prov),
          ),
        ],
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
        const SizedBox(height: 20),
        _buildAbsensiSummaryCard(report),
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
              Text(
                'Filter Periode Laporan',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFF1A1D1B),
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
            'NET PROFIT (KEUNTUNGAN BERSIH)',
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
          const SizedBox(height: 8),
          const Text(
            'Total Penjualan − Total HPP (Snapshot Resep) − Biaya Bulanan Pro-Rata − Biaya Mendadak',
            style: TextStyle(color: Colors.white70, fontSize: 12),
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
        title: 'Total HPP Teoritis',
        value: _currencyFormat.format(report?.totalHppTeoritis ?? 0),
        subtitle: 'Snapshot HPP saat transaksi',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFB45309),
      ),
      _MetricCardData(
        title: 'Biaya Bulanan (Pro-Rata)',
        value: _currencyFormat.format(report?.pengeluaranBulananProRata ?? 0),
        subtitle: 'Alokasi harian periode terpilih',
        icon: Icons.calendar_view_month_rounded,
        color: const Color(0xFF1D4ED8),
      ),
      _MetricCardData(
        title: 'Pengeluaran Mendadak',
        value: _currencyFormat.format(report?.pengeluaranMendadak ?? 0),
        subtitle: 'Biaya insidental pada periode',
        icon: Icons.bolt_rounded,
        color: const Color(0xFFB91C1C),
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
              const Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Text(
                'Ringkasan Transaksi & Metode Pembayaran',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildMiniStatPill(
                'Transaksi Selesai',
                '${report?.jumlahTransaksi ?? 0} Nota',
                Colors.green.shade700,
              ),
              _buildMiniStatPill(
                'Pembayaran Tunai (Cash)',
                _currencyFormat.format(report?.totalCash ?? 0),
                Colors.teal.shade700,
              ),
              _buildMiniStatPill(
                'Pembayaran QRIS Statis',
                _currencyFormat.format(report?.totalQris ?? 0),
                Colors.indigo.shade700,
              ),
              _buildMiniStatPill(
                'Transaksi Dibatalkan (Void)',
                '${report?.jumlahTransaksiDibatalkan ?? 0} Nota',
                Colors.red.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStokSummaryCard(ProfitReportModel? report) {
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
              const Icon(Icons.warehouse_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Text(
                'Ringkasan Pergerakan Stok & Opname Periode',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildMiniStatPill(
                'Barang Masuk Gudang',
                '${report?.jumlahBarangMasuk ?? 0} Pencatatan',
                Colors.blue.shade700,
              ),
              _buildMiniStatPill(
                'Barang Keluar ke Bar/Kitchen',
                '${report?.jumlahBarangKeluar ?? 0} Transfer',
                Colors.orange.shade800,
              ),
              _buildMiniStatPill(
                'Sesi Stock Opname',
                '${report?.jumlahSesiOpname ?? 0} Sesi',
                AppTheme.primaryColor,
              ),
              _buildMiniStatPill(
                'Bahan di Bawah Stok Minimum',
                '${report?.jumlahStokMenipis ?? 0} Bahan',
                Colors.red.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbsensiSummaryCard(ProfitReportModel? report) {
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
              const Icon(Icons.fingerprint_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Text(
                'Ringkasan Kehadiran, Keterlambatan & Izin Periode',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildMiniStatPill(
                'Total Kehadiran Masuk',
                '${report?.totalHadir ?? 0} Shift',
                AppTheme.primaryColor,
              ),
              _buildMiniStatPill(
                'Hadir Tepat Waktu',
                '${report?.totalTepatWaktu ?? 0} Shift',
                Colors.green.shade700,
              ),
              _buildMiniStatPill(
                'Hadir Terlambat',
                '${report?.totalTerlambat ?? 0} Shift',
                Colors.red.shade700,
              ),
              _buildMiniStatPill(
                'Pengajuan Izin Terlambat',
                '${report?.totalIzinTelat ?? 0} Pengajuan',
                Colors.amber.shade900,
              ),
              _buildMiniStatPill(
                'Izin Tidak Masuk (Ketidakhadiran)',
                '${report?.totalIzinTidakMasuk ?? 0} Pengajuan',
                Colors.purple.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(ExpenseBreakdownReportModel? breakdown) {
    final items = breakdown?.items ?? [];
    final total = breakdown?.totalPengeluaran ?? 0.0;

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
              const Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Proporsi Pengeluaran per Kategori',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Text(
                _currencyFormat.format(total),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Gabungan biaya mendadak & alokasi pro-rata bulanan pada periode terpilih',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const Divider(height: 28),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada pengeluaran tercatat pada periode ini.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...items.map((item) {
              final pct = (item.persentase.clamp(0.0, 100.0)) / 100.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
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
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Text(
                          '${_currencyFormat.format(item.totalNominal)} (${item.persentase.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade100,
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

  Widget _buildMiniStatPill(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
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
                      const SizedBox(width: 14),
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
                              'Batas Minimum: ${b.batasStokMinimum.toStringAsFixed(0)} ${b.satuanDasar}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Sisa: ${b.totalStok.toStringAsFixed(1)} ${b.satuanDasar}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
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
  Widget _buildPengeluaranView(ReportingProvider prov) {
    final activeKategoris = prov.activeKategoriList;
    final filteredList = _filterPengeluaranTipe.isEmpty
        ? prov.pengeluaranList
        : prov.pengeluaranList
            .where((e) => e.tipe == _filterPengeluaranTipe)
            .toList();

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
                'Catat Pengeluaran Operasional Baru',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'Pengeluaran Bulanan dialokasikan pro-rata per hari, sedangkan Pengeluaran Mendadak dibebankan pada tanggal kejadian.',
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
                  if (val != null) setState(() => _formTipe = val);
                },
              ),
              const SizedBox(height: 16),
              if (activeKategoris.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Belum ada Kategori Biaya aktif. Silakan tambah kategori terlebih dahulu.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentSection = 4),
                        child: const Text('Kelola Kategori'),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: activeKategoris.any((k) => k.id == _formKategoriId)
                      ? _formKategoriId
                      : activeKategoris.first.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori Pengeluaran'),
                  items: activeKategoris
                      .map(
                        (k) => DropdownMenuItem(
                          value: k.id,
                          child: Text(k.nama, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _formKategoriId = val),
                ),
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _formBulanMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Bulan'),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('Bulan ${(i + 1).toString().padLeft(2, '0')}'),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _formBulanMonth = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _formBulanYear,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tahun'),
                        items: List.generate(
                          5,
                          (i) {
                            final y = DateTime.now().year - 2 + i;
                            return DropdownMenuItem(value: y, child: Text('$y'));
                          },
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _formBulanYear = val);
                        },
                      ),
                    ),
                  ],
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
              const SizedBox(height: 16),
              TextField(
                controller: _ketCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (Opsional)',
                  hintText: 'Contoh: Pembelian gas dapur / Tagihan listrik bulanan',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: activeKategoris.isEmpty
                      ? null
                      : () => _handleSubmitPengeluaran(prov, activeKategoris),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Simpan Pengeluaran'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Riwayat Pengeluaran Tercatat',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterPengeluaranTipe,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua Tipe')),
                    DropdownMenuItem(value: 'mendadak', child: Text('Mendadak')),
                    DropdownMenuItem(value: 'bulanan', child: Text('Bulanan')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterPengeluaranTipe = val);
                  },
                ),
              ),
            ),
          ],
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

  Future<void> _handleSubmitPengeluaran(
    ReportingProvider prov,
    List<KategoriPengeluaranModel> activeKategoris,
  ) async {
    final rawNominal = _nominalCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    final nominal = double.tryParse(rawNominal) ?? 0;
    if (nominal <= 0) {
      _showSnack('Nominal pengeluaran harus lebih dari 0', isError: true);
      return;
    }
    final katId = activeKategoris.any((k) => k.id == _formKategoriId)
        ? _formKategoriId!
        : activeKategoris.first.id;

    final res = await prov.createPengeluaran(
      tipe: _formTipe,
      kategoriId: katId,
      nominal: nominal,
      bulan: _formTipe == 'bulanan'
          ? _fmtMonth(_formBulanYear, _formBulanMonth)
          : null,
      tanggal: _formTipe == 'mendadak' ? _fmtDate(_formTanggal) : null,
      keterangan: _ketCtrl.text,
    );

    _showSnack(res.message, isError: !res.success);
    if (res.success) {
      _nominalCtrl.clear();
      _ketCtrl.clear();
      await _reloadProfitAndBreakdown();
    }
  }

  Widget _buildPengeluaranItemCard(ReportingProvider prov, PengeluaranModel item) {
    final isBulanan = item.tipe == 'bulanan';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isBulanan ? Colors.blue.shade50 : Colors.red.shade50,
            child: Icon(
              isBulanan ? Icons.calendar_month_rounded : Icons.bolt_rounded,
              color: isBulanan ? Colors.blue.shade700 : Colors.red.shade700,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.namaKategori,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isBulanan ? Colors.blue.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isBulanan
                      ? 'Bulanan (${item.bulan ?? "-"})'
                      : 'Mendadak (${item.tanggal ?? "-"})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isBulanan ? Colors.blue.shade800 : Colors.red.shade800,
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
          trailing: Row(
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
                        'Yakin ingin menghapus pengeluaran "${item.namaKategori}" sebesar ${_currencyFormat.format(item.nominal)}?',
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
    final nomCtrl = TextEditingController(text: item.nominal.toStringAsFixed(0));
    final ketCtrl = TextEditingController(text: item.keterangan ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Pengeluaran (${item.namaKategori})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      final res = await prov.updatePengeluaran(
        item.id,
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
}

class _ReportSectionMeta {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ReportSectionMeta({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
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
