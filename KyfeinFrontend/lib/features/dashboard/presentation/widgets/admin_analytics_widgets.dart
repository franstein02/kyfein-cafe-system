import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../providers/dashboard_provider.dart';

const _kPrimary = Color(0xFF1B4332);
const _kEmerald = Color(0xFF10B981);
const _kSurface = Colors.white;
const _kBorder = Color(0xFFE5EBE7);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextDim = Color(0xFF7A7A7A);

final _idrFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String _formatCompactRp(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 1000000000) {
    final v = abs / 1000000000;
    return '${sign}Rp ${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M';
  }
  if (abs >= 1000000) {
    final v = abs / 1000000;
    return '${sign}Rp ${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}jt';
  }
  if (abs >= 1000) {
    final v = abs / 1000;
    return '${sign}Rp ${v.toStringAsFixed(0)}rb';
  }
  return '${sign}Rp ${abs.toStringAsFixed(0)}';
}

String _formatCompactAxis(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs == 0) return '0';
  if (abs >= 1000000000) {
    final v = abs / 1000000000;
    return '$sign${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M';
  }
  if (abs >= 1000000) {
    final v = abs / 1000000;
    return '$sign${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}jt';
  }
  if (abs >= 1000) {
    final v = abs / 1000;
    return '$sign${v.toStringAsFixed(0)}rb';
  }
  return '$sign${abs.toStringAsFixed(0)}';
}

String _formatIndoRange(String? startIso, String? endIso) {
  if (startIso == null || startIso.isEmpty) return '';
  final s = DateTime.tryParse(startIso);
  final e = (endIso != null && endIso.isNotEmpty) ? DateTime.tryParse(endIso) : s;
  if (s == null) return startIso;
  final fmt = DateFormat('dd MMM yyyy');
  if (e == null || (s.year == e.year && s.month == e.month && s.day == e.day)) {
    return fmt.format(s);
  }
  if (s.year == e.year) {
    return '${DateFormat('dd MMM').format(s)} – ${fmt.format(e)}';
  }
  return '${fmt.format(s)} – ${fmt.format(e)}';
}

class _AnalyticsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _AnalyticsCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Filter periode cepat untuk Dashboard Admin / Owner.
class AdminPeriodFilterBar extends StatelessWidget {
  final DashboardProvider dashboard;

