import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/stok_gudang_provider.dart';
import '../../providers/stok_models.dart';

/// Form Barang Masuk (restock gudang). 1 form = 1 header barang_masuk + banyak baris detail.
/// Aturan: tiap baris wajib punya bahan, jumlah (> 0), dan harga total (> 0).
class BarangMasukScreen extends StatefulWidget {
  const BarangMasukScreen({super.key});

  @override
  State<BarangMasukScreen> createState() => _BarangMasukScreenState();
}

/// State 1 baris form (controller dipegang di sini supaya tidak hilang saat rebuild).
class _RowState {
  Bahan? bahan;
  final kemasanC = TextEditingController();
  final eceranC = TextEditingController();
  final hargaC = TextEditingController();

  int get kemasan =>
      (bahan != null && !bahan!.punyaKemasan) ? 0 : (int.tryParse(kemasanC.text.trim()) ?? 0);
  double get eceran => double.tryParse(eceranC.text.trim().replaceAll(',', '.')) ?? 0;
  double get harga =>
      double.tryParse(hargaC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  double get totalSatuanKecil =>
      bahan == null ? 0 : kemasan * bahan!.isiPerKemasan + eceran;

  /// Harga per satuan kecil; null kalau belum bisa dihitung.
  double? get hargaPerSatuan =>
      (totalSatuanKecil > 0 && harga > 0) ? harga / totalSatuanKecil : null;

  String? errorBahan(bool tampil) => tampil && bahan == null ? 'Pilih bahan' : null;
  String? errorJumlah(bool tampil) =>
      tampil && bahan != null && totalSatuanKecil <= 0 ? 'Isi jumlah kemasan atau eceran' : null;
  String? errorHarga(bool tampil) =>
      tampil && harga <= 0 ? 'Harga total wajib diisi' : null;

  bool get valid => bahan != null && totalSatuanKecil > 0 && harga > 0;

  void dispose() {
    kemasanC.dispose();
    eceranC.dispose();
    hargaC.dispose();
  }
}

class _BarangMasukScreenState extends State<BarangMasukScreen> {
  final _rows = <_RowState>[_RowState()];
  final _keteranganC = TextEditingController();
  final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _tampilError = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _keteranganC.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _tampilError = true);
    if (_rows.any((r) => !r.valid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua baris yang masih merah')),
      );
      return;
    }

    final provider = context.read<StokGudangProvider>();
    final items = _rows
        .map((r) => BarangMasukItem(
      bahan: r.bahan!,
      kemasan: r.kemasan,
      eceran: r.eceran,
      hargaTotal: r.harga,
    ))
        .toList();

    final ok = await provider.submitBarangMasuk(
      items: items,
      keterangan: _keteranganC.text.trim().isEmpty ? null : _keteranganC.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan barang masuk. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StokGudangProvider>();
    final dipakai = _rows.map((r) => r.bahan?.id).whereType<String>().toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Barang Masuk')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < _rows.length; i++)
                _buildRowCard(i, provider.daftarBahan, dipakai),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_RowState())),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah bahan'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keteranganC,
                decoration: InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  hintText: 'Nama toko, no. nota, dll',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                : const Text('Simpan barang masuk'),
          ),
        ),
      ),
    );
  }

  Widget _buildRowCard(int index, List<Bahan> semuaBahan, Set<String> dipakai) {
    final row = _rows[index];
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Bahan yang sudah dipilih di baris lain disembunyikan, supaya tidak dobel.
    final pilihan = semuaBahan
        .where((b) => b.id == row.bahan?.id || !dipakai.contains(b.id))
        .toList();

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
                      errorText: row.errorBahan(_tampilError),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: pilihan
                        .map((b) => DropdownMenuItem(value: b.id, child: Text(b.nama)))
                        .toList(),
                    onChanged: (id) => setState(
                            () => row.bahan = semuaBahan.firstWhere((b) => b.id == id)),
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    tooltip: 'Hapus baris',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final removed = _rows[index];
                      setState(() => _rows.removeAt(index));
                      // Dispose setelah frame selesai, supaya TextField lama sudah dilepas.
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => removed.dispose());
                    },
                  ),
              ],
            ),
            if (row.bahan != null) ...[
              const SizedBox(height: 6),
              Text(
                row.bahan!.punyaKemasan
                    ? '1 kemasan = ${formatAngka(row.bahan!.isiPerKemasan)} ${row.bahan!.satuan}'
                    : 'Bahan ini tidak punya kemasan besar, isi eceran saja',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: row.kemasanC,
                    enabled: row.bahan?.punyaKemasan ?? true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Kemasan utuh',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: row.eceranC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Eceran${row.bahan != null ? ' (${row.bahan!.satuan})' : ''}',
                      errorText: row.errorJumlah(_tampilError),
                      errorMaxLines: 2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.hargaC,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Harga total baris ini',
                prefixText: 'Rp ',
                errorText: row.errorHarga(_tampilError),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (row.hargaPerSatuan != null) ...[
              const SizedBox(height: 10),
              Text(
                'Total ${formatAngka(row.totalSatuanKecil)} ${row.bahan!.satuan}'
                    '  •  ${_rupiah.format(row.hargaPerSatuan)} per ${row.bahan!.satuan}',
                style: text.bodyMedium?.copyWith(color: Theme.of(context).primaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}