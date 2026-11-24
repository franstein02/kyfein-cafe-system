import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/stok_models.dart';

/// Kartu/seksi rekap transaksi barang masuk gudang beserta rincian harga per item,
/// harga per kemasan/satuan kecil, dan perbandingan terhadap harga rata-rata (AVG) terkini.
class RekapBarangMasukSection extends StatefulWidget {
  final BarangMasukRekapResponse? rekap;
  final bool isLoading;
  final String emptyMessage;
  final VoidCallback? onShowBulanIni;

  const RekapBarangMasukSection({
    super.key,
    required this.rekap,
    this.isLoading = false,
    this.emptyMessage = 'Belum ada pencatatan barang masuk pada periode ini.',
    this.onShowBulanIni,
  });

  @override
  State<RekapBarangMasukSection> createState() =>
      _RekapBarangMasukSectionState();
}

class _RekapBarangMasukSectionState extends State<RekapBarangMasukSection> {
  String _areaFilter = 'semua'; // semua | bar | kitchen
  String _searchQuery = '';

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _unitFmt = NumberFormat('#,##0.##', 'id_ID');

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    try {
      return DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(local);
    } catch (_) {
      return DateFormat('dd MMM yyyy • HH:mm').format(local);
    }
  }

  List<_FilteredBatch> _filterBatches(List<BarangMasukRekapItem> items) {
    final q = _searchQuery.trim().toLowerCase();
    final res = <_FilteredBatch>[];
    for (final batch in items) {
      final catatanCocok =
          q.isEmpty || (batch.catatan ?? '').toLowerCase().contains(q);
      final filteredDetails = batch.details.where((d) {
        if (_areaFilter != 'semua' &&
            d.area != 'semua' &&
            d.area != _areaFilter) {
          return false;
        }
        if (q.isNotEmpty && !catatanCocok) {
          return d.namaBahan.toLowerCase().contains(q);
        }
        return true;
      }).toList();

      if (filteredDetails.isEmpty) continue;
      final nilai = filteredDetails.fold<double>(
        0.0,
        (acc, d) => acc + d.hargaTotal,
      );
      res.add(
        _FilteredBatch(
          batch: batch,
          details: filteredDetails,
          filteredTotalNilai: nilai,
        ),
      );
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final rawItems = widget.rekap?.items ?? const <BarangMasukRekapItem>[];
    final filteredBatches = _filterBatches(rawItems);
    final totalItemFiltered = filteredBatches.fold<int>(
      0,
      (acc, b) => acc + b.details.length,
    );
    final totalNilaiFiltered = filteredBatches.fold<double>(
      0.0,
      (acc, b) => acc + b.filteredTotalNilai,
    );

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
                Icons.receipt_long_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rekap Barang Masuk & Harga',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Summary totals bar (full-width 2-column symmetric strip)
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
                  child: _summaryMetric(
                    'Nota Masuk',
                    '${filteredBatches.length} Nota · $totalItemFiltered Item',
                    AppTheme.textColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFE3E9E5),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _summaryMetric(
                    'Total Pembelian',
                    _currency.format(totalNilaiFiltered),
                    AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Area filter chips & search
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final opt in const [
                ('semua', 'Semua Area'),
                ('bar', 'Bar'),
                ('kitchen', 'Kitchen'),
              ])
                ChoiceChip(
                  label: Text(opt.$2),
                  selected: _areaFilter == opt.$1,
                  onSelected: (_) => setState(() => _areaFilter = opt.$1),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari bahan atau catatan nota...',
              prefixIcon: const Icon(Icons.search, size: 19),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Divider(height: 24),

          if (widget.isLoading && rawItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredBatches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rawItems.isEmpty
                        ? widget.emptyMessage
                        : 'Tidak ada item barang masuk yang cocok dengan filter.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (rawItems.isEmpty && widget.onShowBulanIni != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: widget.onShowBulanIni,
                      icon: const Icon(Icons.calendar_month_outlined, size: 17),
                      label: const Text('Tampilkan Bulan Ini'),
                    ),
                  ],
                ],
              ),
            )
          else
            ...List.generate(
              filteredBatches.length,
              (idx) => _buildBatchCard(filteredBatches[idx], idx == 0),
            ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchCard(_FilteredBatch fb, bool expandDefault) {
    final batch = fb.batch;
    final catatan = (batch.catatan != null && batch.catatan!.trim().isNotEmpty)
        ? batch.catatan!.trim()
        : 'Barang masuk gudang';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFAFBF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: expandDefault,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              catatan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _formatDateTime(batch.waktu),
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Oleh: ${batch.namaKaryawan}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${fb.details.length} item • ${_currency.format(fb.filteredTotalNilai)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              const Divider(height: 12),
              ...fb.details.map(_buildDetailRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BarangMasukRekapDetail d) {
    final qtyParts = <String>[];
    if (d.jumlahKemasanBesar > 0) {
      qtyParts.add('${d.jumlahKemasanBesar} kemasan');
    }
    if (d.jumlahSatuanKecil > 0) {
      qtyParts.add('${formatAngka(d.jumlahSatuanKecil)} ${d.satuan}');
    }
    final qtyLabel = qtyParts.isEmpty
        ? '${_unitFmt.format(d.totalSatuanKecil)} ${d.satuan}'
        : '${qtyParts.join(' + ')} (Total ${_unitFmt.format(d.totalSatuanKecil)} ${d.satuan})';

    final diff = d.selisihVsAvg;
    final bool naik = diff != null && diff > 0;
    final bool turun = diff != null && diff < 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      d.namaBahan,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: d.area == 'kitchen'
                            ? Colors.orange.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.area.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: d.area == 'kitchen'
                              ? Colors.orange.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currency.format(d.hargaTotal),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Masuk: $qtyLabel',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (d.hargaPerKemasan != null)
                Text(
                  'Harga/kemasan: ${_currency.format(d.hargaPerKemasan)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              Text(
                'Harga/${d.satuan}: Rp ${_unitFmt.format(d.hargaPerSatuanKecil)}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
              ),
              Text(
                'AVG skrg: Rp ${_unitFmt.format(d.hargaRataRataSaatIni)}/${d.satuan}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              if (diff != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: naik
                        ? Colors.red.shade50
                        : turun
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        naik
                            ? Icons.trending_up_rounded
                            : turun
                                ? Icons.trending_down_rounded
                                : Icons.horizontal_rule_rounded,
                        size: 13,
                        color: naik
                            ? Colors.red.shade700
                            : turun
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          naik
                              ? 'Naik +Rp ${_unitFmt.format(diff)}/${d.satuan}'
                              : turun
                                  ? 'Turun -Rp ${_unitFmt.format(diff.abs())}/${d.satuan}'
                                  : 'Stabil (= AVG)',
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
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilteredBatch {
  final BarangMasukRekapItem batch;
  final List<BarangMasukRekapDetail> details;
  final double filteredTotalNilai;

  const _FilteredBatch({
    required this.batch,
    required this.details,
    required this.filteredTotalNilai,
  });
}

