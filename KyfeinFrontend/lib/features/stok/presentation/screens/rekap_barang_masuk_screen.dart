import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/stok_gudang_provider.dart';
import '../widgets/rekap_barang_masuk_section.dart';

/// Layar riwayat & rekap barang masuk gudang beserta rincian harga pembelian.
/// Dibuka dari StokGudangScreen sehingga admin dapat meninjau nota masuk kapan saja.
class RekapBarangMasukScreen extends StatefulWidget {
  const RekapBarangMasukScreen({super.key});

  @override
  State<RekapBarangMasukScreen> createState() => _RekapBarangMasukScreenState();
}

class _RekapBarangMasukScreenState extends State<RekapBarangMasukScreen> {
  String _periode = 'semua'; // semua | hari_ini | 7_hari | bulan_ini

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    String? start;
    String? end;
    if (_periode == 'hari_ini') {
      start = fmt.format(now);
      end = start;
    } else if (_periode == '7_hari') {
      start = fmt.format(now.subtract(const Duration(days: 6)));
      end = fmt.format(now);
    } else if (_periode == 'bulan_ini') {
      final first = DateTime(now.year, now.month, 1);
      final last = DateTime(now.year, now.month + 1, 0);
      start = fmt.format(first);
      end = fmt.format(last);
    }

    await context.read<StokGudangProvider>().loadRekapMasuk(
          tanggalMulai: start,
          tanggalSelesai: end,
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StokGudangProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rekap Barang Masuk & Harga'),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final opt in const [
                          ('semua', 'Semua Riwayat'),
                          ('hari_ini', 'Hari Ini'),
                          ('7_hari', '7 Hari Terakhir'),
                          ('bulan_ini', 'Bulan Ini'),
                        ])
                          ChoiceChip(
                            label: Text(opt.$2),
                            selected: _periode == opt.$1,
                            onSelected: (_) {
                              setState(() => _periode = opt.$1);
                              _load();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    RekapBarangMasukSection(
                      rekap: p.rekapMasuk,
                      isLoading: p.isLoadingRekap,
                      emptyMessage:
                          'Belum ada pencatatan barang masuk dengan harga pada rentang ini.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

