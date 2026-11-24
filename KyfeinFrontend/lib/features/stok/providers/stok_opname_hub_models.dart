class ShiftOpnameSnapshot {
  final String shiftKey;
  final String shiftLabel;
  final String? jadwalShiftId;
  final String? karyawanNama;
  final double? stokAwal;
  final double transferMasuk;
  final double pemakaianBom;
  final double? ekspektasiStok;
  final double? stokAkhir;
  final double? pemakaianAktual;
  final double? selisihVsBom;
  final String statusAudit;
  final String diagnosa;

  ShiftOpnameSnapshot({
    required this.shiftKey,
    required this.shiftLabel,
    this.jadwalShiftId,
    this.karyawanNama,
    this.stokAwal,
    this.transferMasuk = 0,
    this.pemakaianBom = 0,
    this.ekspektasiStok,
    this.stokAkhir,
    this.pemakaianAktual,
    this.selisihVsBom,
    this.statusAudit = 'belum_lengkap',
    this.diagnosa = '',
  });

  factory ShiftOpnameSnapshot.fromJson(Map<String, dynamic> json) {
    double? parseOpt(dynamic v) =>
        v != null ? num.tryParse(v.toString())?.toDouble() : null;
    return ShiftOpnameSnapshot(
      shiftKey: json['shift_key']?.toString() ?? '',
      shiftLabel: json['shift_label']?.toString() ?? 'Shift',
      jadwalShiftId: json['jadwal_shift_id']?.toString(),
      karyawanNama: json['karyawan_nama']?.toString(),
      stokAwal: parseOpt(json['stok_awal']),
      transferMasuk: parseOpt(json['transfer_masuk']) ?? 0,
      pemakaianBom: parseOpt(json['pemakaian_bom']) ?? 0,
      ekspektasiStok: parseOpt(json['ekspektasi_stok']),
      stokAkhir: parseOpt(json['stok_akhir']),
      pemakaianAktual: parseOpt(json['pemakaian_aktual']),
      selisihVsBom: parseOpt(json['selisih_vs_bom']),
      statusAudit: json['status_audit']?.toString() ?? 'belum_lengkap',
      diagnosa: json['diagnosa']?.toString() ?? '',
    );
  }
}

class ShiftComparisonItem {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String titik;
  final ShiftOpnameSnapshot? shift1;
  final ShiftOpnameSnapshot? shift2;
  final double? selisihAkhirS1VsAwalS2;
  final double? selisihStokAkhirS1VsS2;
  final double? selisihPemakaianS1VsS2;
  final double? selisihVariansS1VsS2;
  final String statusHandover; // 'sesuai', 'kurang', 'lebih', 'belum_lengkap'
  final String catatanPerbandingan;

  ShiftComparisonItem({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.titik,
    this.shift1,
    this.shift2,
    this.selisihAkhirS1VsAwalS2,
    this.selisihStokAkhirS1VsS2,
    this.selisihPemakaianS1VsS2,
    this.selisihVariansS1VsS2,
    this.statusHandover = 'belum_lengkap',
    this.catatanPerbandingan = '',
  });

  factory ShiftComparisonItem.fromJson(Map<String, dynamic> json) {
    double? parseOpt(dynamic v) =>
        v != null ? num.tryParse(v.toString())?.toDouble() : null;
    return ShiftComparisonItem(
      bahanId: json['bahan_id']?.toString() ?? '',
      namaBahan: json['nama_bahan']?.toString() ?? '',
      satuan: json['satuan']?.toString() ?? '',
      titik: json['titik']?.toString() ?? 'bar',
      shift1: json['shift_1'] is Map<String, dynamic>
          ? ShiftOpnameSnapshot.fromJson(json['shift_1'] as Map<String, dynamic>)
          : null,
      shift2: json['shift_2'] is Map<String, dynamic>
          ? ShiftOpnameSnapshot.fromJson(json['shift_2'] as Map<String, dynamic>)
          : null,
      selisihAkhirS1VsAwalS2: parseOpt(json['selisih_akhir_s1_vs_awal_s2']),
      selisihStokAkhirS1VsS2: parseOpt(json['selisih_stok_akhir_s1_vs_s2']),
      selisihPemakaianS1VsS2: parseOpt(json['selisih_pemakaian_s1_vs_s2']),
      selisihVariansS1VsS2: parseOpt(json['selisih_varians_s1_vs_s2']),
      statusHandover: json['status_handover']?.toString() ?? 'belum_lengkap',
      catatanPerbandingan: json['catatan_perbandingan']?.toString() ?? '',
    );
  }
}

