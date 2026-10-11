import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/stok_gudang_provider.dart';
import '../../providers/stok_models.dart';

/// Form Barang Keluar: transfer gudang -> bar/kitchen.
/// Hanya mengurangi stok gudang + jadi bukti audit. Stok bar/kitchen diperbarui lewat opname.
class BarangKeluarScreen extends StatefulWidget {
  /// Titik awal yang terpilih. Nanti bisa diisi dari area_kerja shift aktif karyawan.
  final TitikStok titikAwal;
  const BarangKeluarScreen({super.key, this.titikAwal = TitikStok.bar});

  @override
  State<BarangKeluarScreen> createState() => _BarangKeluarScreenState();
}

class _RowState {
  Bahan? bahan;
  final jumlahC = TextEditingController();

  double get jumlah => double.tryParse(jumlahC.text.trim().replaceAll(',', '.')) ?? 0;

  void dispose() => jumlahC.dispose();
}

class _BarangKeluarScreenState extends State<BarangKeluarScreen> {
  final _rows = <_RowState>[_RowState()];
  late TitikStok _titik = widget.titikAwal;
  bool _tampilError = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  /// Pesan error untuk 1 baris, atau null kalau valid.
  String? _errorBaris(_RowState r, StokGudangProvider provider) {
    if (r.bahan == null) return 'Pilih bahan';
    if (r.jumlah <= 0) return 'Jumlah harus lebih dari 0';
    final tersedia = provider.stokUntuk(r.bahan!.id)?.totalSatuanKecil ?? 0;
    if (r.jumlah > tersedia) {
      return 'Melebihi stok gudang (${formatAngka(tersedia)} ${r.bahan!.satuan})';
    }
    return null;
  }

  Future<void> _simpan() async {
    final provider = context.read<StokGudangProvider>();
    setState(() => _tampilError = true);
    if (_rows.any((r) => _errorBaris(r, provider) != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua baris yang masih merah')),
      );
      return;
    }

    final ok = await provider.submitBarangKeluar(
      titik: _titik,
      items: _rows
          .map((r) => BarangKeluarItem(bahan: r.bahan!, jumlah: r.jumlah))
          .toList(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan barang keluar. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StokGudangProvider>();
    final primary = Theme.of(context).primaryColor;
    final dipakai = _rows.map((r) => r.bahan?.id).whereType<String>().toSet();
    // Hanya bahan yang masih ada stoknya di gudang.
    final tersedia = provider.daftarBahan
        .where((b) => (provider.stokUntuk(b.id)?.totalSatuanKecil ?? 0) > 0)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Barang Keluar')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Tujuan', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<TitikStok>(
                segments: TitikStok.values
                    .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                    .toList(),
                selected: {_titik},
                onSelectionChanged: (v) => setState(() => _titik = v.first),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ini hanya mencatat barang yang diambil dari gudang. '
                        'Stok bar/kitchen diperbarui lewat opname, bukan dari form ini.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _rows.length; i++)
                _buildRowCard(i, provider, tersedia, dipakai),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_RowState())),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah bahan'),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: provider.isSubmitting ? null : _simpan,
            child: provider.isSubmitting
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Catat pengambilan ke ${_titik.label}'),
          ),
        ),
      ),
    );
  }

  Widget _buildRowCard(
      int index, StokGudangProvider provider, List<Bahan> semua, Set<String> dipakai) {
    final row = _rows[index];
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pilihan =
        semua.where((b) => b.id == row.bahan?.id || !dipakai.contains(b.id)).toList();
    final stok = row.bahan == null ? null : provider.stokUntuk(row.bahan!.id);
    final error = _tampilError ? _errorBaris(row, provider) : null;
    final errorBahan = error == 'Pilih bahan' ? error : null;
    final errorJumlah = error == 'Pilih bahan' ? null : error;

    return Card(
      key: ObjectKey(row),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: row.bahan?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Bahan',
                      errorText: errorBahan,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: pilihan
                        .map((b) => DropdownMenuItem(value: b.id, child: Text(b.nama)))
                        .toList(),
                    onChanged: (id) =>
                        setState(() => row.bahan = semua.firstWhere((b) => b.id == id)),
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    tooltip: 'Hapus baris',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final removed = _rows[index];
                      setState(() => _rows.removeAt(index));
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => removed.dispose());
                    },
                  ),
              ],
            ),
            if (stok != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tersedia: ${formatStokGudang(stok)} '
                '(total ${formatAngka(stok.totalSatuanKecil)} ${stok.bahan.satuan})',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: row.jumlahC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Jumlah diambil',
                suffixText: row.bahan?.satuan,
                errorText: errorJumlah,
                errorMaxLines: 2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
