import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/stok_models.dart';
import '../../providers/stok_opname_provider.dart';

/// Layar Stok Opname (awal / akhir shift) untuk 1 titik.
/// - hitung_manual : karyawan menghitung fisik tiap bahan (ada kalkulator hitungan).
/// - carry_forward : stok ditampilkan read-only, karyawan cukup konfirmasi terima.
class OpnameScreen extends StatelessWidget {
  final TitikStok titik;
  final TipeOpname tipe;

  /// Hanya dipakai saat provider masih mock. Setelah backend tersambung, metode ditentukan server.
  final MetodeOpname metodeMock;

  const OpnameScreen({
    super.key,
    required this.titik,
    required this.tipe,
    this.metodeMock = MetodeOpname.hitungManual,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StokOpnameProvider(auth: ctx.read<AuthProvider>())
        ..loadKonteks(titik: titik, tipe: tipe, metodeMock: metodeMock),
      child: const _OpnameView(),
    );
  }
}

double _num(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

/// 1 bagian hitungan: jumlah x (pengali opsional). Contoh: 6 x 1000 (6 kotak, isi 1000 ml).
class _Part {
  final jumlahC = TextEditingController();
  final pengaliC = TextEditingController();

  bool get kosong => jumlahC.text.trim().isEmpty;
  double get pengali => pengaliC.text.trim().isEmpty ? 1 : _num(pengaliC.text);
  double get subtotal => _num(jumlahC.text) * pengali;
  bool get pakaiPengali => pengaliC.text.trim().isNotEmpty;

  void dispose() {
    jumlahC.dispose();
    pengaliC.dispose();
  }
}

class _BahanState {
  final OpnameBahan item;
  final parts = <_Part>[_Part()];
  _BahanState(this.item);

  bool get terisi => parts.any((p) => !p.kosong);
  double get total => parts.fold(0.0, (sum, p) => sum + p.subtotal);

  /// Rumus ditampilkan hanya kalau hitungannya gabungan, mis. "600 + 6 × 1.000".
  String? get rumus {
    final isi = parts.where((p) => !p.kosong).toList();
    if (isi.length < 2 && !isi.any((p) => p.pakaiPengali)) return null;
    return isi
        .map((p) => p.pakaiPengali
            ? '${formatAngka(_num(p.jumlahC.text))} × ${formatAngka(p.pengali)}'
            : formatAngka(_num(p.jumlahC.text)))
        .join(' + ');
  }

  void dispose() {
    for (final p in parts) {
      p.dispose();
    }
  }
}

class _OpnameView extends StatefulWidget {
  const _OpnameView();

  @override
  State<_OpnameView> createState() => _OpnameViewState();
}

class _OpnameViewState extends State<_OpnameView> {
  final _states = <String, _BahanState>{};
  final _catatanC = TextEditingController();
  bool _tampilError = false;

  @override
  void dispose() {
    for (final s in _states.values) {
      s.dispose();
    }
    _catatanC.dispose();
    super.dispose();
  }

  void _siapkanState(OpnameKonteks k) {
    if (_states.isNotEmpty) return;
    for (final o in k.daftar) {
      _states[o.bahan.id] = _BahanState(o);
    }
  }

  Future<void> _simpan(OpnameKonteks k) async {
    final provider = context.read<StokOpnameProvider>();
    final carry = k.metode == MetodeOpname.carryForward;

    if (!carry) {
      setState(() => _tampilError = true);
      if (_states.values.any((s) => !s.terisi)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masih ada bahan yang belum dihitung')),
        );
        return;
      }
    }

    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(carry
            ? 'Konfirmasi terima stok ${k.titik.label}?'
            : 'Simpan opname ${k.tipe.label.toLowerCase()}?'),
        content: Text(
          k.tipe == TipeOpname.akhirShift
              ? 'Setelah disimpan, transaksi shift ini terkunci dan tidak bisa di-void lagi.'
              : carry
                  ? 'Stok awal dianggap sama dengan stok terakhir yang tertera.'
                  : 'Stok ${k.titik.label} akan diganti dengan hasil hitunganmu.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    final items = carry
        ? k.daftar
            .map((o) => OpnameItem(bahanId: o.bahan.id, jumlah: o.ekspektasi ?? 0))
            .toList()
        : _states.values
            .map((s) => OpnameItem(bahanId: s.item.bahan.id, jumlah: s.total))
            .toList();

    if (!carry) {
      for (final s in _states.values) {
        for (final p in s.parts) {
          if (p.pakaiPengali) provider.simpanPengali(s.item.bahan.id, p.pengali);
        }
      }
    }

    final ok = await provider.submitOpname(
      items: items,
      catatan: _catatanC.text.trim().isEmpty ? null : _catatanC.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan opname. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StokOpnameProvider>();
    final k = provider.konteks;

    if (k != null) _siapkanState(k);

    return Scaffold(
      appBar: AppBar(
        title: Text(k == null ? 'Stok Opname' : 'Opname ${k.tipe.label} • ${k.titik.label}'),
      ),
      body: _buildBody(provider, k),
      bottomNavigationBar: k == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: provider.isSubmitting ? null : () => _simpan(k),
                  child: provider.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(k.metode == MetodeOpname.carryForward
                          ? 'Konfirmasi terima'
                          : 'Simpan opname'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(StokOpnameProvider provider, OpnameKonteks? k) {
    if (provider.isLoading && k == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (k == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            provider.errorMessage.isEmpty ? 'Data opname tidak tersedia.' : provider.errorMessage,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final carry = k.metode == MetodeOpname.carryForward;
    final primary = Theme.of(context).primaryColor;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  Expanded(child: Text(_infoTeks(k))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (carry)
              for (final o in k.daftar) _buildCarryTile(o)
            else ...[
              for (final s in _states.values) _buildHitungCard(s, provider),
              const SizedBox(height: 4),
              TextField(
                controller: _catatanC,
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _infoTeks(OpnameKonteks k) {
    if (k.metode == MetodeOpname.carryForward) {
      return 'Stok awal = stok akhir shift sebelumnya + barang yang dibawa dari gudang. '
          'Cek sekilas, lalu konfirmasi.';
    }
    if (k.tipe == TipeOpname.akhirShift) {
      return 'Hitung semua bahan di ${k.titik.label}. Tulis 0 kalau habis. '
          'Setelah disimpan, shift dianggap selesai.';
    }
    return 'Hitung semua bahan di ${k.titik.label}. Tulis 0 kalau habis. '
        'Kamu bisa menjumlahkan beberapa hitungan, mis. 600 ml + 6 × 1000 ml.';
  }

  Widget _buildCarryTile(OpnameBahan o) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        title: Text(o.bahan.nama),
        trailing: Text(
          '${formatAngka(o.ekspektasi ?? 0)} ${o.bahan.satuan}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildHitungCard(_BahanState s, StokOpnameProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final satuan = s.item.bahan.satuan;
    final belumIsi = _tampilError && !s.terisi;

    return Card(
      key: ObjectKey(s),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: belumIsi ? cs.error : cs.outlineVariant,
          width: belumIsi ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.item.bahan.nama, style: text.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < s.parts.length; i++) _buildPartRow(s, i, provider),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final baru = _Part();
                  final terakhir = provider.pengaliTerakhir(s.item.bahan.id);
                  if (terakhir != null) baru.pengaliC.text = formatAngka(terakhir);
                  s.parts.add(baru);
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah hitungan'),
              ),
            ),
            if (s.terisi) ...[
              const Divider(),
              if (s.rumus != null)
                Text(s.rumus!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(
                'Total: ${formatAngka(s.total)} $satuan',
                style: text.titleSmall?.copyWith(color: Theme.of(context).primaryColor),
              ),
            ] else if (belumIsi)
              Text('Belum dihitung. Tulis 0 kalau habis.',
                  style: text.bodySmall?.copyWith(color: cs.error)),
          ],
        ),
      ),
    );
  }

  Widget _buildPartRow(_BahanState s, int i, StokOpnameProvider provider) {
    final part = s.parts[i];
    final satuan = s.item.bahan.satuan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: part.jumlahC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Jumlah',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Text('×'),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: part.pengaliC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Isi per unit',
                hintText: 'opsional',
                suffixText: satuan,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (s.parts.length > 1)
            IconButton(
              tooltip: 'Hapus hitungan',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                final removed = s.parts[i];
                setState(() => s.parts.removeAt(i));
                WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
              },
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