class OpnameHarianItem {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String titik;
  final double? stokAwal;
  final double transferMasuk;
  final double pemakaianBom;
  final double? ekspektasiStok;
  final double? stokAkhir;
  final double? selisih;
  final double? selisihVsBom;
  final String? diagnosa;
  final String status; // 'lengkap', 'hanya_awal', 'hanya_akhir', 'belum_opname'

  OpnameHarianItem({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.titik,
    this.stokAwal,
    this.transferMasuk = 0,
    this.pemakaianBom = 0,
    this.ekspektasiStok,
    this.stokAkhir,
    this.selisih,
    this.selisihVsBom,
    this.diagnosa,
    required this.status,
  });

  factory OpnameHarianItem.fromJson(Map<String, dynamic> json) {
    double? parseOpt(dynamic v) =>
        v != null ? num.tryParse(v.toString())?.toDouble() : null;
    return OpnameHarianItem(
      bahanId: json['bahan_id'] as String? ?? '',
      namaBahan: json['nama_bahan'] as String? ?? '',
      satuan: json['satuan'] as String? ?? '',
      titik: json['titik'] as String? ?? 'bar',
      stokAwal: parseOpt(json['stok_awal']),
      transferMasuk: parseOpt(json['transfer_masuk']) ?? 0,
      pemakaianBom: parseOpt(json['pemakaian_bom']) ?? 0,
      ekspektasiStok: parseOpt(json['ekspektasi_stok']),
      stokAkhir: parseOpt(json['stok_akhir']),
      selisih: parseOpt(json['selisih']),
      selisihVsBom: parseOpt(json['selisih_vs_bom']),
      diagnosa: json['diagnosa']?.toString(),
      status: json['status'] as String? ?? 'belum_opname',
    );
  }
}

class OpnameHarianSesi {
  final String id;
  final String jadwalShiftId;
  final String? shiftKey;
  final String? shiftLabel;
  final String titik;
  final String tipe;
  final String metode;
  final String? karyawanNama;
  final DateTime waktuOpname;
  final String? catatan;
  final int itemsCount;

  OpnameHarianSesi({
    required this.id,
    required this.jadwalShiftId,
    this.shiftKey,
    this.shiftLabel,
    required this.titik,
    required this.tipe,
    required this.metode,
    this.karyawanNama,
    required this.waktuOpname,
    this.catatan,
    required this.itemsCount,
  });

