// Model modul Stok. Mengikuti skema di rencana-pengembangan-kyfein.md (3.0 & 3.2).
// Nama key di fromJson/toJson HARUS dicocokkan dengan response/request FastAPI (cek /docs).

class Bahan {
  final String id;
  final String nama;

  /// Satuan dasar: ml / gram / pcs, dll.
  final String satuan;

  /// Area penggunaan bahan: 'bar' | 'kitchen' | 'semua'.
  final String area;

  /// Konversi 1 kemasan besar -> satuan kecil (khusus internal gudang).
  /// Kolom DB-nya boleh NULL (decimal 10,3). 0 berarti bahan ini tidak punya kemasan besar.
  final double isiPerKemasan;

  /// Batas stok menipis, dalam satuan kemasan besar (misal 50 kemasan).
  final double stokMinimum;

  /// Harga rata-rata (moving weighted average) per satuan kecil. Hanya tersedia untuk admin/owner.
  final double? hargaRataRata;

  const Bahan({
    required this.id,
    required this.nama,
    required this.satuan,
    this.area = 'semua',
    required this.isiPerKemasan,
    required this.stokMinimum,
    this.hargaRataRata,
  });

  bool get punyaKemasan => isiPerKemasan > 0;

  bool cocokUntukTitik(TitikStok t) => area == 'semua' || area == t.apiValue;

  String get areaLabel {
    switch (area) {
      case 'bar':
        return 'Bar (Minuman)';
      case 'kitchen':
        return 'Kitchen (Dapur)';
      default:
        return 'Bar & Kitchen';
    }
  }

  /// Batas stok minimum dalam satuan kecil (stokMinimum × isiPerKemasan).
  double get batasMinimumSatuanKecil => stokMinimum <= 0
      ? 0
      : (punyaKemasan ? stokMinimum * isiPerKemasan : stokMinimum);

  factory Bahan.fromJson(Map<String, dynamic> json) => Bahan(
    id: json['id'].toString(),
    nama: json['nama'] ?? '',
    satuan: json['satuan'] ?? '',
    area: (json['area'] ?? 'semua').toString().toLowerCase(),
    isiPerKemasan: double.tryParse(json['isi_per_kemasan']?.toString() ?? '') ?? 0,
    stokMinimum: double.tryParse(json['stok_minimum']?.toString() ?? '0') ?? 0,
    hargaRataRata: json['harga_rata_rata'] != null
        ? double.tryParse(json['harga_rata_rata'].toString())
        : null,
  );

  Bahan copyWith({
    String? id,
    String? nama,
    String? satuan,
    String? area,
    double? isiPerKemasan,
    double? stokMinimum,
    double? hargaRataRata,
  }) =>
      Bahan(
        id: id ?? this.id,
        nama: nama ?? this.nama,
        satuan: satuan ?? this.satuan,
        area: area ?? this.area,
        isiPerKemasan: isiPerKemasan ?? this.isiPerKemasan,
        stokMinimum: stokMinimum ?? this.stokMinimum,
        hargaRataRata: hargaRataRata ?? this.hargaRataRata,
      );
}

/// Pemakaian satu bahan pada 1 resep BOM menu beserta biaya per porsi (dari harga AVG).
class StokGudangBomItem {
  final String menuId;
  final String kodeMenu;
  final String namaMenu;
  final String? areaProduksi;
  final double jumlahTerpakai;
  final double biayaPerPorsi;
  final int? estimasiPorsi;

  const StokGudangBomItem({
    required this.menuId,
    required this.kodeMenu,
    required this.namaMenu,
    this.areaProduksi,
    required this.jumlahTerpakai,
    required this.biayaPerPorsi,
    this.estimasiPorsi,
  });

  factory StokGudangBomItem.fromJson(Map<String, dynamic> j) =>
      StokGudangBomItem(
        menuId: j['menu_id']?.toString() ?? '',
        kodeMenu: j['kode_menu']?.toString() ?? '',
        namaMenu: j['nama_menu']?.toString() ?? '-',
        areaProduksi: j['area_produksi']?.toString(),
        jumlahTerpakai:
            double.tryParse((j['jumlah_terpakai'] ?? 0).toString()) ?? 0.0,
        biayaPerPorsi:
            double.tryParse((j['biaya_per_porsi'] ?? 0).toString()) ?? 0.0,
        estimasiPorsi: j['estimasi_porsi'] != null
            ? int.tryParse(j['estimasi_porsi'].toString())
            : null,
      );
}

