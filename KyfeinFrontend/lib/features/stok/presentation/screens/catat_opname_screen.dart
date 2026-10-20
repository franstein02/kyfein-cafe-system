import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/catat_opname_provider.dart';
import '../../providers/stok_models.dart';
import 'stok_opname_hub_screen.dart';

class CatatOpnameScreen extends StatelessWidget {
  const CatatOpnameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CatatOpnameProvider(auth: ctx.read<AuthProvider>())..loadInitialData(),
      child: const _CatatOpnameView(),
    );
  }
}

class _CatatOpnameView extends StatefulWidget {
  const _CatatOpnameView();

  @override
  State<_CatatOpnameView> createState() => _CatatOpnameViewState();
}

class _CatatOpnameViewState extends State<_CatatOpnameView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final provider = context.read<CatatOpnameProvider>();
      final awalSaved = provider.isAwalSaved(provider.titik);
      if (_tabController.index == 1 && !awalSaved) {
        // Tab 2 tapped while Tab 1 not saved
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pencatatan Stok Akhir terkunci. Harap simpan Stok Awal ${provider.titik.label} terlebih dahulu.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF9E5C00),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatatOpnameProvider>();
    final awalSaved = provider.isAwalSaved(provider.titik);
    final akhirSaved = provider.isAkhirSaved(provider.titik);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Catat Opname',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan data',
            onPressed: provider.isLoading ? null : provider.loadInitialData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: Icon(
                    awalSaved ? Icons.check_circle_rounded : Icons.wb_sunny_rounded,
                    color: awalSaved ? Colors.green.shade700 : null,
                    size: 18,
                  ),
                  text: 'Stok Awal',
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: Icon(
                    akhirSaved
                        ? Icons.check_circle_rounded
                        : (awalSaved ? Icons.nights_stay_rounded : Icons.lock_rounded),
                    color: akhirSaved
                        ? Colors.green.shade700
                        : (!awalSaved ? Colors.amber.shade800 : null),
                    size: 18,
                  ),
                  text: 'Stok Akhir',
                ),
              ],
            ),
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Area Switcher Bar (Bar / Kitchen) ────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          const Text(
                            'Area Operasional:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2D312E)),
                          ),
                          const Spacer(),
                          // Choice chips for Titik
                          _areaChip(
                            context,
                            provider,
                            label: 'Bar',
                            icon: Icons.local_cafe_rounded,
                            titik: TitikStok.bar,
                          ),
                          const SizedBox(width: 8),
                          _areaChip(
                            context,
                            provider,
                            label: 'Kitchen',
                            icon: Icons.soup_kitchen_rounded,
                            titik: TitikStok.kitchen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Search Box Full Width
                      SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: provider.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Cari bahan ${provider.titik.label.toLowerCase()}...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery('');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            fillColor: Colors.grey.shade100,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // ── Tab Views ────────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: STOK AWAL
                      _TabStokAwalContent(
                        onNavigateToAkhir: () {
                          _tabController.animateTo(1);
                        },
                      ),

                      // TAB 2: STOK AKHIR (LOCKED IF TAB 1 NOT SAVED)
                      awalSaved
                          ? const _TabStokAkhirContent()
                          : _TabLockedView(
                              titik: provider.titik,
                              onBukaStokAwal: () {
                                _tabController.animateTo(0);
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _areaChip(
    BuildContext context,
    CatatOpnameProvider provider, {
    required String label,
    required IconData icon,
    required TitikStok titik,
  }) {
    final isSelected = provider.titik == titik;
    return InkWell(
      onTap: () {
        provider.setTitik(titik);
        _searchController.clear();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2D312E),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LOCKED STATE VIEW FOR TAB 2 (STOK AKHIR)
// ═════════════════════════════════════════════════════════════════════════════
class _TabLockedView extends StatelessWidget {
  final TitikStok titik;
  final VoidCallback onBukaStokAwal;

  const _TabLockedView({required this.titik, required this.onBukaStokAwal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.amber.shade200, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Pencatatan Stok Akhir Terkunci',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D312E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pencatatan Stok Akhir untuk area ${titik.label} hanya dapat dibuka setelah Stok Awal selesai dihitung dan disimpan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onBukaStokAwal,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Catat Stok Awal Sekarang',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 CONTENT: STOK AWAL
// ═════════════════════════════════════════════════════════════════════════════
class _TabStokAwalContent extends StatelessWidget {
  final VoidCallback onNavigateToAkhir;

  const _TabStokAwalContent({required this.onNavigateToAkhir});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatatOpnameProvider>();
    final isSaved = provider.isAwalSaved(provider.titik);
    final isEditing = provider.isEditing(provider.titik, TipeOpname.awalShift);
    final savedTime = provider.savedTime(provider.titik, TipeOpname.awalShift);
    final savedCounts = provider.savedResults(provider.titik, TipeOpname.awalShift);
    final catatan = provider.getCatatan(provider.titik, TipeOpname.awalShift);

    if (isSaved && !isEditing) {
      return _SavedSuccessCard(
        tipe: TipeOpname.awalShift,
        titik: provider.titik,
        waktu: savedTime,
        savedCounts: savedCounts,
        allBahan: provider.allBahan,
        catatan: catatan,
        onLanjut: onNavigateToAkhir,
        onEdit: () => provider.mulaiEdit(provider.titik, TipeOpname.awalShift),
      );
    }

    return _OpnameFormList(
      tipe: TipeOpname.awalShift,
      titik: provider.titik,
      isEditing: isEditing,
      onBatalEdit: isEditing ? () => provider.batalEdit(provider.titik, TipeOpname.awalShift) : null,
      onSuccessSaved: onNavigateToAkhir,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 CONTENT: STOK AKHIR (WHEN UNLOCKED)
// ═════════════════════════════════════════════════════════════════════════════
class _TabStokAkhirContent extends StatelessWidget {
  const _TabStokAkhirContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatatOpnameProvider>();
    final isSaved = provider.isAkhirSaved(provider.titik);
    final isEditing = provider.isEditing(provider.titik, TipeOpname.akhirShift);
    final savedTime = provider.savedTime(provider.titik, TipeOpname.akhirShift);
    final savedCounts = provider.savedResults(provider.titik, TipeOpname.akhirShift);
    final catatan = provider.getCatatan(provider.titik, TipeOpname.akhirShift);

    if (isSaved && !isEditing) {
      return _SavedSuccessCard(
        tipe: TipeOpname.akhirShift,
        titik: provider.titik,
        waktu: savedTime,
        savedCounts: savedCounts,
        allBahan: provider.allBahan,
        catatan: catatan,
        onLanjut: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StokOpnameHubScreen()),
          );
        },
        onEdit: () => provider.mulaiEdit(provider.titik, TipeOpname.akhirShift),
      );
    }

    return _OpnameFormList(
      tipe: TipeOpname.akhirShift,
      titik: provider.titik,
      isEditing: isEditing,
      onBatalEdit: isEditing ? () => provider.batalEdit(provider.titik, TipeOpname.akhirShift) : null,
      onSuccessSaved: () {
        // Feedback shown in form
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUCCESS BANNER & DETAILS WHEN OPNAME IS SAVED
// ═════════════════════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════════════════════
// SUCCESS BANNER & DETAILS WHEN OPNAME IS SAVED
// ═════════════════════════════════════════════════════════════════════════════
class _SavedSuccessCard extends StatelessWidget {
  final TipeOpname tipe;
  final TitikStok titik;
  final DateTime? waktu;
  final Map<String, double>? savedCounts;
  final List<Bahan> allBahan;
  final String? catatan;
  final VoidCallback onLanjut;
  final VoidCallback onEdit;

  const _SavedSuccessCard({
    required this.tipe,
    required this.titik,
    required this.waktu,
    required this.savedCounts,
    required this.allBahan,
    this.catatan,
    required this.onLanjut,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isAwal = tipe == TipeOpname.awalShift;
    final timeStr = waktu != null ? DateFormat('HH:mm').format(waktu!) : '-';
    final dateStr = waktu != null ? DateFormat('d MMMM yyyy', 'id_ID').format(waktu!) : 'Hari ini';

    // Ambil list bahan yang memiliki hitungan tersimpan
    final Map<String, double> counts = savedCounts ?? {};
    final savedEntries = counts.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 1. Header Banner Status Tersimpan ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 36, color: Colors.green.shade700),
              ),
              const SizedBox(height: 14),
              Text(
                'Stok ${isAwal ? "Awal" : "Akhir"} ${titik.label} Tersimpan',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Tercatat pada $dateStr pukul $timeStr WIB',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isAwal ? const Color(0xFFF1F7F2) : const Color(0xFFEBF3EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAwal ? Icons.lock_open_rounded : Icons.analytics_rounded,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isAwal
                            ? 'Pencatatan Stok Akhir kini telah TERBUKA dan siap dihitung di akhir shift.'
                            : 'Opname shift ${titik.label} hari ini lengkap dan telah terkunci untuk audit pemakaian BOM POS.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1B4332), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D312E),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.primaryColor),
                    label: Text(
                      'Edit / Revisi ${isAwal ? "Awal" : "Akhir"}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onLanjut,
                      icon: Icon(isAwal ? Icons.arrow_forward_rounded : Icons.fact_check_rounded, size: 18),
                      label: Text(
                        isAwal ? 'Ke Stok Akhir →' : 'Lihat Rekap Opname',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 2. Card Daftar Rincian Bahan yang Tersimpan ─────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, size: 18, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rincian Stok ${isAwal ? "Awal" : "Akhir"} Tercatat',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          'Data fisik aktual tersimpan di sistem',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '${savedEntries.length} Bahan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 8),

              if (savedEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada rincian bahan yang tercatat',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: savedEntries.length,
                  separatorBuilder: (_, __) => Divider(height: 12, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final entry = savedEntries[index];
                    final bId = entry.key;
                    final jumlah = entry.value;

                    Bahan? bahan;
                    try {
                      bahan = allBahan.firstWhere((b) => b.id == bId);
                    } catch (_) {
                      bahan = Bahan(id: bId, nama: bId, satuan: 'satuan', isiPerKemasan: 1, stokMinimum: 0);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bahan.nama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF2D312E),
                                  ),
                                ),
                                Text(
                                  'Satuan: ${bahan.satuan}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC8E6C9)),
                            ),
                            child: Text(
                              '${formatAngka(jumlah)} ${bahan.satuan}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF1B4332),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              if (catatan != null && catatan!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan: $catatan',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tombol Edit di bagian bawah list
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_note_rounded, size: 20),
          label: Text(
            'Edit / Revisi Data Stok ${isAwal ? "Awal" : "Akhir"}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHYSICAL COUNT FORM LIST FOR BAHAN
// ═════════════════════════════════════════════════════════════════════════════
class _OpnameFormList extends StatefulWidget {
  final TipeOpname tipe;
  final TitikStok titik;
  final bool isEditing;
  final VoidCallback? onBatalEdit;
  final VoidCallback onSuccessSaved;

  const _OpnameFormList({
    required this.tipe,
    required this.titik,
    this.isEditing = false,
    this.onBatalEdit,
    required this.onSuccessSaved,
  });

  @override
  State<_OpnameFormList> createState() => _OpnameFormListState();
}

class _OpnameFormListState extends State<_OpnameFormList> {
  final TextEditingController _catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<CatatOpnameProvider>();
    _catatanController.text = provider.getCatatan(widget.titik, widget.tipe);
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _handleSimpan(CatatOpnameProvider provider) async {
    final isAwal = widget.tipe == TipeOpname.awalShift;
    final bahanList = provider.filteredBahan;
    final terisiCount = bahanList.where((b) {
      final s = provider.getFormState(widget.titik, widget.tipe, b);
      return s.isFilled;
    }).length;

    if (terisiCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap masukkan hitungan fisik minimal untuk 1 bahan'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Simpan Stok ${isAwal ? "Awal" : "Akhir"} ${widget.titik.label}?'),
        content: Text(
          isAwal
              ? 'Stok awal akan disimpan sebagai baseline pemakaian harian ${widget.titik.label}. Tab Stok Akhir akan terbuka setelah disimpan.'
              : 'Setelah stok akhir disimpan, opname shift ${widget.titik.label} akan terkunci dan dibandingkan dengan pemakaian BOM penjualan POS.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    provider.setCatatan(widget.titik, widget.tipe, _catatanController.text);
    final ok = await provider.simpanOpname(
      titik: widget.titik,
      tipe: widget.tipe,
      catatan: _catatanController.text,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${isAwal ? "Awal" : "Akhir"} ${widget.titik.label} berhasil disimpan!'),
          backgroundColor: Colors.green.shade800,
        ),
      );

      if (isAwal) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            title: const Text('Stok Awal Berhasil Disimpan'),
            content: Text(
              'Pencatatan Stok Awal ${widget.titik.label} berhasil disimpan. Tab Stok Akhir kini telah terbuka dan dapat Anda isi saat shift selesai.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tetap di Sini'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onSuccessSaved();
                },
                child: const Text('Buka Stok Akhir →'),
              ),
            ],
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage.isNotEmpty ? provider.errorMessage : 'Gagal menyimpan opname'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatatOpnameProvider>();
    final isAwal = widget.tipe == TipeOpname.awalShift;
    final bahanList = provider.filteredBahan;

    final terisiCount = bahanList.where((b) {
      final s = provider.getFormState(widget.titik, widget.tipe, b);
      return s.isFilled;
    }).length;

    return Column(
      children: [
        if (widget.isEditing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFFF8E7),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFFB78103)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Edit / Koreksi Stok ${isAwal ? "Awal" : "Akhir"}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF7A5600)),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Nilai sebelumnya telah dimuat. Anda dapat mengubah bahan yang diinginkan lalu simpan.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF7A5600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          // Top instruction bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isAwal ? const Color(0xFFF1F7F2) : const Color(0xFFEBF3EF),
            child: Row(
              children: [
                Icon(
                  isAwal ? Icons.info_outline_rounded : Icons.fact_check_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAwal
                        ? 'Hitung fisik bahan di area ${widget.titik.label} sebelum memulai operasional shift.'
                        : 'Hitung fisik sisa bahan di area ${widget.titik.label} untuk audit pemakaian BOM.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1B4332), fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '$terisiCount/${bahanList.length} Bahan',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),

        // List of Bahan Cards
        Expanded(
          child: bahanList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.titik == TitikStok.kitchen ? Icons.soup_kitchen_outlined : Icons.inventory_2_outlined,
                          size: 52,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.titik == TitikStok.kitchen
                              ? 'Belum ada bahan untuk area Kitchen'
                              : 'Tidak ada bahan untuk area ${widget.titik.label}',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.titik == TitikStok.kitchen
                              ? 'Seluruh bahan operasional kafe saat ini berada di area Bar.'
                              : 'Coba ubah kata kunci pencarian.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: bahanList.length + 1,
                  itemBuilder: (context, index) {
                    if (index == bahanList.length) {
                      // Catatan field at the end of the list
                      return Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Catatan Opname (Opsional):',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _catatanController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Misal: susu tumpah 100ml, sirup retur...',
                                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final bahan = bahanList[index];
                    final formState = provider.getFormState(widget.titik, widget.tipe, bahan);

                    return _BahanCountCard(
                      key: ValueKey('${widget.titik.apiValue}_${widget.tipe.apiValue}_${bahan.id}'),
                      bahan: bahan,
                      formState: formState,
                      onChanged: () => setState(() {}),
                    );
                  },
                ),
        ),

        // Bottom Fixed Submit Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$terisiCount dari ${bahanList.length} Bahan',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      terisiCount == bahanList.length ? 'Semua Terhitung' : 'Siap Disimpan',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                if (widget.isEditing && widget.onBatalEdit != null) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: widget.onBatalEdit,
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (provider.isSubmitting || bahanList.isEmpty) ? null : () => _handleSimpan(provider),
                  icon: provider.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    widget.isEditing
                        ? 'Simpan Perubahan'
                        : (isAwal ? 'Simpan Stok Awal' : 'Simpan Stok Akhir'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MULTI-PART CALCULATOR CARD FOR EACH MATERIAL
// ═════════════════════════════════════════════════════════════════════════════
class _BahanCountCard extends StatelessWidget {
  final Bahan bahan;
  final OpnameBahanFormState formState;
  final VoidCallback onChanged;

  const _BahanCountCard({
    super.key,
    required this.bahan,
    required this.formState,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = formState.isFilled;
    final total = formState.total;
    final formula = formState.formula;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFilled ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: isFilled ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name, unit badge, live total
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bahan.nama,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Satuan: ${bahan.satuan}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (bahan.punyaKemasan) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• Kemasan: ${formatAngka(bahan.isiPerKemasan)} ${bahan.satuan}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Live Total Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFilled ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isFilled ? formatAngka(total) : '0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isFilled ? AppTheme.primaryColor : Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        bahan.satuan,
                        style: TextStyle(fontSize: 10, color: isFilled ? AppTheme.primaryColor : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Calculator Parts (Rows of Jumlah x Pengali)
            ...List.generate(formState.parts.length, (i) {
              final part = formState.parts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    // Input Jumlah
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: part.jumlahC,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => onChanged(),
                          decoration: InputDecoration(
                            labelText: i == 0 ? 'Jumlah Kemasan / Satuan' : 'Jumlah',
                            labelStyle: const TextStyle(fontSize: 11),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('×', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(width: 6),
                    // Input Pengali
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: part.pengaliC,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => onChanged(),
                          decoration: InputDecoration(
                            labelText: 'Isi (pengali)',
                            labelStyle: const TextStyle(fontSize: 11),
                            hintText: '1',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      bahan.satuan,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    // Delete button if more than 1 part
                    if (formState.parts.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        onPressed: () {
                          formState.removePart(i);
                          onChanged();
                        },
                      ),
                  ],
                ),
              );
            }),

            // Add Multiplier / Extra Part Button & Formula
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    formState.addPart(pengali: 1);
                    onChanged();
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Tambah Bagian/Eceran (+)', style: TextStyle(fontSize: 11)),
                ),
                const Spacer(),
                if (formula != null)
                  Expanded(
                    child: Text(
                      formula,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
