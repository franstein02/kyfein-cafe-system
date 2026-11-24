import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/stok_models.dart';

final _idrFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _unitPriceFormat = NumberFormat('#,##0.##', 'id_ID');

String _fmtUnitRp(double v) => 'Rp ${_unitPriceFormat.format(v)}';
String _fmtRp(double v) => _idrFormat.format(v.round());

class StokGudangTile extends StatefulWidget {
  final StokGudang stok;
  final VoidCallback? onEdit;

  const StokGudangTile({super.key, required this.stok, this.onEdit});

  @override
  State<StokGudangTile> createState() => _StokGudangTileState();
}

class _StokGudangTileState extends State<StokGudangTile> {
  bool _showBom = false;

  @override
  Widget build(BuildContext context) {
    final stok = widget.stok;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final menipis = stok.menipis;
    final hasPricing = stok.hasPricing;
    final area = stok.bahan.area;
    final avgPerKemasan = stok.effectiveHargaPerKemasan;
    final bomList = stok.bomPemakaian;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: menipis ? cs.error : AppTheme.borderColor,
          width: menipis ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Nama Bahan + Area + Menipis + Tombol Edit ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            stok.bahan.nama,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1D1B),
                            ),
                          ),
                          _areaBadge(area),
                          if (menipis)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Menipis',
                                style: text.labelSmall?.copyWith(
                                  color: cs.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatStokGudang(stok),
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D312E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total ${formatAngka(stok.totalSatuanKecil)} ${stok.bahan.satuan}'
                        '${stok.bahan.punyaKemasan ? ' (1 kemasan = ${formatAngka(stok.bahan.isiPerKemasan)} ${stok.bahan.satuan})' : ''}',
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Stok',
                    color: AppTheme.primaryColor,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    onPressed: widget.onEdit,
                  ),
              ],
            ),

            // ── Harga AVG & Nilai Stok (Khusus Admin / Owner) ────────────────
            if (hasPricing) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    _priceMetric(
                      label: 'AVG / ${stok.bahan.satuan.isNotEmpty ? stok.bahan.satuan : 'unit'}',
                      value: _fmtUnitRp(stok.effectiveHargaRataRata),
                      valueColor: AppTheme.primaryColor,
                      isBold: true,
                    ),
                    if (avgPerKemasan != null) ...[
                      _verticalDivider(),
                      _priceMetric(
                        label: 'AVG / kemasan',
                        value: _fmtRp(avgPerKemasan),
                        valueColor: const Color(0xFF2D312E),
                      ),
                    ],
                    _verticalDivider(),
                    _priceMetric(
                      label: 'Nilai Stok',
                      value: _fmtRp(stok.effectiveNilaiPersediaan),
                      valueColor: const Color(0xFF1B4332),
                      isBold: true,
                    ),
                  ],
                ),
              ),

              // ── Pemakaian Per BOM (Resep Menu) ─────────────────────────────
              const SizedBox(height: 8),
              if (bomList.isEmpty)
                Row(
                  children: [
                    Icon(Icons.restaurant_menu_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Belum dipakai di resep BOM menu aktif',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _showBom = !_showBom),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _showBom
                          ? AppTheme.primaryColor.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showBom
                            ? AppTheme.primaryColor.withValues(alpha: 0.25)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Biaya & Takaran Per BOM (${bomList.length} Menu)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          _showBom
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showBom) ...[
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
                        for (int idx = 0; idx < bomList.length; idx++) ...[
                          if (idx > 0)
                            Divider(height: 12, color: Colors.grey.shade200),
                          _bomRow(bomList[idx], stok.bahan.satuan),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _areaBadge(String area) {
    final isBar = area == 'bar';
    final isKitchen = area == 'kitchen';
    final bg = isBar
        ? const Color(0xFFF1E9DE)
        : isKitchen
            ? const Color(0xFFFDE8E1)
            : Colors.grey.shade100;
    final fg = isBar
        ? const Color(0xFF7A4E2B)
        : isKitchen
            ? const Color(0xFFC0441C)
            : Colors.grey.shade700;
    final label = isBar ? 'BAR' : (isKitchen ? 'KITCHEN' : 'UMUM');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 28,
        color: AppTheme.borderColor,
        margin: const EdgeInsets.symmetric(horizontal: 6),
      );

  Widget _priceMetric({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bomRow(StokGudangBomItem bom, String satuan) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bom.kodeMenu.isNotEmpty
                    ? '${bom.kodeMenu} · ${bom.namaMenu}'
                    : bom.namaMenu,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D1B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Takaran: ${formatAngka(bom.jumlahTerpakai)} $satuan / porsi'
                '${bom.estimasiPorsi != null ? ' · Est. ±${bom.estimasiPorsi} porsi' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _fmtUnitRp(bom.biayaPerPorsi),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
            Text(
              '/ porsi',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
