import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/on_duty_guard.dart';
import '../../../../core/widgets/page_refresh_scope.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/stok_gudang_provider.dart';
import '../../providers/stok_models.dart';
import '../widgets/stok_gudang_tile.dart';
import '../widgets/edit_stok_gudang_dialog.dart';
import 'barang_keluar_screen.dart';
import 'barang_masuk_screen.dart';
import 'rekap_barang_masuk_screen.dart';
import 'stok_titik_screen.dart';

/// Pembungkus: membuat provider khusus modul stok (tanpa perlu ubah main.dart).
/// Kalau nanti provider dipakai lintas layar (mis. opname), pindahkan ke MultiProvider.
class StokGudangScreen extends StatelessWidget {
  const StokGudangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OnDutyGuard(
      featureName: 'Stok Gudang & Ambil Barang',
      child: ChangeNotifierProvider(
        create: (ctx) =>
            StokGudangProvider(auth: ctx.read<AuthProvider>())..loadData(),
        child: const _StokGudangView(),
      ),
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
    final auth = context.read<AuthProvider>();
    final role = auth.role?.toLowerCase();
    final divisi = auth.divisi?.toLowerCase();
    final isLockedNonAdmin = role != 'admin' && (divisi == 'kitchen' || divisi == 'bar');
    final initialTitik = divisi == 'kitchen' ? TitikStok.kitchen : TitikStok.bar;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: BarangKeluarScreen(
            titikAwal: initialTitik,
            kunciTitik: isLockedNonAdmin,
          ),
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

    return PageRefreshRegistrar(
      onRefresh: p.loadData,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: buildStandaloneAppBar(
          context,
          title: 'Stok Gudang & Mutasi',
          onRefresh: p.loadData,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.bolehInputBarangMasuk)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: p,
                            child: const RekapBarangMasukScreen(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Rekap Masuk & Harga'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StokTitikScreen()),
                    ),
                    icon: const Icon(Icons.local_cafe_outlined, size: 18),
                    label: const Text('Lihat Stok Bar / Kitchen'),
                  ),
                ],
              ),
            ),
          if (p.hasPricingData)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Estimasi Nilai Persediaan Gudang (AVG)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(p.totalNilaiGudang.round()),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${p.items.length} Bahan · ${p.jumlahBahanDenganBom} di BOM',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: context.read<StokGudangProvider>().setQuery,
              decoration: InputDecoration(
                hintText: 'Cari bahan di gudang...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _areaFilterChip(context, p, 'semua', 'Semua'),
                  const SizedBox(width: 6),
                  _areaFilterChip(context, p, 'bar', 'Bar'),
                  const SizedBox(width: 6),
                  _areaFilterChip(context, p, 'kitchen', 'Kitchen'),
                  const SizedBox(width: 8),
                  FilterChip(
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
                      fontSize: 12.5,
                    ),
                  ),
                ],
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
      ),
    );
  }

  Widget _areaFilterChip(
      BuildContext context, StokGudangProvider p, String value, String label) {
    final selected = p.areaFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => p.setAreaFilter(value),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
        width: selected ? 1.4 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryColor : const Color(0xFF2D312E),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
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
            onEdit: p.bolehInputBarangMasuk
                ? () async {
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
                  }
                : null,
          );
        },
      ),
    );
  }
}