/// Satu baris stok gudang: kemasan utuh + sisa eceran dari kemasan yang sudah dibuka.
class StokGudang {
  final Bahan bahan;
  final int jumlahKemasanBesar;
  final double jumlahSatuanKecil;
  final double? hargaRataRata;
  final double? hargaRataRataPerKemasan;
  final double? nilaiPersediaan;
  final List<StokGudangBomItem> bomPemakaian;

  const StokGudang({
    required this.bahan,
    required this.jumlahKemasanBesar,
    required this.jumlahSatuanKecil,
    this.hargaRataRata,
    this.hargaRataRataPerKemasan,
    this.nilaiPersediaan,
    this.bomPemakaian = const [],
  });

  /// Total dalam satuan kecil = kemasan x isi + eceran.
  double get totalSatuanKecil =>
      jumlahKemasanBesar * bahan.isiPerKemasan + jumlahSatuanKecil;

  bool get menipis =>
      bahan.batasMinimumSatuanKecil > 0 &&
      totalSatuanKecil <= bahan.batasMinimumSatuanKecil;

  /// True jika respons backend menyertakan harga AVG (khusus admin/owner).
  bool get hasPricing => hargaRataRata != null || bahan.hargaRataRata != null;

  double get effectiveHargaRataRata =>
      hargaRataRata ?? bahan.hargaRataRata ?? 0.0;

  double? get effectiveHargaPerKemasan {
    if (!hasPricing || !bahan.punyaKemasan) return null;
    return hargaRataRataPerKemasan ??
        (effectiveHargaRataRata * bahan.isiPerKemasan);
  }

  double get effectiveNilaiPersediaan =>
      nilaiPersediaan ?? (totalSatuanKecil * effectiveHargaRataRata);

  StokGudang tambah({required int kemasan, required double eceran}) => StokGudang(
    bahan: bahan,
    jumlahKemasanBesar: jumlahKemasanBesar + kemasan,
    jumlahSatuanKecil: jumlahSatuanKecil + eceran,
    hargaRataRata: hargaRataRata,
    hargaRataRataPerKemasan: hargaRataRataPerKemasan,
    nilaiPersediaan: nilaiPersediaan,
    bomPemakaian: bomPemakaian,
  );

