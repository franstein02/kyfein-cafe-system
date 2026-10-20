import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/stok_gudang_provider.dart';
import '../widgets/stok_gudang_tile.dart';
import '../widgets/edit_stok_gudang_dialog.dart';
import 'barang_keluar_screen.dart';
import 'barang_masuk_screen.dart';
import 'stok_titik_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StokGudangProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gudang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_cafe_outlined),
            tooltip: 'Stok Bar / Kitchen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StokTitikScreen()),
            ),
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
                avatar: p.jumlahMenipis > 0
                    ? Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: p.hanyaMenipis
                            ? Colors.red.shade800
                            : Colors.red.shade600,
                      )
                    : null,
                label: Text('Menipis (${p.jumlahMenipis})'),
                selected: p.hanyaMenipis,
                onSelected: context.read<StokGudangProvider>().toggleMenipis,
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: p.jumlahMenipis > 0
                    ? Colors.red.shade50
                    : Theme.of(context).primaryColor.withValues(alpha: 0.15),
                side: BorderSide(
                  color: p.hanyaMenipis
                      ? (p.jumlahMenipis > 0
                          ? Colors.red.shade400
                          : Theme.of(context).primaryColor)
                      : (p.jumlahMenipis > 0
                          ? Colors.red.shade300
                          : Colors.grey.shade400),
                  width: p.hanyaMenipis ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: TextStyle(
                  color: p.hanyaMenipis
                      ? (p.jumlahMenipis > 0
                          ? Colors.red.shade800
                          : Theme.of(context).primaryColor)
                      : (p.jumlahMenipis > 0
                          ? Colors.red.shade700
                          : const Color(0xFF2D312E)),
                  fontWeight:
                      p.hanyaMenipis ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
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
        itemBuilder: (ctx, i) {
          final item = p.items[i];
          return StokGudangTile(
            stok: item,
            onEdit: () async {
              final updated = await EditStokGudangDialog.show(
                context,
                stok: item,
                provider: p,
              );
              if (updated == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stok ${item.bahan.nama} berhasil diperbarui'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}