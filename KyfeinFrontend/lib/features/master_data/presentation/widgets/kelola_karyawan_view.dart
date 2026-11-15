import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/master_data_provider.dart';

class KelolaKaryawanView extends StatefulWidget {
  final bool showHeader;
  const KelolaKaryawanView({super.key, this.showHeader = false});

  @override
  State<KelolaKaryawanView> createState() => _KelolaKaryawanViewState();
}

class _KelolaKaryawanViewState extends State<KelolaKaryawanView> {
  String _selectedFilter = 'semua';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MasterDataProvider>();
      if (widget.showHeader || provider.karyawanList.isEmpty) {
        provider.loadData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  _DivisiVisual _divisiVisual(String divisi) {
    switch (divisi) {
      case 'kitchen':
        return const _DivisiVisual(
          label: 'Kitchen',
          icon: Icons.restaurant_rounded,
          bgColor: Color(0xFFFFEDD5),
          fgColor: Color(0xFF9A3412),
          accessSummary: 'Fokus akses: KDS Kitchen, Stok & Opname Kitchen, Jadwal & Absensi',
        );
      case 'bar':
        return const _DivisiVisual(
          label: 'Bar / Barista',
          icon: Icons.local_cafe_rounded,
          bgColor: Color(0xFFFEF3C7),
          fgColor: Color(0xFF92400E),
          accessSummary: 'Fokus akses: KDS Bar, Stok & Opname Bar, Jadwal & Absensi',
        );
      default:
        return const _DivisiVisual(
          label: 'Kasir',
          icon: Icons.point_of_sale_rounded,
          bgColor: Color(0xFFE8F5EE),
          fgColor: Color(0xFF1B4332),
          accessSummary: 'Fokus akses: Kasir POS, Riwayat Transaksi, Jadwal & Absensi',
        );
    }
  }

  List<MasterKaryawan> _filterList(List<MasterKaryawan> all) {
    final karyawanOnly = all.where((k) => k.role != 'admin').toList();
    return karyawanOnly.where((k) {
      final matchesFilter = switch (_selectedFilter) {
        'kasir' => k.effectiveDivisi == 'kasir' && k.statusAktif,
        'bar' => k.effectiveDivisi == 'bar' && k.statusAktif,
        'kitchen' => k.effectiveDivisi == 'kitchen' && k.statusAktif,
        'nonaktif' => !k.statusAktif,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return k.nama.toLowerCase().contains(q) ||
          k.email.toLowerCase().contains(q) ||
          (k.nomorHp ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MasterDataProvider>();
    final allKaryawan = provider.karyawanList.where((k) => k.role != 'admin').toList();
    final filtered = _filterList(provider.karyawanList);

    final kasirCount = allKaryawan.where((k) => k.effectiveDivisi == 'kasir' && k.statusAktif).length;
    final barCount = allKaryawan.where((k) => k.effectiveDivisi == 'bar' && k.statusAktif).length;
    final kitchenCount = allKaryawan.where((k) => k.effectiveDivisi == 'kitchen' && k.statusAktif).length;
    final nonaktifCount = allKaryawan.where((k) => !k.statusAktif).length;

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          if (widget.showHeader) _buildStandaloneHeader(provider),
          Expanded(
            child: provider.isLoading && allKaryawan.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.loadData,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          children: [
                            if (!widget.showHeader) ...[
                              _buildInlineAddBanner(provider),
                              const SizedBox(height: 16),
                            ],
                            _buildFilterCard(
                              total: allKaryawan.length,
                              kasirCount: kasirCount,
                              barCount: barCount,
                              kitchenCount: kitchenCount,
                              nonaktifCount: nonaktifCount,
                            ),
                            const SizedBox(height: 16),
                            if (filtered.isEmpty)
                              _buildEmptyState(allKaryawan.isEmpty, provider)
                            else
                              ...filtered.map((k) => _buildKaryawanCard(k, provider)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandaloneHeader(MasterDataProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelola Karyawan',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Buat, edit, dan atur divisi akun karyawan (Kasir, Bar, Kitchen).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: provider.isLoading ? null : provider.loadData,
                tooltip: 'Muat Ulang Data Karyawan',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.primaryColor),
              ),
              ElevatedButton.icon(
                onPressed: () => _showKaryawanDialog(context, provider),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Tambah Karyawan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineAddBanner(MasterDataProvider provider) {
    return Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showKaryawanDialog(context, provider),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambah Akun Karyawan Baru',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pilih divisi Kasir, Bar, atau Kitchen sesuai tugas operasional',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required int total,
    required int kasirCount,
    required int barCount,
    required int kitchenCount,
    required int nonaktifCount,
  }) {
    final filters = [
      ('semua', 'Semua ($total)'),
      ('kasir', 'Kasir ($kasirCount)'),
      ('bar', 'Bar ($barCount)'),
      ('kitchen', 'Kitchen ($kitchenCount)'),
      ('nonaktif', 'Nonaktif ($nonaktifCount)'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, email, atau nomor HP karyawan...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((item) {
                final selected = _selectedFilter == item.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = item.$1),
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.backgroundColor,
                    side: BorderSide(
                      color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noAccountsAtAll, MasterDataProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_2_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            noAccountsAtAll
                ? 'Belum ada akun karyawan terdaftar'
                : 'Tidak ada karyawan yang sesuai filter',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noAccountsAtAll
                ? 'Tambahkan akun untuk divisi Kasir, Bar, atau Kitchen agar karyawan bisa login.'
                : 'Coba ubah kata kunci pencarian atau pilih filter divisi lain.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (noAccountsAtAll) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showKaryawanDialog(context, provider),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Karyawan Pertama'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKaryawanCard(MasterKaryawan k, MasterDataProvider provider) {
    final visual = _divisiVisual(k.effectiveDivisi);
    final hpLabel = (k.nomorHp == null || k.nomorHp!.isEmpty) ? '-' : k.nomorHp!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: k.statusAktif ? visual.bgColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  visual.icon,
                  color: k.statusAktif ? visual.fgColor : Colors.grey.shade500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: k.statusAktif ? AppTheme.textColor : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(
                            color: visual.bgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            visual.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: visual.fgColor,
                            ),
                          ),
                        ),
                        if (!k.statusAktif)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              'Nonaktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: k.statusAktif,
                activeTrackColor: AppTheme.primaryColor,
                onChanged: (v) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final err = await provider.updateKaryawan(k.id, {'status_aktif': v});
                  if (!mounted) return;
                  if (err != null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(err), backgroundColor: Colors.red),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          v ? '${k.nama} diaktifkan kembali' : '${k.nama} dinonaktifkan',
                        ),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19, color: AppTheme.primaryColor),
                tooltip: 'Edit Karyawan',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                onPressed: () => _showKaryawanDialog(context, provider, k),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      k.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    hpLabel,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            visual.accessSummary,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<void> _showKaryawanDialog(
    BuildContext context,
    MasterDataProvider provider, [
    MasterKaryawan? existing,
  ]) async {
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _KaryawanFormDialog(
        provider: provider,
        existing: existing,
        visualBuilder: _divisiVisual,
      ),
    );
    if (successMessage != null && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }
}

class _KaryawanFormDialog extends StatefulWidget {
  final MasterDataProvider provider;
  final MasterKaryawan? existing;
  final _DivisiVisual Function(String divisi) visualBuilder;

  const _KaryawanFormDialog({
    required this.provider,
    required this.existing,
    required this.visualBuilder,
  });

  @override
  State<_KaryawanFormDialog> createState() => _KaryawanFormDialogState();
}

class _KaryawanFormDialogState extends State<_KaryawanFormDialog> {
  late final TextEditingController _namaC;
  late final TextEditingController _emailC;
  late final TextEditingController _hpC;
  late final TextEditingController _passC;

  late String _selectedDivisi;
  late bool _statusAktif;
  bool _obscurePass = true;
  bool _submitting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _namaC = TextEditingController(text: widget.existing?.nama ?? '');
    _emailC = TextEditingController(text: widget.existing?.email ?? '');
    _hpC = TextEditingController(text: widget.existing?.nomorHp ?? '');
    _passC = TextEditingController();
    _selectedDivisi = widget.existing?.effectiveDivisi ?? 'kasir';
    _statusAktif = widget.existing?.statusAktif ?? true;
  }

  @override
  void dispose() {
    _namaC.dispose();
    _emailC.dispose();
    _hpC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nama = _namaC.text.trim();
    final email = _emailC.text.trim().toLowerCase();
    final hp = _hpC.text.trim();
    final pass = _passC.text;
    final existing = widget.existing;

    if (nama.isEmpty) {
      setState(() => _formError = 'Nama lengkap wajib diisi');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _formError = 'Masukkan alamat email yang valid');
      return;
    }
    if (existing == null && pass.length < 8) {
      setState(() => _formError = 'Password wajib diisi minimal 8 karakter');
      return;
    }
    if (existing != null && pass.isNotEmpty && pass.length < 8) {
      setState(() => _formError = 'Password baru minimal 8 karakter');
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    String? err;
    if (existing != null) {
      final payload = <String, dynamic>{
        'nama': nama,
        'email': email,
        'divisi': _selectedDivisi,
        'nomor_hp': hp,
        'status_aktif': _statusAktif,
        if (pass.isNotEmpty) 'password': pass,
      };
      err = await widget.provider.updateKaryawan(existing.id, payload);
    } else {
      err = await widget.provider.createKaryawan({
        'nama': nama,
        'email': email,
        'nomor_hp': hp.isEmpty ? null : hp,
        'role': 'karyawan',
        'divisi': _selectedDivisi,
        'password': pass,
        'status_aktif': true,
      });
    }

    if (!mounted) return;
    if (err == null) {
      final msg = existing != null
          ? 'Data $nama berhasil diperbarui'
          : 'Akun $nama ($_selectedDivisi) berhasil dibuat';
      Navigator.of(context).pop(msg);
    } else {
      setState(() {
        _submitting = false;
        _formError = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.visualBuilder(_selectedDivisi);
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      actionsPadding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      title: Text(
        isEdit ? 'Edit Data Karyawan' : 'Tambah Karyawan Baru',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textColor,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_formError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formError!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _namaC,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Login',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedDivisi,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Divisi / Area Kerja',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'kasir',
                    child: Text(
                      'Kasir (POS & Transaksi)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'bar',
                    child: Text(
                      'Bar / Barista (KDS & Stok Bar)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'kitchen',
                    child: Text(
                      'Kitchen (KDS & Stok Dapur)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _selectedDivisi = val);
                        }
                      },
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: visual.bgColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(visual.icon, size: 16, color: visual.fgColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        visual.accessSummary,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: visual.fgColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _hpC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP (Opsional)',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passC,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'Password Baru (Opsional)'
                      : 'Password (Min. 8 karakter)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 12),
                Material(
                  color: AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    title: const Text(
                      'Status Akun Aktif',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _statusAktif
                          ? 'Karyawan dapat login & dijadwalkan'
                          : 'Akses login karyawan dinonaktifkan',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    value: _statusAktif,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: _submitting ? null : (v) => setState(() => _statusAktif = v),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Simpan Perubahan' : 'Buat Akun'),
        ),
      ],
    );
  }
}

class _DivisiVisual {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  final String accessSummary;

  const _DivisiVisual({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.accessSummary,
  });
}
