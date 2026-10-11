import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/stok_models.dart';
import '../../providers/stok_titik_provider.dart';

/// Layar lihat stok Bar / Kitchen (read-only). Angka = hasil opname fisik terakhir.
class StokTitikScreen extends StatelessWidget {
  const StokTitikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StokTitikProvider(auth: ctx.read<AuthProvider>())..load(),
      child: const _StokTitikView(),
    );
  }
}

class _StokTitikView extends StatelessWidget {
  const _StokTitikView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StokTitikProvider>();
    final cs = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Bar & Kitchen')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SegmentedButton<TitikStok>(
                  segments: TitikStok.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                      .toList(),
                  selected: {p.titik},
                  onSelectionChanged: (v) =>
                      context.read<StokTitikProvider>().pilihTitik(v.first),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                        'Angka ini hasil hitung fisik opname terakhir, bukan stok real-time. '
                        'Barang yang diambil dari gudang baru tercatat di sini setelah opname berikutnya.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(context, p, cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, StokTitikProvider p, ColorScheme cs) {
    if (p.isLoading && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(p.errorMessage, textAlign: TextAlign.center),
        ),
      );
    }
    final waktu = DateFormat('dd/MM HH:mm');
    return RefreshIndicator(
      onRefresh: context.read<StokTitikProvider>().load,
      child: p.items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 100),
              Center(
                child: Text('Belum ada opname di ${p.titik.label}.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: p.items.length,
              itemBuilder: (_, i) {
                final s = p.items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: ListTile(
                    title: Text(s.bahan.nama),
                    subtitle: s.diperbaruiPada == null
                        ? null
                        : Text('Opname terakhir ${waktu.format(s.diperbaruiPada!)}'),
                    trailing: Text(
                      '${formatAngka(s.jumlah)} ${s.bahan.satuan}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