  const AdminPeriodFilterBar({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final preset = dashboard.selectedPreset;
    final overview = dashboard.overview;

    String customLabel = 'Rentang';
    if (preset == 'custom' &&
        dashboard.customStart != null &&
        dashboard.customEnd != null) {
      customLabel =
          '${DateFormat('dd MMM').format(dashboard.customStart!)} – ${DateFormat('dd MMM').format(dashboard.customEnd!)}';
    }

    final periodeText = overview != null
        ? _formatIndoRange(overview.periodeMulai, overview.periodeSelesai)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _presetChip('Hari Ini', 'hari_ini', preset == 'hari_ini', () {
              dashboard.applyOverviewPreset('hari_ini');
            }),
            _presetChip('7 Hari', '7_hari', preset == '7_hari', () {
              dashboard.applyOverviewPreset('7_hari');
            }),
            _presetChip('30 Hari', '30_hari', preset == '30_hari', () {
              dashboard.applyOverviewPreset('30_hari');
            }),
            _presetChip('Bulan Ini', 'bulan_ini', preset == 'bulan_ini', () {
              dashboard.applyOverviewPreset('bulan_ini');
            }),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: preset == 'custom' ? Colors.white : _kPrimary,
                backgroundColor:
                    preset == 'custom' ? _kPrimary : Colors.white,
                side: BorderSide(
                  color: preset == 'custom' ? _kPrimary : _kBorder,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.date_range_rounded, size: 15),
              label: Text(
                customLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: (dashboard.customStart != null &&
                          dashboard.customEnd != null)
                      ? DateTimeRange(
                          start: dashboard.customStart!,
                          end: dashboard.customEnd!,
                        )
                      : null,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: _kPrimary,
                          onPrimary: Colors.white,
                          onSurface: _kTextDark,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  await dashboard.applyCustomRange(range.start, range.end);
                }
              },
            ),
          ],
        ),
        if (periodeText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: _kTextDim),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Data ringkasan: $periodeText',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (dashboard.isOverviewLoading) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 2.5,
              color: _kPrimary,
              backgroundColor: Color(0xFFE5EBE7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _presetChip(
    String label,
    String keyVal,
    bool selected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: _kPrimary,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _kPrimary : _kBorder),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : _kTextDark,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

/// Grid 4 kartu ringkasan penjualan, keuntungan, HPP & biaya, serta transaksi.
class AdminKpiSection extends StatelessWidget {
  final DashboardProvider dashboard;

  const AdminKpiSection({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final ov = dashboard.overview;
    final legacy = dashboard.adminSummary;

    final totalPenjualan = ov?.totalPenjualan ?? legacy?.totalPenjualan ?? 0.0;
    final netProfit = ov?.netProfit ?? legacy?.profitHarian ?? 0.0;
    final totalHpp = ov?.totalHppTeoritis ?? 0.0;
    final totalPengeluaran = ov?.totalPengeluaran ?? 0.0;
    final jmlTrx = ov?.jumlahTransaksi ?? legacy?.jumlahTransaksi ?? 0;
    final jmlBatal = ov?.jumlahTransaksiDibatalkan ?? 0;
    final avgTrx = ov?.rataRataTransaksi ??
        (jmlTrx > 0 ? totalPenjualan / jmlTrx : 0.0);
    final marginPct = ov?.marginProfitPersen ??
        (totalPenjualan > 0 ? (netProfit / totalPenjualan) * 100 : 0.0);
    final cash = ov?.totalCash ?? 0.0;
    final qris = ov?.totalQris ?? 0.0;
    final pctChange = ov?.perubahanPenjualanPersen;
    final belanjaBahan = ov?.totalBelanjaBarangMasuk ?? 0.0;
    final totalKasKeluar = ov?.totalPengeluaranKas ?? (totalPengeluaran + belanjaBahan);
    final arusKasBersih = ov?.arusKasBersih ?? (totalPenjualan - totalKasKeluar);
    final nilaiAsetStok = ov?.nilaiAsetStokSaatIni ?? 0.0;

    String salesBadgeText = '';
    Color salesBadgeColor = _kEmerald;
    if (pctChange != null) {
      final sign = pctChange >= 0 ? '+' : '';
      salesBadgeText = '$sign${pctChange.toStringAsFixed(1)}% vs sblmnya';
      salesBadgeColor =
          pctChange >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
    }

    final cards = [
      _KpiCardItem(
        label: 'Total Penjualan',
        value: _idrFormat.format(totalPenjualan),
        valueColor: _kTextDark,
        icon: Icons.trending_up_rounded,
        iconColor: _kEmerald,
        badgeText: salesBadgeText.isNotEmpty ? salesBadgeText : null,
        badgeColor: salesBadgeColor,
        subtitle:
            'Cash ${_formatCompactRp(cash)} · QRIS ${_formatCompactRp(qris)}',
      ),
      _KpiCardItem(
        label: 'Keuntungan Bersih',
        value: _idrFormat.format(netProfit),
        valueColor: netProfit >= 0
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        icon: Icons.savings_rounded,
        iconColor: const Color(0xFF6366F1),
        badgeText: 'Margin ${marginPct.toStringAsFixed(1)}%',
        badgeColor: netProfit >= 0
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        subtitle: 'Setelah HPP & biaya ops',
      ),
      _KpiCardItem(
        label: 'HPP & Biaya Ops',
        value: _idrFormat.format(totalHpp + totalPengeluaran),
        valueColor: _kTextDark,
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xFFD97706),
        subtitle:
            'HPP ${_formatCompactRp(totalHpp)} · Biaya ${_formatCompactRp(totalPengeluaran)}',
      ),
      _KpiCardItem(
        label: 'Transaksi Selesai',
        value: '$jmlTrx',
        valueColor: _kTextDark,
        icon: Icons.point_of_sale_rounded,
        iconColor: _kPrimary,
        badgeText: jmlBatal > 0 ? '$jmlBatal batal' : null,
        badgeColor: const Color(0xFFDC2626),
        subtitle: 'Rata-rata ${_formatCompactRp(avgTrx)}/trx',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard(cards[i])),
                    ],
                  ],
                ),
              );
            }

            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildKpiCard(cards[0])),
                      const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard(cards[1])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildKpiCard(cards[2])),
                      const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard(cards[3])),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _AnalyticsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: _kPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Arus Kas Riil (Belanja Bahan + Ops) & Nilai Stok',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  final items = [
                    (
                      'Total Pengeluaran Kas',
                      _idrFormat.format(totalKasKeluar),
                      'Bahan ${_formatCompactRp(belanjaBahan)} · Ops ${_formatCompactRp(totalPengeluaran)}',
                      const Color(0xFFB45309),
                    ),
                    (
                      'Arus Kas Bersih',
                      _idrFormat.format(arusKasBersih),
                      arusKasBersih >= 0
                          ? 'Surplus kas periode'
                          : 'Belum BEP modal stok',
                      arusKasBersih >= 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                    (
                      'Aset Stok Tersisa',
                      _idrFormat.format(nilaiAsetStok),
                      'Modal tersimpan di gudang & titik',
                      _kPrimary,
                    ),
                  ];
                  if (c.maxWidth >= 680) {
                    return Row(
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _cashSummaryCell(
                              items[i].$1,
                              items[i].$2,
                              items[i].$3,
                              items[i].$4,
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _cashSummaryCell(
                          items[i].$1,
                          items[i].$2,
                          items[i].$3,
                          items[i].$4,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cashSummaryCell(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _kTextDim,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: _kTextDim),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(_KpiCardItem item) {
    return _AnalyticsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kTextDim,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 15, color: item.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: item.valueColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (item.badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.badgeText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: item.badgeColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: _kTextDim),
          ),
        ],
      ),
    );
  }
}