  factory OpnameHarianSesi.fromJson(Map<String, dynamic> json) {
    return OpnameHarianSesi(
      id: json['id'] as String? ?? '',
      jadwalShiftId: json['jadwal_shift_id'] as String? ?? '',
      shiftKey: json['shift_key']?.toString(),
      shiftLabel: json['shift_label']?.toString(),
      titik: json['titik'] as String? ?? '',
      tipe: json['tipe'] as String? ?? '',
      metode: json['metode'] as String? ?? '',
      karyawanNama: json['karyawan_nama'] as String?,
      waktuOpname: json['waktu_opname'] != null
          ? DateTime.tryParse(json['waktu_opname'].toString()) ?? DateTime.now()
          : DateTime.now(),
      catatan: json['catatan'] as String?,
      itemsCount: int.tryParse(json['items_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class BOMItemDetail {
  final String menuId;
  final String namaMenu;
  final int qtyTerjual;
  final double takaran;
  final double subtotalBom;

  BOMItemDetail({
    required this.menuId,
    required this.namaMenu,
    required this.qtyTerjual,
    required this.takaran,
    required this.subtotalBom,
  });

  factory BOMItemDetail.fromJson(Map<String, dynamic> json) {
    return BOMItemDetail(
      menuId: json['menu_id'] as String? ?? '',
      namaMenu: json['nama_menu'] as String? ?? '',
      qtyTerjual: int.tryParse(json['qty_terjual']?.toString() ?? '0') ?? 0,
      takaran: (num.tryParse(json['takaran']?.toString() ?? '0') ?? 0).toDouble(),
      subtotalBom: (num.tryParse(json['subtotal_bom']?.toString() ?? '0') ?? 0).toDouble(),
    );
  }
}

class OpnameAuditItem {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String titik;
  final double? stokAwal;
  final double transferMasuk;
  final double? stokAkhir;
  final double? pemakaianFisik;
  final double pemakaianBom;
  final double? ekspektasiStok;
  final double? selisihStokAkhirVsEkspektasi;
  final double? varians;
  final double? persentaseSelisih;
  final String statusAudit; // 'sesuai', 'lebih_boros', 'lebih_hemat', 'belum_lengkap'
  final String diagnosa;
  final String penjelasanDiagnosa;
  final List<BOMItemDetail> detailMenu;

  OpnameAuditItem({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.titik,
    this.stokAwal,
    this.transferMasuk = 0,
    this.stokAkhir,
    this.pemakaianFisik,
    required this.pemakaianBom,
    this.ekspektasiStok,
    this.selisihStokAkhirVsEkspektasi,
    this.varians,
    this.persentaseSelisih,
    required this.statusAudit,
    this.diagnosa = '',
    this.penjelasanDiagnosa = '',
    this.detailMenu = const [],
  });

  factory OpnameAuditItem.fromJson(Map<String, dynamic> json) {
    final list = json['detail_menu'] as List<dynamic>? ?? [];
    double? parseOpt(dynamic v) =>
        v != null ? num.tryParse(v.toString())?.toDouble() : null;
    final sa = parseOpt(json['stok_awal']);
    final trf = parseOpt(json['transfer_masuk']) ?? 0;
    final bom = parseOpt(json['pemakaian_bom']) ?? 0;
    final sk = parseOpt(json['stok_akhir']);
    final eksp = parseOpt(json['ekspektasi_stok']) ??
        (sa != null ? (sa + trf) - bom : null);
    final varVal = parseOpt(json['varians']);
    final selEksp = parseOpt(json['selisih_stok_akhir_vs_ekspektasi']) ??
        (sk != null && eksp != null ? sk - eksp : varVal);
    return OpnameAuditItem(
      bahanId: json['bahan_id'] as String? ?? '',
      namaBahan: json['nama_bahan'] as String? ?? '',
      satuan: json['satuan'] as String? ?? '',
      titik: json['titik'] as String? ?? 'bar',
      stokAwal: sa,
      transferMasuk: trf,
      stokAkhir: sk,
      pemakaianFisik: parseOpt(json['pemakaian_fisik']),
      pemakaianBom: bom,
      ekspektasiStok: eksp,
      selisihStokAkhirVsEkspektasi: selEksp,
      varians: varVal,
      persentaseSelisih: parseOpt(json['persentase_selisih']),
      statusAudit: json['status_audit'] as String? ?? 'belum_lengkap',
      diagnosa: json['diagnosa']?.toString() ?? '',
      penjelasanDiagnosa: json['penjelasan_diagnosa']?.toString() ?? '',
      detailMenu: list.map((e) => BOMItemDetail.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class OpnameAuditSummary {
  final int totalTransaksi;
  final int totalItemTerjual;
  final int totalBahanDiaudit;
  final int bahanSesuai;
  final int bahanSelisih;
  final int bahanBelumLengkap;
  final int bahanIndikasiTumpah;
  final int bahanSurplus;
  final int totalShiftDibandingkan;
  final int handoverSelisihCount;

  OpnameAuditSummary({
    this.totalTransaksi = 0,
    this.totalItemTerjual = 0,
    this.totalBahanDiaudit = 0,
    this.bahanSesuai = 0,
    this.bahanSelisih = 0,
    this.bahanBelumLengkap = 0,
    this.bahanIndikasiTumpah = 0,
    this.bahanSurplus = 0,
    this.totalShiftDibandingkan = 0,
    this.handoverSelisihCount = 0,
  });

  factory OpnameAuditSummary.fromJson(Map<String, dynamic> json) {
    return OpnameAuditSummary(
      totalTransaksi: int.tryParse(json['total_transaksi']?.toString() ?? '0') ?? 0,
      totalItemTerjual: int.tryParse(json['total_item_terjual']?.toString() ?? '0') ?? 0,
      totalBahanDiaudit: int.tryParse(json['total_bahan_diaudit']?.toString() ?? '0') ?? 0,
      bahanSesuai: int.tryParse(json['bahan_sesuai']?.toString() ?? '0') ?? 0,
      bahanSelisih: int.tryParse(json['bahan_selisih']?.toString() ?? '0') ?? 0,
      bahanBelumLengkap: int.tryParse(json['bahan_belum_lengkap']?.toString() ?? '0') ?? 0,
      bahanIndikasiTumpah: int.tryParse(json['bahan_indikasi_tumpah']?.toString() ?? '0') ?? 0,
      bahanSurplus: int.tryParse(json['bahan_surplus']?.toString() ?? '0') ?? 0,
      totalShiftDibandingkan: int.tryParse(json['total_shift_dibandingkan']?.toString() ?? '0') ?? 0,
      handoverSelisihCount: int.tryParse(json['handover_selisih_count']?.toString() ?? '0') ?? 0,
    );
  }
}
