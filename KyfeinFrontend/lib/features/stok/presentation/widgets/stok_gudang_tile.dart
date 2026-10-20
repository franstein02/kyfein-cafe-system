import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/stok_models.dart';

class StokGudangTile extends StatelessWidget {
  final StokGudang stok;
  final VoidCallback? onEdit;

  const StokGudangTile({super.key, required this.stok, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final menipis = stok.menipis;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: menipis ? cs.error : cs.outlineVariant,
          width: menipis ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stok.bahan.nama, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(formatStokGudang(stok), style: text.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Total ${formatAngka(stok.totalSatuanKecil)} ${stok.bahan.satuan}'
                      '${stok.bahan.punyaKemasan ? ' (1 kemasan = ${formatAngka(stok.bahan.isiPerKemasan)} ${stok.bahan.satuan})' : ''}',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (menipis) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Menipis',
                    style: text.labelMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Stok',
                color: AppTheme.primaryColor,
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}