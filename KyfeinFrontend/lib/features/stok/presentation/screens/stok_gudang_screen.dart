import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/stok_gudang_provider.dart';
import '../widgets/stok_gudang_tile.dart';
import 'barang_keluar_screen.dart';
import 'barang_masuk_screen.dart';
import 'opname_screen.dart';
import 'stok_titik_screen.dart';
import '../../providers/stok_models.dart';

/// Pembungkus: membuat provider khusus modul stok (tanpa perlu ubah main.dart).
/// Kalau nanti provider dipakai lintas layar (mis. opname), pindahkan ke MultiProvider.
class StokGudangScreen extends StatelessWidget {
  const StokGudangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
      StokGudangProvider(auth: ctx.read<AuthProvider>())..loadData(),
      child: const _StokGudangView(),
    );
  }
}

class _StokGudangView extends StatelessWidget {
  const _StokGudangView();

  Future<void> _bukaBarangMasuk(BuildContext context) async {
    final provider = context.read<StokGudangProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const BarangMasukScreen(),
        ),
      ),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Barang masuk tersimpan')));
    }
  }

  Future<void> _bukaBarangKeluar(BuildContext context) async {
    final provider = context.read<StokGudangProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const BarangKeluarScreen(),
        ),
      ),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Barang keluar tersimpan')));
    }
  }

  /// SEMENTARA untuk uji layar opname. Nanti dipicu otomatis dari alur shift (Langkah 7).
  Future<void> _bukaOpname(
      BuildContext context, TipeOpname tipe, MetodeOpname metode) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OpnameScreen(titik: TitikStok.bar, tipe: tipe, metodeMock: metode),
      ),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Opname tersimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StokGudangProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Gudang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_cafe_outlined),
            tooltip: 'Stok Bar / Kitchen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StokTitikScreen()),
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Uji opname (sementara)',
            onSelected: (v) {
              if (v == 0) _bukaOpname(context, TipeOpname.awalShift, MetodeOpname.hitungManual);
              if (v == 1) _bukaOpname(context, TipeOpname.awalShift, MetodeOpname.carryForward);
              if (v == 2) _bukaOpname(context, TipeOpname.akhirShift, MetodeOpname.hitungManual);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Awal shift - hitung manual')),
              PopupMenuItem(value: 1, child: Text('Awal shift - carry forward')),
              PopupMenuItem(value: 2, child: Text('Akhir shift')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: context.read<StokGudangProvider>().setQuery,
              decoration: InputDecoration(
                hintText: 'Cari bahan',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text('Menipis (${p.jumlahMenipis})'),
                selected: p.hanyaMenipis,
                onSelected: context.read<StokGudangProvider>().toggleMenipis,
              ),
            ),
          ),
          Expanded(child: _buildBody(context, p)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (p.bolehInputBarangMasuk) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: p.daftarBahan.isEmpty ? null : () => _bukaBarangMasuk(context),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Barang masuk'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: p.daftarBahan.isEmpty ? null : () => _bukaBarangKeluar(context),
                  icon: const Icon(Icons.outbox_outlined),
                  label: const Text('Barang keluar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, StokGudangProvider p) {
    if (p.isLoading && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.errorMessage.isNotEmpty) {
      return Center(child: Text(p.errorMessage, textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: context.read<StokGudangProvider>().loadData,
      child: p.items.isEmpty
          ? ListView(children: const [
        SizedBox(height: 120),
        Center(child: Text('Tidak ada bahan yang cocok.')),
      ])
          : ListView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: p.items.length,
        itemBuilder: (_, i) => StokGudangTile(stok: p.items[i]),
      ),
    );
  }
}