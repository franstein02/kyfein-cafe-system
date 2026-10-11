/// Model modul Stok. Mengikuti skema di rencana-pengembangan-kyfein.md (3.0 & 3.2).
/// Nama key di fromJson/toJson HARUS dicocokkan dengan response/request FastAPI (cek /docs).

class Bahan {
  final String id;
  final String nama;

  /// Satuan dasar: ml / gram / pcs, dll.
  final String satuan;

  /// Konversi 1 kemasan besar -> satuan kecil (khusus internal gudang).
  /// Kolom DB-nya boleh NULL (decimal 10,3). 0 berarti bahan ini tidak punya kemasan besar.
  final double isiPerKemasan;

  /// Batas stok menipis, dalam satuan kecil.
  final double stokMinimum;

  const Bahan({
    required this.id,
    required this.nama,
    required this.satuan,
    required this.isiPerKemasan,
    required this.stokMinimum,
  });

  bool get punyaKemasan => isiPerKemasan > 0;

  factory Bahan.fromJson(Map<String, dynamic> json) => Bahan(
    id: json['id'].toString(),
    nama: json['nama'] ?? '',
    satuan: json['satuan'] ?? '',
    isiPerKemasan: double.tryParse(json['isi_per_kemasan']?.toString() ?? '') ?? 0,
    stokMinimum: double.tryParse(json['stok_minimum']?.toString() ?? '0') ?? 0,
  );
}

/// Satu baris stok gudang: kemasan utuh + sisa eceran dari kemasan yang sudah dibuka.
class StokGudang {
  final Bahan bahan;
  final int jumlahKemasanBesar;
  final double jumlahSatuanKecil;

  const StokGudang({
    required this.bahan,
    required this.jumlahKemasanBesar,
    required this.jumlahSatuanKecil,
  });

  /// Total dalam satuan kecil = kemasan x isi + eceran.
  double get totalSatuanKecil =>
      jumlahKemasanBesar * bahan.isiPerKemasan + jumlahSatuanKecil;

  bool get menipis => totalSatuanKecil <= bahan.stokMinimum;

  StokGudang tambah({required int kemasan, required double eceran}) => StokGudang(
    bahan: bahan,
    jumlahKemasanBesar: jumlahKemasanBesar + kemasan,
    jumlahSatuanKecil: jumlahSatuanKecil + eceran,
  );

  factory StokGudang.fromJson(Map<String, dynamic> json) => StokGudang(
    bahan: Bahan.fromJson(json['bahan'] as Map<String, dynamic>),
    jumlahKemasanBesar:
    int.tryParse(json['jumlah_kemasan_besar']?.toString() ?? '0') ?? 0,
    jumlahSatuanKecil:
    double.tryParse(json['jumlah_satuan_kecil']?.toString() ?? '0') ?? 0,
  );
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
    bahan: Bahan.fromJson(json['bahan'] as Map<String, dynamic>),
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