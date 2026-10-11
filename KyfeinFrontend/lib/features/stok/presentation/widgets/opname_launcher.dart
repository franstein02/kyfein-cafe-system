import 'package:flutter/material.dart';
import '../../providers/stok_models.dart';
import '../screens/opname_screen.dart';

/// Titik opname dari area_kerja shift. 'kasir' tidak punya titik sendiri -> null.
TitikStok? titikDariArea(String areaKerja) {
  switch (areaKerja) {
    case 'bar':
      return TitikStok.bar;
    case 'kitchen':
      return TitikStok.kitchen;
    default:
      return null;
  }
}

/// Buka layar opname untuk shift aktif. Return true kalau opname berhasil disimpan.
/// Dipanggil dari dashboard (tombol opname) dan dari gerbang POS.
///
/// [areaKerja] sengaja berupa String (bukan ShiftAktif) supaya modul stok
/// tidak bergantung ke modul dashboard.
Future<bool> bukaOpname(
  BuildContext context, {
  required String areaKerja,
  required TipeOpname tipe,
  MetodeOpname metodeMock = MetodeOpname.hitungManual,
}) async {
  final titik = titikDariArea(areaKerja) ?? await _pilihTitik(context);
  if (titik == null || !context.mounted) return false;

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => OpnameScreen(titik: titik, tipe: tipe, metodeMock: metodeMock),
    ),
  );
  return saved == true;
}

Future<TitikStok?> _pilihTitik(BuildContext context) {
  return showDialog<TitikStok>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Opname untuk titik mana?'),
      children: [
        for (final t in TitikStok.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, t),
            child: Text(t.label),
          ),
      ],
    ),
  );
}

/// Layar pengganti POS selama opname awal shift belum disubmit.
class OpnameWajibView extends StatelessWidget {
  final String areaKerja;

  /// Dipanggil setelah opname awal berhasil disimpan (mis. refresh DashboardProvider).
  final VoidCallback onSelesai;

  const OpnameWajibView({super.key, required this.areaKerja, required this.onSelesai});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: primary),
                const SizedBox(height: 16),
                Text('Opname awal shift dulu', style: text.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Transaksi bisa dimulai setelah stok awal dihitung atau dikonfirmasi.',
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Mulai opname awal shift'),
                  onPressed: () async {
                    final ok = await bukaOpname(
                      context,
                      areaKerja: areaKerja,
                      tipe: TipeOpname.awalShift,
                    );
                    if (ok) onSelesai();
                  },
                ),
                if (Navigator.of(context).canPop())
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kembali'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