class _KpiCardItem {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;
  final String? badgeText;
  final Color badgeColor;
  final String subtitle;

  const _KpiCardItem({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
    this.badgeText,
    this.badgeColor = _kEmerald,
    required this.subtitle,
  });
}

/// Grafik batang interaktif untuk Penjualan & Keuntungan.
class AdminSalesChartCard extends StatefulWidget {
  final DashboardProvider dashboard;

  const AdminSalesChartCard({super.key, required this.dashboard});

  @override
  State<AdminSalesChartCard> createState() => _AdminSalesChartCardState();
}

class _AdminSalesChartCardState extends State<AdminSalesChartCard> {
  String _metric = 'keduanya'; // 'keduanya' | 'penjualan' | 'profit'
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final ov = widget.dashboard.overview;
    final points = ov?.grafikPenjualan ?? const <SalesChartPoint>[];
    final granularity = ov?.chartGranularity ?? 'hari';
    final isDailyPreset = widget.dashboard.selectedPreset == 'hari_ini';

    final String subtitle;
    if (ov == null) {
      subtitle = 'Memuat data tren penjualan...';
    } else if (granularity == 'jam') {
      subtitle = 'Per Jam · ${_formatIndoRange(ov.chartPeriodeMulai, ov.chartPeriodeSelesai)}';
    } else if (granularity == 'bulan') {
      subtitle = 'Per Bulan · ${_formatIndoRange(ov.chartPeriodeMulai, ov.chartPeriodeSelesai)}';
    } else {
      subtitle = 'Per Hari · ${_formatIndoRange(ov.chartPeriodeMulai, ov.chartPeriodeSelesai)}';
    }

