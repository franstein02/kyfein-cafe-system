class OpnameHarianItem {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String titik;
  final double? stokAwal;
  final double transferMasuk;
  final double? stokAkhir;
  final double? selisih;
  final String status; // 'lengkap', 'hanya_awal', 'hanya_akhir', 'belum_opname'

  OpnameHarianItem({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.titik,
    this.stokAwal,
    this.transferMasuk = 0,
    this.stokAkhir,
    this.selisih,
    required this.status,
  });

  factory OpnameHarianItem.fromJson(Map<String, dynamic> json) {
    return OpnameHarianItem(
      bahanId: json['bahan_id'] as String? ?? '',
      namaBahan: json['nama_bahan'] as String? ?? '',
      satuan: json['satuan'] as String? ?? '',
      titik: json['titik'] as String? ?? 'bar',
      stokAwal: json['stok_awal'] != null ? (num.tryParse(json['stok_awal'].toString())?.toDouble()) : null,
      transferMasuk: (num.tryParse(json['transfer_masuk']?.toString() ?? '0') ?? 0).toDouble(),
      stokAkhir: json['stok_akhir'] != null ? (num.tryParse(json['stok_akhir'].toString())?.toDouble()) : null,
      selisih: json['selisih'] != null ? (num.tryParse(json['selisih'].toString())?.toDouble()) : null,
      status: json['status'] as String? ?? 'belum_opname',
    );
  }
}

class OpnameHarianSesi {
  final String id;
  final String jadwalShiftId;
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
  final double? varians;
  final double? persentaseSelisih;
  final String statusAudit; // 'sesuai', 'lebih_boros', 'lebih_hemat', 'belum_lengkap'
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
    this.varians,
    this.persentaseSelisih,
    required this.statusAudit,
    this.detailMenu = const [],
  });

  factory OpnameAuditItem.fromJson(Map<String, dynamic> json) {
    final list = json['detail_menu'] as List<dynamic>? ?? [];
    return OpnameAuditItem(
      bahanId: json['bahan_id'] as String? ?? '',
      namaBahan: json['nama_bahan'] as String? ?? '',
      satuan: json['satuan'] as String? ?? '',
      titik: json['titik'] as String? ?? 'bar',
      stokAwal: json['stok_awal'] != null ? (num.tryParse(json['stok_awal'].toString())?.toDouble()) : null,
      transferMasuk: (num.tryParse(json['transfer_masuk']?.toString() ?? '0') ?? 0).toDouble(),
      stokAkhir: json['stok_akhir'] != null ? (num.tryParse(json['stok_akhir'].toString())?.toDouble()) : null,
      pemakaianFisik: json['pemakaian_fisik'] != null ? (num.tryParse(json['pemakaian_fisik'].toString())?.toDouble()) : null,
      pemakaianBom: (num.tryParse(json['pemakaian_bom']?.toString() ?? '0') ?? 0).toDouble(),
      varians: json['varians'] != null ? (num.tryParse(json['varians'].toString())?.toDouble()) : null,
      persentaseSelisih: json['persentase_selisih'] != null ? (num.tryParse(json['persentase_selisih'].toString())?.toDouble()) : null,
      statusAudit: json['status_audit'] as String? ?? 'belum_lengkap',
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

  OpnameAuditSummary({
    this.totalTransaksi = 0,
    this.totalItemTerjual = 0,
    this.totalBahanDiaudit = 0,
    this.bahanSesuai = 0,
    this.bahanSelisih = 0,
    this.bahanBelumLengkap = 0,
  });

  factory OpnameAuditSummary.fromJson(Map<String, dynamic> json) {
    return OpnameAuditSummary(
      totalTransaksi: int.tryParse(json['total_transaksi']?.toString() ?? '0') ?? 0,
      totalItemTerjual: int.tryParse(json['total_item_terjual']?.toString() ?? '0') ?? 0,
      totalBahanDiaudit: int.tryParse(json['total_bahan_diaudit']?.toString() ?? '0') ?? 0,
      bahanSesuai: int.tryParse(json['bahan_sesuai']?.toString() ?? '0') ?? 0,
      bahanSelisih: int.tryParse(json['bahan_selisih']?.toString() ?? '0') ?? 0,
      bahanBelumLengkap: int.tryParse(json['bahan_belum_lengkap']?.toString() ?? '0') ?? 0,
    );
  }
}