  factory StokGudang.fromJson(Map<String, dynamic> json) {
    final bahanObj = json['bahan'] != null
        ? Bahan.fromJson(json['bahan'] as Map<String, dynamic>)
        : Bahan(
            id: json['bahan_id']?.toString() ?? '',
            nama: json['nama_bahan'] ?? '',
            satuan: json['satuan']?.toString() ?? '',
            area: (json['area'] ?? 'semua').toString().toLowerCase(),
            isiPerKemasan:
                double.tryParse(json['isi_per_kemasan']?.toString() ?? '1') ?? 1,
            stokMinimum:
                double.tryParse(json['stok_minimum']?.toString() ?? '0') ?? 0,
            hargaRataRata: json['harga_rata_rata'] != null
                ? double.tryParse(json['harga_rata_rata'].toString())
                : null,
          );
    final avg = json['harga_rata_rata'] != null
        ? double.tryParse(json['harga_rata_rata'].toString())
        : bahanObj.hargaRataRata;
    return StokGudang(
      bahan: bahanObj,
      jumlahKemasanBesar:
          int.tryParse(json['jumlah_kemasan_besar']?.toString() ?? '0') ?? 0,
      jumlahSatuanKecil:
          double.tryParse(json['jumlah_satuan_kecil']?.toString() ?? '0') ?? 0,
      hargaRataRata: avg,
      hargaRataRataPerKemasan: json['harga_rata_rata_per_kemasan'] != null
          ? double.tryParse(json['harga_rata_rata_per_kemasan'].toString())
          : null,
      nilaiPersediaan: json['nilai_persediaan'] != null
          ? double.tryParse(json['nilai_persediaan'].toString())
          : null,
      bomPemakaian: ((json['bom_pemakaian'] as List?) ?? const [])
          .map((e) => StokGudangBomItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu baris input di form Barang Masuk (-> barang_masuk_detail).
class BarangMasukItem {
  final Bahan bahan;
  final int kemasan;
  final double eceran;
  final double hargaTotal;

  const BarangMasukItem({
    required this.bahan,
    required this.kemasan,
    required this.eceran,
    required this.hargaTotal,
  });

  double get totalSatuanKecil => kemasan * bahan.isiPerKemasan + eceran;

  Map<String, dynamic> toJson() => {
    'bahan_id': bahan.id,
    'jumlah_kemasan_besar': kemasan,
    'jumlah_satuan_kecil': eceran,
    'harga_total': hargaTotal,
  };
}

/// Titik operasional tujuan barang keluar (kolom ENUM titik_tujuan / titik).
enum TitikStok {
  bar('bar', 'Bar'),
  kitchen('kitchen', 'Kitchen');

  final String apiValue;
  final String label;
  const TitikStok(this.apiValue, this.label);
}

/// Satu baris input di form Barang Keluar (-> barang_keluar_detail).
/// [jumlah] dalam SATUAN KECIL (ml/gram/pcs), sesuai skema.
class BarangKeluarItem {
  final Bahan bahan;
  final double jumlah;

  const BarangKeluarItem({required this.bahan, required this.jumlah});

  Map<String, dynamic> toJson() => {
    'bahan_id': bahan.id,
    'jumlah': jumlah,
  };
}

/// Tipe kejadian opname (kolom ENUM stok_opname.tipe).
enum TipeOpname {
  awalShift('awal_shift', 'Awal shift'),
  akhirShift('akhir_shift', 'Akhir shift');

  final String apiValue;
  final String label;
  const TipeOpname(this.apiValue, this.label);
}

/// Metode opname (kolom ENUM stok_opname.metode). Ditentukan backend, bukan dipilih karyawan.
/// carry_forward = same-day handover (1 tap konfirmasi), hitung_manual = wajib hitung fisik.
enum MetodeOpname {
  hitungManual('hitung_manual'),
  carryForward('carry_forward');

  final String apiValue;
  const MetodeOpname(this.apiValue);
}

/// Satu bahan yang harus dihitung di sebuah titik.
class OpnameBahan {
  final Bahan bahan;

  /// Hanya terisi untuk carry_forward: stok akhir shift sebelumnya + transfer masuk.
  final double? ekspektasi;

  const OpnameBahan({required this.bahan, this.ekspektasi});
}

/// Konteks 1 sesi opname: titik, tipe, metode, dan daftar bahan yang dihitung.
class OpnameKonteks {
  final TitikStok titik;
  final TipeOpname tipe;
  final MetodeOpname metode;
  final List<OpnameBahan> daftar;

  const OpnameKonteks({
    required this.titik,
    required this.tipe,
    required this.metode,
    required this.daftar,
  });
}

/// Satu baris hasil hitung (-> stok_opname_detail). [jumlah] = 1 angka dalam satuan dasar bahan.
class OpnameItem {
  final String bahanId;
  final double jumlah;

  const OpnameItem({required this.bahanId, required this.jumlah});

  Map<String, dynamic> toJson() => {'bahan_id': bahanId, 'jumlah': jumlah};
}

/// Stok di titik (Bar/Kitchen) = hasil hitung fisik opname terakhir (tabel stok_titik).
/// [jumlah] 1 angka dalam satuan dasar bahan.
class StokTitik {
  final Bahan bahan;
  final TitikStok titik;
  final double jumlah;
  final DateTime? diperbaruiPada;

  const StokTitik({
    required this.bahan,
    required this.titik,
    required this.jumlah,
    this.diperbaruiPada,
  });

  factory StokTitik.fromJson(Map<String, dynamic> json) => StokTitik(
    bahan: json['bahan'] != null
        ? Bahan.fromJson(json['bahan'] as Map<String, dynamic>)
        : Bahan(
            id: json['bahan_id']?.toString() ?? '',
            nama: json['nama_bahan'] ?? '',
            satuan: '',
            isiPerKemasan: 1,
            stokMinimum: 0,
          ),
    titik: json['titik'] == 'kitchen' ? TitikStok.kitchen : TitikStok.bar,
    jumlah: double.tryParse(json['jumlah']?.toString() ?? '0') ?? 0,
    diperbaruiPada: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
  );
}

/// Format angka: 12.0 -> "12", 12.5 -> "12,5"
String formatAngka(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

/// Satu-satunya tempat format tampilan stok gudang, supaya konsisten di semua layar.
/// Contoh: "2 kemasan + 5 pcs"
String formatStokGudang(StokGudang s) {
  final kemasan = s.jumlahKemasanBesar;
  final eceran = s.jumlahSatuanKecil;
  if (kemasan == 0 && eceran == 0) return 'Kosong';
  final bagian = <String>[];
  if (kemasan > 0) bagian.add('$kemasan kemasan');
  if (eceran > 0) bagian.add('${formatAngka(eceran)} ${s.bahan.satuan}');
  return bagian.join(' + ');
}

/// Rincian 1 baris bahan pada rekap transaksi barang masuk.
class BarangMasukRekapDetail {
  final String id;
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String area;
  final double isiPerKemasan;
  final int jumlahKemasanBesar;
  final double jumlahSatuanKecil;
  final double totalSatuanKecil;
  final double hargaTotal;
  final double hargaPerSatuanKecil;
  final double? hargaPerKemasan;
  final double hargaRataRataSaatIni;
  final double? selisihVsAvg;

  const BarangMasukRekapDetail({
    required this.id,
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.area,
    required this.isiPerKemasan,
    required this.jumlahKemasanBesar,
    required this.jumlahSatuanKecil,
    required this.totalSatuanKecil,
    required this.hargaTotal,
    required this.hargaPerSatuanKecil,
    this.hargaPerKemasan,
    required this.hargaRataRataSaatIni,
    this.selisihVsAvg,
  });

  factory BarangMasukRekapDetail.fromJson(Map<String, dynamic> j) =>
      BarangMasukRekapDetail(
        id: j['id']?.toString() ?? '',
        bahanId: j['bahan_id']?.toString() ?? '',
        namaBahan: j['nama_bahan']?.toString() ?? '-',
        satuan: j['satuan']?.toString() ?? '',
        area: (j['area'] ?? 'semua').toString().toLowerCase(),
        isiPerKemasan:
            double.tryParse((j['isi_per_kemasan'] ?? 0).toString()) ?? 0.0,
        jumlahKemasanBesar:
            int.tryParse((j['jumlah_kemasan_besar'] ?? 0).toString()) ?? 0,
        jumlahSatuanKecil:
            double.tryParse((j['jumlah_satuan_kecil'] ?? 0).toString()) ?? 0.0,
        totalSatuanKecil:
            double.tryParse((j['total_satuan_kecil'] ?? 0).toString()) ?? 0.0,
        hargaTotal: double.tryParse((j['harga_total'] ?? 0).toString()) ?? 0.0,
        hargaPerSatuanKecil:
            double.tryParse((j['harga_per_satuan_kecil'] ?? 0).toString()) ??
                0.0,
        hargaPerKemasan: j['harga_per_kemasan'] != null
            ? double.tryParse(j['harga_per_kemasan'].toString())
            : null,
        hargaRataRataSaatIni:
            double.tryParse((j['harga_rata_rata_saat_ini'] ?? 0).toString()) ??
                0.0,
        selisihVsAvg: j['selisih_vs_avg'] != null
            ? double.tryParse(j['selisih_vs_avg'].toString())
            : null,
      );
}

/// 1 header pencatatan barang masuk beserta daftar item & total harganya.
class BarangMasukRekapItem {
  final String id;
  final DateTime? waktu;
  final String karyawanId;
  final String namaKaryawan;
  final String? catatan;
  final int jumlahItem;
  final double totalNilai;
  final List<BarangMasukRekapDetail> details;

  const BarangMasukRekapItem({
    required this.id,
    this.waktu,
    required this.karyawanId,
    required this.namaKaryawan,
    this.catatan,
    required this.jumlahItem,
    required this.totalNilai,
    required this.details,
  });

  factory BarangMasukRekapItem.fromJson(Map<String, dynamic> j) =>
      BarangMasukRekapItem(
        id: j['id']?.toString() ?? '',
        waktu: DateTime.tryParse(j['waktu']?.toString() ?? ''),
        karyawanId: j['karyawan_id']?.toString() ?? '',
        namaKaryawan: j['nama_karyawan']?.toString() ?? '-',
        catatan: j['catatan']?.toString(),
        jumlahItem: int.tryParse((j['jumlah_item'] ?? 0).toString()) ?? 0,
        totalNilai: double.tryParse((j['total_nilai'] ?? 0).toString()) ?? 0.0,
        details: ((j['details'] as List?) ?? const [])
            .map((e) => BarangMasukRekapDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Respons lengkap rekap barang masuk dari GET /stok/barang-masuk.
class BarangMasukRekapResponse {
  final int totalTransaksi;
  final int totalItemMasuk;
  final double totalNilaiPembelian;
  final List<BarangMasukRekapItem> items;

  const BarangMasukRekapResponse({
    required this.totalTransaksi,
    required this.totalItemMasuk,
    required this.totalNilaiPembelian,
    required this.items,
  });

  factory BarangMasukRekapResponse.fromJson(Map<String, dynamic> j) =>
      BarangMasukRekapResponse(
        totalTransaksi:
            int.tryParse((j['total_transaksi'] ?? 0).toString()) ?? 0,
        totalItemMasuk:
            int.tryParse((j['total_item_masuk'] ?? 0).toString()) ?? 0,
        totalNilaiPembelian:
            double.tryParse((j['total_nilai_pembelian'] ?? 0).toString()) ??
                0.0,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => BarangMasukRekapItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}