    int? activeIdx = _selectedIndex;
    if (activeIdx != null && activeIdx >= points.length) {
      activeIdx = null;
    }
    if (activeIdx == null && points.isNotEmpty) {
      final lastActive = points.lastIndexWhere((p) => p.totalPenjualan > 0);
      activeIdx = lastActive >= 0 ? lastActive : points.length - 1;
    }
    final activePoint = (activeIdx != null && activeIdx < points.length)
        ? points[activeIdx]
        : null;

    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grafik Penjualan & Profit',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _kTextDim),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isDailyPreset)
                    _pillToggle(
                      label: widget.dashboard.chartMode == 'jam'
                          ? 'Lihat 7 Hari'
                          : 'Per Jam Hari Ini',
                      selected: widget.dashboard.chartMode == 'jam',
                      onTap: () {
                        final next = widget.dashboard.chartMode == 'jam'
                            ? 'auto'
                            : 'jam';
                        widget.dashboard.setChartMode(next);
                      },
                    ),
                  _metricChip('Semua', 'keduanya'),
                  _metricChip('Penjualan', 'penjualan'),
                  _metricChip('Profit', 'profit'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activePoint != null) _buildSelectedTooltip(activePoint),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'Belum ada data grafik penjualan untuk periode ini',
                  style: TextStyle(fontSize: 13, color: _kTextDim),
                ),
              ),
            )
          else
            _buildChartCanvas(points, activeIdx),
          const SizedBox(height: 10),
          _buildLegend(points),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String key) {
    final selected = _metric == key;
    return _pillToggle(
      label: label,
      selected: selected,
      onTap: () => setState(() => _metric = key),
    );
  }

  Widget _pillToggle({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : const Color(0xFFF3F6F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _kTextDark,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTooltip(SalesChartPoint p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            p.label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
            ),
          ),
          Text(
            'Penjualan: ${_idrFormat.format(p.totalPenjualan)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kTextDark,
            ),
          ),
          Text(
            'Profit: ${_idrFormat.format(p.netProfit)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.netProfit >= 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
            ),
          ),
          Text(
            '${p.jumlahTransaksi} trx',
            style: const TextStyle(fontSize: 11.5, color: _kTextDim),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCanvas(List<SalesChartPoint> points, int? activeIdx) {
    double maxVal = 0;
    double minVal = 0;
    for (final p in points) {
      if (_metric == 'keduanya' || _metric == 'penjualan') {
        maxVal = math.max(maxVal, p.totalPenjualan);
      }
      if (_metric == 'keduanya' || _metric == 'profit') {
        maxVal = math.max(maxVal, p.netProfit);
        minVal = math.min(minVal, p.netProfit);
      }
    }
    if (maxVal <= 0 && minVal >= 0) {
      maxVal = 100000;
    } else {
      maxVal = maxVal > 0 ? maxVal * 1.15 : 0;
      minVal = minVal < 0 ? minVal * 1.15 : 0;
    }

    const chartHeight = 200.0;
    const topPad = 10.0;
    const bottomAxisHeight = 24.0;
    final minSlotWidth = _metric == 'keduanya' ? 32.0 : 28.0;

    return SizedBox(
      height: chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: topPad, bottom: bottomAxisHeight),
              child: _YAxisLabels(minVal: minVal, maxVal: maxVal),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availW = constraints.maxWidth;
                final slotW = math.max(availW / points.length, minSlotWidth);
                final totalW = slotW * points.length;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final idx = (details.localPosition.dx ~/ slotW)
                          .clamp(0, points.length - 1);
                      setState(() => _selectedIndex = idx);
                    },
                    child: CustomPaint(
                      size: Size(totalW, chartHeight),
                      painter: _SalesChartPainter(
                        points: points,
                        metric: _metric,
                        minVal: minVal,
                        maxVal: maxVal,
                        slotWidth: slotW,
                        selectedIndex: activeIdx,
                        topPad: topPad,
                        bottomAxisHeight: bottomAxisHeight,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(List<SalesChartPoint> points) {
    final hasNegative = points.any((p) => p.netProfit < 0);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        if (_metric == 'keduanya' || _metric == 'penjualan')
          _legendDot(_kPrimary, 'Penjualan'),
        if (_metric == 'keduanya' || _metric == 'profit')
          _legendDot(_kEmerald, 'Keuntungan (+)'),
        if ((_metric == 'keduanya' || _metric == 'profit') && hasNegative)
          _legendDot(const Color(0xFFEF4444), 'Rugi / Minus (-)'),
        const Text(
          'Ketuk batang grafik untuk detail',
          style: TextStyle(fontSize: 11, color: _kTextDim),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  final double minVal;
  final double maxVal;

  const _YAxisLabels({required this.minVal, required this.maxVal});

  @override
  Widget build(BuildContext context) {
    final span = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);
    final midVal = minVal + span * 0.5;
    final labels = [
      _formatCompactAxis(maxVal),
      _formatCompactAxis(midVal),
      _formatCompactAxis(minVal),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: labels
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _kTextDim),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  final List<SalesChartPoint> points;
  final String metric;
  final double minVal;
  final double maxVal;
  final double slotWidth;
  final int? selectedIndex;
  final double topPad;
  final double bottomAxisHeight;

  _SalesChartPainter({
    required this.points,
    required this.metric,
    required this.minVal,
    required this.maxVal,
    required this.slotWidth,
    required this.selectedIndex,
    required this.topPad,
    required this.bottomAxisHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - topPad - bottomAxisHeight;
    final span = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);

    double yFor(double v) {
      final norm = (v - minVal) / span;
      return topPad + plotHeight * (1 - norm);
    }

    final zeroY = yFor(0).clamp(topPad, topPad + plotHeight);

    // 1. Horizontal guide lines (top, mid, zero/bottom)
    final gridPaint = Paint()
      ..color = const Color(0xFFE5EBE7)
      ..strokeWidth = 1;
    for (final ratio in [0.0, 0.5, 1.0]) {
      final y = topPad + plotHeight * ratio;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final zeroPaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);

    // 2. Selected highlight column
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final sx = selectedIndex! * slotWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sx + 2, topPad - 2, slotWidth - 4, plotHeight + 4),
          const Radius.circular(8),
        ),
        Paint()..color = _kPrimary.withValues(alpha: 0.06),
      );
    }

    // 3. Bars + X-axis labels
    final salesPaint = Paint()..color = _kPrimary;
    final salesSelPaint = Paint()..color = const Color(0xFF14532D);
    final profitPosPaint = Paint()..color = _kEmerald;
    final profitNegPaint = Paint()..color = const Color(0xFFEF4444);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final slotX = i * slotWidth;
      final isSel = i == selectedIndex;

      if (metric == 'keduanya') {
        final barW = ((slotWidth - 14) / 2).clamp(6.0, 18.0);
        const gap = 3.0;
        final startX = slotX + (slotWidth - (barW * 2 + gap)) / 2;

        _drawBar(
          canvas: canvas,
          x: startX,
          width: barW,
          zeroY: zeroY,
          targetY: yFor(p.totalPenjualan),
          paint: isSel ? salesSelPaint : salesPaint,
        );
        _drawBar(
          canvas: canvas,
          x: startX + barW + gap,
          width: barW,
          zeroY: zeroY,
          targetY: yFor(p.netProfit),
          paint: p.netProfit >= 0 ? profitPosPaint : profitNegPaint,
        );
      } else if (metric == 'penjualan') {
        final barW = (slotWidth - 16).clamp(8.0, 26.0);
        final startX = slotX + (slotWidth - barW) / 2;
        _drawBar(
          canvas: canvas,
          x: startX,
          width: barW,
          zeroY: zeroY,
          targetY: yFor(p.totalPenjualan),
          paint: isSel ? profitPosPaint : salesPaint,
        );
      } else {
        final barW = (slotWidth - 16).clamp(8.0, 26.0);
        final startX = slotX + (slotWidth - barW) / 2;
        _drawBar(
          canvas: canvas,
          x: startX,
          width: barW,
          zeroY: zeroY,
          targetY: yFor(p.netProfit),
          paint: p.netProfit >= 0 ? profitPosPaint : profitNegPaint,
        );
      }

      // Draw X-axis label
      final tp = TextPainter(
        text: TextSpan(
          text: p.label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? _kPrimary : _kTextDim,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: slotWidth - 2);
      tp.paint(
        canvas,
        Offset(
          slotX + (slotWidth - tp.width) / 2,
          topPad + plotHeight + 6,
        ),
      );
    }
  }

  void _drawBar({
    required Canvas canvas,
    required double x,
    required double width,
    required double zeroY,
    required double targetY,
    required Paint paint,
  }) {
    final diff = (zeroY - targetY).abs();
    if (diff < 1.0) {
      // Minimal visible stub for 0 value? No, skip flat 0 to keep chart clean
      return;
    }
    final isPositive = targetY <= zeroY;
    final rect = isPositive
        ? Rect.fromLTRB(x, targetY, x + width, zeroY)
        : Rect.fromLTRB(x, zeroY, x + width, targetY);
    final radius = Radius.circular(math.min(5, width / 2));
    final rrect = isPositive
        ? RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius)
        : RRect.fromRectAndCorners(rect, bottomLeft: radius, bottomRight: radius);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.metric != metric ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.slotWidth != slotWidth;
  }
}

/// Kartu perilaku & kedisiplinan karyawan (sering telat, lupa absen pulang, izin, alpha).
class AdminEmployeeBehaviorCard extends StatefulWidget {
  final DashboardProvider dashboard;

  const AdminEmployeeBehaviorCard({super.key, required this.dashboard});

  @override
  State<AdminEmployeeBehaviorCard> createState() =>
      _AdminEmployeeBehaviorCardState();
}

class _AdminEmployeeBehaviorCardState extends State<AdminEmployeeBehaviorCard> {
  String _filter = 'semua'; // 'semua' | 'perlu_perhatian' | 'telat' | 'disiplin'

  @override
  Widget build(BuildContext context) {
    final ov = widget.dashboard.overview;
    final allItems = ov?.perilakuKaryawan ?? const <EmployeeBehaviorItem>[];

    final seriousCount = allItems
        .where((e) => e.kategoriPerilaku == 'perlu_perhatian')
        .length;
    final lateOrWarnCount = allItems
        .where((e) =>
            e.telatCount > 0 ||
            e.kategoriPerilaku == 'perlu_perhatian' ||
            e.kategoriPerilaku == 'waspada')
        .length;
    final cleanCount =
        allItems.where((e) => e.kategoriPerilaku == 'disiplin').length;

    final filtered = allItems.where((e) {
      switch (_filter) {
        case 'perlu_perhatian':
          return e.kategoriPerilaku == 'perlu_perhatian';
        case 'telat':
          return e.telatCount > 0 ||
              e.kategoriPerilaku == 'perlu_perhatian' ||
              e.kategoriPerilaku == 'waspada';
        case 'disiplin':
          return e.kategoriPerilaku == 'disiplin';
        default:
          return true;
      }
    }).toList();

    final evalRange = ov != null
        ? _formatIndoRange(ov.periodePerilakuMulai, ov.periodePerilakuSelesai)
        : '';

    return _AnalyticsCard(
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
                      'Perilaku & Kedisiplinan Karyawan',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),
                    if (evalRange.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Evaluasi: $evalRange',
                        style:
                            const TextStyle(fontSize: 12, color: _kTextDim),
                      ),
                    ],
                  ],
                ),
              ),
              if (ov != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ov.tingkatKetepatanTimPersen >= 85
                        ? const Color(0xFFDCFCE7)
                        : (ov.tingkatKetepatanTimPersen >= 65
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tepat Waktu ${ov.tingkatKetepatanTimPersen.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: ov.tingkatKetepatanTimPersen >= 85
                          ? const Color(0xFF166534)
                          : (ov.tingkatKetepatanTimPersen >= 65
                              ? const Color(0xFF92400E)
                              : const Color(0xFF991B1B)),
                    ),
                  ),
                ),
            ],
          ),
          if (ov != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _teamStatChip(
                  'Hadir: ${ov.ringkasanDisiplinTotalHadir}',
                  const Color(0xFFF3F6F4),
                  _kTextDark,
                ),
                _teamStatChip(
                  'Telat: ${ov.ringkasanDisiplinTelat}',
                  ov.ringkasanDisiplinTelat > 0
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F6F4),
                  ov.ringkasanDisiplinTelat > 0
                      ? const Color(0xFF92400E)
                      : _kTextDim,
                ),
                _teamStatChip(
                  'Tanpa Ket.: ${ov.ringkasanDisiplinAlpha}',
                  ov.ringkasanDisiplinAlpha > 0
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFF3F6F4),
                  ov.ringkasanDisiplinAlpha > 0
                      ? const Color(0xFF991B1B)
                      : _kTextDim,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _behaviorFilterChip('Semua (${allItems.length})', 'semua'),
                const SizedBox(width: 6),
                _behaviorFilterChip(
                    'Perlu Perhatian ($seriousCount)', 'perlu_perhatian'),
                const SizedBox(width: 6),
                _behaviorFilterChip(
                    'Telat / Waspada ($lateOrWarnCount)', 'telat'),
                const SizedBox(width: 6),
                _behaviorFilterChip('Disiplin ($cleanCount)', 'disiplin'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 18, color: _kEmerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      allItems.isEmpty
                          ? 'Belum ada data karyawan & absensi pada periode ini.'
                          : 'Tidak ada karyawan dalam kategori filter ini.',
                      style: const TextStyle(fontSize: 12.5, color: _kTextDim),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < filtered.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildEmployeeTile(filtered[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _teamStatChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _behaviorFilterChip(String label, String key) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: _kPrimary,
      backgroundColor: const Color(0xFFF6F8F6),
      side: BorderSide(color: selected ? _kPrimary : _kBorder),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : _kTextDark,
      ),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _buildEmployeeTile(EmployeeBehaviorItem item) {
    final Color statusBg;
    final Color statusFg;
    final Color accentColor;
    final String statusLabel;

    switch (item.kategoriPerilaku) {
      case 'perlu_perhatian':
        statusBg = const Color(0xFFFEE2E2);
        statusFg = const Color(0xFF991B1B);
        accentColor = const Color(0xFFDC2626);
        statusLabel = item.telatCount >= 3 ? 'Sering Telat' : 'Perlu Perhatian';
        break;
      case 'waspada':
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFF92400E);
        accentColor = const Color(0xFFD97706);
        statusLabel = 'Waspada';
        break;
      case 'disiplin':
        statusBg = const Color(0xFFDCFCE7);
        statusFg = const Color(0xFF166534);
        accentColor = const Color(0xFF16A34A);
        statusLabel = 'Disiplin';
        break;
      default:
        statusBg = const Color(0xFFF3F4F6);
        statusFg = const Color(0xFF4B5563);
        accentColor = const Color(0xFF9CA3AF);
        statusLabel = 'Belum Ada Data';
        break;
    }

    final divCap = item.divisi.isEmpty
        ? 'Kasir'
        : '${item.divisi[0].toUpperCase()}${item.divisi.substring(1).toLowerCase()}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.kategoriPerilaku == 'perlu_perhatian'
            ? const Color(0xFFFFFBFB)
            : const Color(0xFFFAFBF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.kategoriPerilaku == 'perlu_perhatian'
              ? const Color(0xFFFECACA)
              : _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: accentColor.withValues(alpha: 0.14),
                child: Text(
                  item.nama.isNotEmpty ? item.nama[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),
                    Text(
                      divCap,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _kTextDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.ringkasanPerilaku,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: item.kategoriPerilaku == 'perlu_perhatian'
                  ? statusFg
                  : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniMetric(
                'Hadir ${item.totalHadir}/${item.totalShiftTerjadwal}',
                const Color(0xFFF3F4F6),
                const Color(0xFF374151),
              ),
              if (item.totalHadir > 0)
                _miniMetric(
                  'Tepat ${item.tingkatKetepatanPersen.toStringAsFixed(0)}%',
                  item.tingkatKetepatanPersen >= 85
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFFBEB),
                  item.tingkatKetepatanPersen >= 85
                      ? const Color(0xFF047857)
                      : const Color(0xFFB45309),
                ),
              if (item.telatCount > 0)
                _miniMetric(
                  'Telat ${item.telatCount}x (${item.totalMenitTelat} mnt)',
                  const Color(0xFFFEE2E2),
                  const Color(0xFFB91C1C),
                ),
              if (item.lupaAbsenPulangCount > 0)
                _miniMetric(
                  'Lupa pulang ${item.lupaAbsenPulangCount}x',
                  const Color(0xFFFFEDD5),
                  const Color(0xFFC2410C),
                ),
              if (item.tanpaKeteranganCount > 0)
                _miniMetric(
                  'Alpha ${item.tanpaKeteranganCount}x',
                  const Color(0xFFFEE2E2),
                  const Color(0xFF991B1B),
                ),
              if (item.izinTelatCount > 0)
                _miniMetric(
                  'Izin telat ${item.izinTelatCount}x',
                  const Color(0xFFF3F4F6),
                  const Color(0xFF4B5563),
                ),
              if (item.izinTidakMasukCount > 0)
                _miniMetric(
                  'Izin absen ${item.izinTidakMasukCount}x',
                  const Color(0xFFF3F4F6),
                  const Color(0xFF4B5563),
                ),
              if (item.tukarShiftCount > 0)
                _miniMetric(
                  'Tukar shift ${item.tukarShiftCount}x',
                  const Color(0xFFF3F4F6),
                  const Color(0xFF4B5563),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
