import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stok/providers/stok_gudang_provider.dart';
import '../../stok/providers/stok_models.dart';

export '../../stok/providers/stok_models.dart'
    show
        BarangMasukRekapDetail,
        BarangMasukRekapItem,
        BarangMasukRekapResponse;

class AbsensiLogItemModel {
  final String jadwalShiftId;
  final String tanggal;
  final String shift;
  final String areaKerja;
  final String jamMulai;
  final String jamSelesai;
  final String? jamMasuk;
  final String? jamPulang;
  final int menitTelat;
  final String statusKehadiran;
  final bool lupaAbsenPulang;
  final String? keterangan;

  AbsensiLogItemModel({
    required this.jadwalShiftId,
    required this.tanggal,
    required this.shift,
    required this.areaKerja,
    required this.jamMulai,
    required this.jamSelesai,
    this.jamMasuk,
    this.jamPulang,
    this.menitTelat = 0,
    required this.statusKehadiran,
    this.lupaAbsenPulang = false,
    this.keterangan,
  });

  factory AbsensiLogItemModel.fromJson(Map<String, dynamic> j) =>
      AbsensiLogItemModel(
        jadwalShiftId: j['jadwal_shift_id']?.toString() ?? '',
        tanggal: j['tanggal']?.toString() ?? '',
        shift: j['shift']?.toString() ?? '',
        areaKerja: j['area_kerja']?.toString() ?? '',
        jamMulai: j['jam_mulai']?.toString() ?? '',
        jamSelesai: j['jam_selesai']?.toString() ?? '',
        jamMasuk: j['jam_masuk']?.toString(),
        jamPulang: j['jam_pulang']?.toString(),
        menitTelat: int.tryParse((j['menit_telat'] ?? 0).toString()) ?? 0,
        statusKehadiran: j['status_kehadiran']?.toString() ?? 'belum_mulai',
        lupaAbsenPulang: j['lupa_absen_pulang'] == true,
        keterangan: j['keterangan']?.toString(),
      );
}

class AbsensiKaryawanItemModel {
  final String karyawanId;
  final String nama;
  final String divisi;
  final int totalShiftTerjadwal;
  final int totalHadir;
  final int tepatWaktuCount;
  final int telatCount;
  final int totalMenitTelat;
  final double rataMenitTelat;
  final int izinTelatCount;
  final int izinTidakMasukCount;
  final int lupaAbsenPulangCount;
  final int tanpaKeteranganCount;
  final int tukarShiftCount;
  final double tingkatKetepatanPersen;
  final String kategoriPerilaku;
  final String ringkasanPerilaku;
  final List<AbsensiLogItemModel> riwayatShift;

  AbsensiKaryawanItemModel({
    required this.karyawanId,
    required this.nama,
    required this.divisi,
    this.totalShiftTerjadwal = 0,
    this.totalHadir = 0,
    this.tepatWaktuCount = 0,
    this.telatCount = 0,
    this.totalMenitTelat = 0,
    this.rataMenitTelat = 0.0,
    this.izinTelatCount = 0,
    this.izinTidakMasukCount = 0,
    this.lupaAbsenPulangCount = 0,
    this.tanpaKeteranganCount = 0,
    this.tukarShiftCount = 0,
    this.tingkatKetepatanPersen = 100.0,
    this.kategoriPerilaku = 'belum_ada_data',
    this.ringkasanPerilaku = '',
    this.riwayatShift = const [],
  });

  factory AbsensiKaryawanItemModel.fromJson(Map<String, dynamic> j) =>
      AbsensiKaryawanItemModel(
        karyawanId: j['karyawan_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '-',
        divisi: (j['divisi'] ?? 'kasir').toString().toLowerCase(),
        totalShiftTerjadwal:
            int.tryParse((j['total_shift_terjadwal'] ?? 0).toString()) ?? 0,
        totalHadir: int.tryParse((j['total_hadir'] ?? 0).toString()) ?? 0,
        tepatWaktuCount:
            int.tryParse((j['tepat_waktu_count'] ?? 0).toString()) ?? 0,
        telatCount: int.tryParse((j['telat_count'] ?? 0).toString()) ?? 0,
        totalMenitTelat:
            int.tryParse((j['total_menit_telat'] ?? 0).toString()) ?? 0,
        rataMenitTelat:
            double.tryParse((j['rata_menit_telat'] ?? 0).toString()) ?? 0.0,
        izinTelatCount:
            int.tryParse((j['izin_telat_count'] ?? 0).toString()) ?? 0,
        izinTidakMasukCount:
            int.tryParse((j['izin_tidak_masuk_count'] ?? 0).toString()) ?? 0,
        lupaAbsenPulangCount:
            int.tryParse((j['lupa_absen_pulang_count'] ?? 0).toString()) ?? 0,
        tanpaKeteranganCount:
            int.tryParse((j['tanpa_keterangan_count'] ?? 0).toString()) ?? 0,
        tukarShiftCount:
            int.tryParse((j['tukar_shift_count'] ?? 0).toString()) ?? 0,
        tingkatKetepatanPersen:
            double.tryParse((j['tingkat_ketepatan_persen'] ?? 100).toString()) ??
                100.0,
        kategoriPerilaku:
            j['kategori_perilaku']?.toString() ?? 'belum_ada_data',
        ringkasanPerilaku: j['ringkasan_perilaku']?.toString() ?? '',
        riwayatShift: ((j['riwayat_shift'] as List?) ?? const [])
            .map((e) => AbsensiLogItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProfitReportModel {
  final String filter;
  final String periodeMulai;
  final String periodeSelesai;
  final int jumlahTransaksi;
  final int jumlahTransaksiDibatalkan;
  final double totalCash;
  final double totalQris;
  final double totalPenjualan;
  final double totalHppTeoritis;
  final double labaKotor;
  final double grossMarginPersen;
  final double pengeluaranBulananProRata;
  final double pengeluaranMendadak;
  final double totalOperasional;
  final double netProfit;
  final double netMarginPersen;
  final List<String> menuTanpaResep;
  final int jumlahBarangMasuk;
  final double totalBelanjaBarangMasuk;
  final double totalPengeluaranKas;
  final double arusKasBersih;
  final double nilaiAsetStokGudang;
  final double nilaiAsetStokTitik;
  final double nilaiAsetStokSaatIni;
  final int jumlahBarangKeluar;
  final int jumlahSesiOpname;
  final int jumlahStokMenipis;
  final int totalShiftTerjadwal;
  final int totalHadir;
  final int totalTepatWaktu;
  final int totalTerlambat;
  final int totalMenitTelat;
  final int totalIzinTelat;
  final int totalIzinTidakMasuk;
  final int totalTanpaKeterangan;
  final int totalLupaAbsenPulang;
  final double tingkatKetepatanPersen;
  final List<AbsensiKaryawanItemModel> absensiPerKaryawan;

  ProfitReportModel({
    required this.filter,
    required this.periodeMulai,
    required this.periodeSelesai,
    required this.jumlahTransaksi,
    required this.jumlahTransaksiDibatalkan,
    required this.totalCash,
    required this.totalQris,
    required this.totalPenjualan,
    required this.totalHppTeoritis,
    this.labaKotor = 0.0,
    this.grossMarginPersen = 0.0,
    required this.pengeluaranBulananProRata,
    required this.pengeluaranMendadak,
    this.totalOperasional = 0.0,
    required this.netProfit,
    this.netMarginPersen = 0.0,
    required this.menuTanpaResep,
    required this.jumlahBarangMasuk,
    this.totalBelanjaBarangMasuk = 0.0,
    this.totalPengeluaranKas = 0.0,
    this.arusKasBersih = 0.0,
    this.nilaiAsetStokGudang = 0.0,
    this.nilaiAsetStokTitik = 0.0,
    this.nilaiAsetStokSaatIni = 0.0,
    required this.jumlahBarangKeluar,
    required this.jumlahSesiOpname,
    required this.jumlahStokMenipis,
    this.totalShiftTerjadwal = 0,
    required this.totalHadir,
    required this.totalTepatWaktu,
    required this.totalTerlambat,
    this.totalMenitTelat = 0,
    required this.totalIzinTelat,
    required this.totalIzinTidakMasuk,
    this.totalTanpaKeterangan = 0,
    this.totalLupaAbsenPulang = 0,
    this.tingkatKetepatanPersen = 100.0,
    this.absensiPerKaryawan = const [],
  });

  factory ProfitReportModel.fromJson(Map<String, dynamic> j) {
    final tgl = j['tanggal']?.toString() ?? '';
    final penjualan =
        double.tryParse((j['total_penjualan'] ?? 0).toString()) ?? 0.0;
    final hpp =
        double.tryParse((j['total_hpp_teoritis'] ?? 0).toString()) ?? 0.0;
    final bulanan =
        double.tryParse((j['pengeluaran_bulanan_pro_rata'] ?? 0).toString()) ??
            0.0;
    final mendadak =
        double.tryParse((j['pengeluaran_mendadak'] ?? 0).toString()) ?? 0.0;
    final opex = j['total_operasional'] != null
        ? (double.tryParse(j['total_operasional'].toString()) ?? (bulanan + mendadak))
        : (bulanan + mendadak);
    final labaKtr = j['laba_kotor'] != null
        ? (double.tryParse(j['laba_kotor'].toString()) ?? (penjualan - hpp))
        : (penjualan - hpp);
    final netPrf = double.tryParse(
            (j['net_profit'] ?? j['net_profit_harian'] ?? (labaKtr - opex))
                .toString()) ??
        0.0;
    final belanjaBm =
        double.tryParse((j['total_belanja_barang_masuk'] ?? 0).toString()) ??
            0.0;
    final totalKasKeluar = j['total_pengeluaran_kas'] != null
        ? (double.tryParse(j['total_pengeluaran_kas'].toString()) ??
            (opex + belanjaBm))
        : (opex + belanjaBm);
    final kasBersih = j['arus_kas_bersih'] != null
        ? (double.tryParse(j['arus_kas_bersih'].toString()) ??
            (penjualan - totalKasKeluar))
        : (penjualan - totalKasKeluar);

    return ProfitReportModel(
      filter: j['filter']?.toString() ?? 'harian',
      periodeMulai: j['periode_mulai']?.toString() ?? tgl,
      periodeSelesai: j['periode_selesai']?.toString() ?? tgl,
      jumlahTransaksi: int.tryParse((j['jumlah_transaksi'] ?? 0).toString()) ?? 0,
      jumlahTransaksiDibatalkan: int.tryParse((j['jumlah_transaksi_dibatalkan'] ?? 0).toString()) ?? 0,
      totalCash: double.tryParse((j['total_cash'] ?? 0).toString()) ?? 0.0,
      totalQris: double.tryParse((j['total_qris'] ?? 0).toString()) ?? 0.0,
      totalPenjualan: penjualan,
      totalHppTeoritis: hpp,
      labaKotor: labaKtr,
      grossMarginPersen: j['gross_margin_persen'] != null
          ? (double.tryParse(j['gross_margin_persen'].toString()) ?? 0.0)
          : (penjualan > 0 ? (labaKtr / penjualan) * 100.0 : 0.0),
      pengeluaranBulananProRata: bulanan,
      pengeluaranMendadak: mendadak,
      totalOperasional: opex,
      netProfit: netPrf,
      netMarginPersen: j['net_margin_persen'] != null
          ? (double.tryParse(j['net_margin_persen'].toString()) ?? 0.0)
          : (penjualan > 0 ? (netPrf / penjualan) * 100.0 : 0.0),
      menuTanpaResep: ((j['menu_tanpa_resep'] ?? []) as List).map((e) => e.toString()).toList(),
      jumlahBarangMasuk: int.tryParse((j['jumlah_barang_masuk'] ?? 0).toString()) ?? 0,
      totalBelanjaBarangMasuk: belanjaBm,
      totalPengeluaranKas: totalKasKeluar,
      arusKasBersih: kasBersih,
      nilaiAsetStokGudang:
          double.tryParse((j['nilai_aset_stok_gudang'] ?? 0).toString()) ?? 0.0,
      nilaiAsetStokTitik:
          double.tryParse((j['nilai_aset_stok_titik'] ?? 0).toString()) ?? 0.0,
      nilaiAsetStokSaatIni:
          double.tryParse((j['nilai_aset_stok_saat_ini'] ?? 0).toString()) ?? 0.0,
      jumlahBarangKeluar: int.tryParse((j['jumlah_barang_keluar'] ?? 0).toString()) ?? 0,
      jumlahSesiOpname: int.tryParse((j['jumlah_sesi_opname'] ?? 0).toString()) ?? 0,
      jumlahStokMenipis: int.tryParse((j['jumlah_stok_menipis'] ?? 0).toString()) ?? 0,
      totalShiftTerjadwal: int.tryParse((j['total_shift_terjadwal'] ?? 0).toString()) ?? 0,
      totalHadir: int.tryParse((j['total_hadir'] ?? 0).toString()) ?? 0,
      totalTepatWaktu: int.tryParse((j['total_tepat_waktu'] ?? 0).toString()) ?? 0,
      totalTerlambat: int.tryParse((j['total_terlambat'] ?? 0).toString()) ?? 0,
      totalMenitTelat: int.tryParse((j['total_menit_telat'] ?? 0).toString()) ?? 0,
      totalIzinTelat: int.tryParse((j['total_izin_telat'] ?? 0).toString()) ?? 0,
      totalIzinTidakMasuk: int.tryParse((j['total_izin_tidak_masuk'] ?? 0).toString()) ?? 0,
      totalTanpaKeterangan: int.tryParse((j['total_tanpa_keterangan'] ?? 0).toString()) ?? 0,
      totalLupaAbsenPulang: int.tryParse((j['total_lupa_absen_pulang'] ?? 0).toString()) ?? 0,
      tingkatKetepatanPersen:
          double.tryParse((j['tingkat_ketepatan_persen'] ?? 100).toString()) ?? 100.0,
      absensiPerKaryawan: ((j['absensi_per_karyawan'] as List?) ?? const [])
          .map((e) => AbsensiKaryawanItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExpenseBreakdownItemModel {
  final String kategoriId;
  final String namaKategori;
  final double totalNominal;
  final double persentase;

  ExpenseBreakdownItemModel({
    required this.kategoriId,
    required this.namaKategori,
    required this.totalNominal,
    required this.persentase,
  });

  factory ExpenseBreakdownItemModel.fromJson(Map<String, dynamic> j) => ExpenseBreakdownItemModel(
        kategoriId: j['kategori_id']?.toString() ?? '',
        namaKategori: j['nama_kategori']?.toString() ?? '-',
        totalNominal: double.tryParse((j['total_nominal'] ?? 0).toString()) ?? 0.0,
        persentase: double.tryParse((j['persentase'] ?? 0).toString()) ?? 0.0,
      );
}

class ExpenseBreakdownReportModel {
  final String filter;
  final String periodeMulai;
  final String periodeSelesai;
  final double totalPengeluaran;
  final double totalBelanjaBahan;
  final double totalSemuaPengeluaran;
  final List<ExpenseBreakdownItemModel> items;
  final List<ExpenseBreakdownItemModel> itemsDenganBahan;

  ExpenseBreakdownReportModel({
    required this.filter,
    required this.periodeMulai,
    required this.periodeSelesai,
    required this.totalPengeluaran,
    this.totalBelanjaBahan = 0.0,
    this.totalSemuaPengeluaran = 0.0,
    required this.items,
    this.itemsDenganBahan = const [],
  });

  factory ExpenseBreakdownReportModel.fromJson(Map<String, dynamic> j) {
    final baseItems = ((j['items'] ?? j['breakdown'] ?? []) as List)
        .map((e) => ExpenseBreakdownItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final totOps =
        double.tryParse((j['total_pengeluaran'] ?? 0).toString()) ?? 0.0;
    final totBhn =
        double.tryParse((j['total_belanja_bahan'] ?? 0).toString()) ?? 0.0;
    final totAll = j['total_semua_pengeluaran'] != null
        ? (double.tryParse(j['total_semua_pengeluaran'].toString()) ??
            (totOps + totBhn))
        : (totOps + totBhn);
    final combinedRaw = j['items_dengan_bahan'] as List?;
    final combined = combinedRaw != null
        ? combinedRaw
            .map((e) =>
                ExpenseBreakdownItemModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : baseItems;

    return ExpenseBreakdownReportModel(
      filter: j['filter']?.toString() ?? 'harian',
      periodeMulai: j['periode_mulai']?.toString() ?? '',
      periodeSelesai: j['periode_selesai']?.toString() ?? '',
      totalPengeluaran: totOps,
      totalBelanjaBahan: totBhn,
      totalSemuaPengeluaran: totAll,
      items: baseItems,
      itemsDenganBahan: combined,
    );
  }
}

class PengeluaranModel {
  final String id;
  final String tipe;
  final String? kategoriId;
  final String? namaPengeluaran;
  final String namaKategori;
  final double nominal;
  final String? bulan;
  final String? tanggal;
  final String? keterangan;
  final double? proRataHarian;
  final int? jumlahHariBulan;
  final String? dicatatOleh;
  final String sumber;
  final int? jumlahItem;
  final bool editable;

  PengeluaranModel({
    required this.id,
    required this.tipe,
    this.kategoriId,
    this.namaPengeluaran,
    required this.namaKategori,
    required this.nominal,
    this.bulan,
    this.tanggal,
    this.keterangan,
    this.proRataHarian,
    this.jumlahHariBulan,
    this.dicatatOleh,
    this.sumber = 'operasional',
    this.jumlahItem,
    this.editable = true,
  });

  factory PengeluaranModel.fromJson(Map<String, dynamic> j) => PengeluaranModel(
        id: j['id']?.toString() ?? '',
        tipe: j['tipe']?.toString() ?? 'mendadak',
        kategoriId: j['kategori_id']?.toString(),
        namaPengeluaran: j['nama_pengeluaran']?.toString(),
        namaKategori: j['nama_kategori']?.toString() ?? '-',
        nominal: double.tryParse((j['nominal'] ?? 0).toString()) ?? 0.0,
        bulan: j['bulan']?.toString(),
        tanggal: j['tanggal']?.toString(),
        keterangan: j['keterangan']?.toString(),
        proRataHarian: j['pro_rata_harian'] != null
            ? double.tryParse(j['pro_rata_harian'].toString())
            : null,
        jumlahHariBulan: j['jumlah_hari_bulan'] is int
            ? j['jumlah_hari_bulan'] as int
            : int.tryParse((j['jumlah_hari_bulan'] ?? '').toString()),
        dicatatOleh: j['dicatat_oleh']?.toString(),
        sumber: j['sumber']?.toString() ?? 'operasional',
        jumlahItem: j['jumlah_item'] is int
            ? j['jumlah_item'] as int
            : int.tryParse((j['jumlah_item'] ?? '').toString()),
        editable: j['editable'] is bool
            ? j['editable'] as bool
            : (j['sumber']?.toString() != 'barang_masuk'),
      );
}

class KategoriPengeluaranModel {
  final String id;
  final String nama;
  final bool statusAktif;

  KategoriPengeluaranModel({
    required this.id,
    required this.nama,
    required this.statusAktif,
  });

  factory KategoriPengeluaranModel.fromJson(Map<String, dynamic> j) => KategoriPengeluaranModel(
        id: j['id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        statusAktif: j['status_aktif'] == true,
      );
}

class StokMenipisItemModel {
  final String id;
  final String nama;
  final String satuanDasar;
  final double batasStokMinimum;
  final double isiPerKemasan;
  final double totalStok;

  StokMenipisItemModel({
    required this.id,
    required this.nama,
    required this.satuanDasar,
    required this.batasStokMinimum,
    this.isiPerKemasan = 0.0,
    required this.totalStok,
  });

  double get batasMinimumKecil =>
      isiPerKemasan > 0 ? batasStokMinimum * isiPerKemasan : batasStokMinimum;

  factory StokMenipisItemModel.fromJson(Map<String, dynamic> j) => StokMenipisItemModel(
        id: j['id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? j['nama_bahan']?.toString() ?? '-',
        satuanDasar: (j['satuan'] ?? j['satuan_dasar'] ?? '').toString(),
        batasStokMinimum: double.tryParse(
                (j['stok_minimum'] ?? j['batas_stok_minimum'] ?? 0).toString()) ??
            0.0,
        isiPerKemasan: double.tryParse((j['isi_per_kemasan'] ?? 0).toString()) ?? 0.0,
        totalStok: double.tryParse((j['total_stok'] ?? j['jumlah_sisa'] ?? 0).toString()) ?? 0.0,
      );
}

class MenuHppBahanItemModel {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String area;
  final double jumlahTerpakai;
  final double hargaRataRata;
  final double subtotalHpp;
  final double persentaseKontribusi;

  MenuHppBahanItemModel({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.area,
    required this.jumlahTerpakai,
    required this.hargaRataRata,
    required this.subtotalHpp,
    required this.persentaseKontribusi,
  });

  factory MenuHppBahanItemModel.fromJson(Map<String, dynamic> j) => MenuHppBahanItemModel(
        bahanId: j['bahan_id']?.toString() ?? '',
        namaBahan: j['nama_bahan']?.toString() ?? '-',
        satuan: j['satuan']?.toString() ?? '',
        area: j['area']?.toString() ?? 'semua',
        jumlahTerpakai: double.tryParse((j['jumlah_terpakai'] ?? 0).toString()) ?? 0.0,
        hargaRataRata: double.tryParse((j['harga_rata_rata'] ?? 0).toString()) ?? 0.0,
        subtotalHpp: double.tryParse((j['subtotal_hpp'] ?? 0).toString()) ?? 0.0,
        persentaseKontribusi:
            double.tryParse((j['persentase_kontribusi'] ?? 0).toString()) ?? 0.0,
      );
}

class MenuHppItemModel {
  final String menuId;
  final String kodeMenu;
  final String namaMenu;
  final String kategoriNama;
  final String areaProduksi;
  final bool statusAktif;
  final double hargaJual;
  final double hppSaatIni;
  final double labaKotor;
  final double marginPersen;
  final double? hppTerjualRataRata;
  final double? selisihHppVsRataTerjual;
  final int qtyTerjual;
  final bool punyaResep;
  final List<MenuHppBahanItemModel> resepItems;

  MenuHppItemModel({
    required this.menuId,
    required this.kodeMenu,
    required this.namaMenu,
    required this.kategoriNama,
    required this.areaProduksi,
    required this.statusAktif,
    required this.hargaJual,
    required this.hppSaatIni,
    required this.labaKotor,
    required this.marginPersen,
    this.hppTerjualRataRata,
    this.selisihHppVsRataTerjual,
    required this.qtyTerjual,
    required this.punyaResep,
    required this.resepItems,
  });

  factory MenuHppItemModel.fromJson(Map<String, dynamic> j) => MenuHppItemModel(
        menuId: j['menu_id']?.toString() ?? '',
        kodeMenu: j['kode_menu']?.toString() ?? '',
        namaMenu: j['nama_menu']?.toString() ?? '',
        kategoriNama: j['kategori_nama']?.toString() ?? '-',
        areaProduksi: j['area_produksi']?.toString() ?? 'bar',
        statusAktif: j['status_aktif'] == true,
        hargaJual: double.tryParse((j['harga_jual'] ?? 0).toString()) ?? 0.0,
        hppSaatIni: double.tryParse((j['hpp_saat_ini'] ?? 0).toString()) ?? 0.0,
        labaKotor: double.tryParse((j['laba_kotor'] ?? 0).toString()) ?? 0.0,
        marginPersen: double.tryParse((j['margin_persen'] ?? 0).toString()) ?? 0.0,
        hppTerjualRataRata: j['hpp_terjual_rata_rata'] != null
            ? double.tryParse(j['hpp_terjual_rata_rata'].toString())
            : null,
        selisihHppVsRataTerjual: j['selisih_hpp_vs_rata_terjual'] != null
            ? double.tryParse(j['selisih_hpp_vs_rata_terjual'].toString())
            : null,
        qtyTerjual: int.tryParse((j['qty_terjual'] ?? 0).toString()) ?? 0,
        punyaResep: j['punya_resep'] == true,
        resepItems: ((j['resep_items'] as List?) ?? const [])
            .map((e) => MenuHppBahanItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BahanHargaMonitorModel {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final String area;
  final double hargaRataRata;
  final double? hargaBeliTerakhir;
  final double? selisihTerakhirVsAvg;
  final String? tanggalBeliTerakhir;
  final int jumlahMenuTerkait;

  BahanHargaMonitorModel({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.area,
    required this.hargaRataRata,
    this.hargaBeliTerakhir,
    this.selisihTerakhirVsAvg,
    this.tanggalBeliTerakhir,
    required this.jumlahMenuTerkait,
  });

  factory BahanHargaMonitorModel.fromJson(Map<String, dynamic> j) => BahanHargaMonitorModel(
        bahanId: j['bahan_id']?.toString() ?? '',
        namaBahan: j['nama_bahan']?.toString() ?? '-',
        satuan: j['satuan']?.toString() ?? '',
        area: j['area']?.toString() ?? 'semua',
        hargaRataRata: double.tryParse((j['harga_rata_rata'] ?? 0).toString()) ?? 0.0,
        hargaBeliTerakhir: j['harga_beli_terakhir'] != null
            ? double.tryParse(j['harga_beli_terakhir'].toString())
            : null,
        selisihTerakhirVsAvg: j['selisih_terakhir_vs_avg'] != null
            ? double.tryParse(j['selisih_terakhir_vs_avg'].toString())
            : null,
        tanggalBeliTerakhir: j['tanggal_beli_terakhir']?.toString(),
        jumlahMenuTerkait: int.tryParse((j['jumlah_menu_terkait'] ?? 0).toString()) ?? 0,
      );
}

class HppMenuReportModel {
  final int totalMenu;
  final int totalMenuBeresep;
  final int totalMenuTanpaResep;
  final double rataRataMarginPersen;
  final int jumlahMenuMarginTipis;
  final List<MenuHppItemModel> items;
  final List<BahanHargaMonitorModel> bahanMonitor;

  HppMenuReportModel({
    required this.totalMenu,
    required this.totalMenuBeresep,
    required this.totalMenuTanpaResep,
    required this.rataRataMarginPersen,
    required this.jumlahMenuMarginTipis,
    required this.items,
    required this.bahanMonitor,
  });

  factory HppMenuReportModel.fromJson(Map<String, dynamic> j) => HppMenuReportModel(
        totalMenu: int.tryParse((j['total_menu'] ?? 0).toString()) ?? 0,
        totalMenuBeresep: int.tryParse((j['total_menu_beresep'] ?? 0).toString()) ?? 0,
        totalMenuTanpaResep:
            int.tryParse((j['total_menu_tanpa_resep'] ?? 0).toString()) ?? 0,
        rataRataMarginPersen:
            double.tryParse((j['rata_rata_margin_persen'] ?? 0).toString()) ?? 0.0,
        jumlahMenuMarginTipis:
            int.tryParse((j['jumlah_menu_margin_tipis'] ?? 0).toString()) ?? 0,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => MenuHppItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        bahanMonitor: ((j['bahan_monitor'] as List?) ?? const [])
            .map((e) => BahanHargaMonitorModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ActionResult {
  final bool success;
  final String message;
  const ActionResult({required this.success, required this.message});
}

class ReportingProvider with ChangeNotifier {
  AuthProvider? _auth;

  bool _isLoading = false;
  ProfitReportModel? _profitReport;
  ExpenseBreakdownReportModel? _breakdownReport;
  List<PengeluaranModel> _pengeluaranList = [];
  List<KategoriPengeluaranModel> _kategoriList = [];
  List<StokMenipisItemModel> _stokMenipisList = [];
  HppMenuReportModel? _hppMenuReport;
  BarangMasukRekapResponse? _barangMasukRekap;

  bool get isLoading => _isLoading;
  ProfitReportModel? get profitReport => _profitReport;
  ExpenseBreakdownReportModel? get breakdownReport => _breakdownReport;
  List<PengeluaranModel> get pengeluaranList => _pengeluaranList;
  List<KategoriPengeluaranModel> get kategoriList => _kategoriList;
  List<KategoriPengeluaranModel> get activeKategoriList =>
      _kategoriList.where((k) => k.statusAktif).toList();
  List<StokMenipisItemModel> get stokMenipisList => _stokMenipisList;
  HppMenuReportModel? get hppMenuReport => _hppMenuReport;
  BarangMasukRekapResponse? get barangMasukRekap => _barangMasukRekap;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
  }

  Map<String, String> get _headers => _auth?.authHeaders ?? {};

  Future<void> loadAll({
    String filter = 'harian',
    String? tanggal,
    String? tanggalMulai,
    String? tanggalSelesai,
    String? bulan,
    int? tahun,
  }) async {
    if (_auth?.token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadProfitAndBreakdown(
          filter: filter,
          tanggal: tanggal,
          tanggalMulai: tanggalMulai,
          tanggalSelesai: tanggalSelesai,
          bulan: bulan,
          tahun: tahun,
          notify: false,
        ),
        loadPengeluaran(notify: false),
        loadKategori(notify: false),
        loadStokMenipis(notify: false),
        loadHppMenuReport(notify: false),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  (String?, String?) _resolvePeriodDateBounds({
    required String filter,
    String? tanggal,
    String? tanggalMulai,
    String? tanggalSelesai,
    String? bulan,
    int? tahun,
  }) {
    if (filter == 'harian' && tanggal != null && tanggal.isNotEmpty) {
      return (tanggal, tanggal);
    }
    if (filter == 'range') {
      return (tanggalMulai, tanggalSelesai);
    }
    if (filter == 'bulanan' && bulan != null && bulan.contains('-')) {
      final parts = bulan.split('-');
      if (parts.length >= 2) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y != null && m != null && m >= 1 && m <= 12) {
          final lastDay = DateTime(y, m + 1, 0).day;
          final mm = m.toString().padLeft(2, '0');
          final dd = lastDay.toString().padLeft(2, '0');
          return ('$y-$mm-01', '$y-$mm-$dd');
        }
      }
    }
    if (filter == 'tahunan' && tahun != null) {
      return ('$tahun-01-01', '$tahun-12-31');
    }
    return (null, null);
  }

  Future<void> loadProfitAndBreakdown({
    required String filter,
    String? tanggal,
    String? tanggalMulai,
    String? tanggalSelesai,
    String? bulan,
    int? tahun,
    bool notify = true,
  }) async {
    if (_auth?.token == null) return;
    if (notify) {
      _isLoading = true;
      notifyListeners();
    }

    final queryParams = <String, String>{'filter': filter};
    if (tanggal != null && tanggal.isNotEmpty) queryParams['tanggal'] = tanggal;
    if (tanggalMulai != null && tanggalMulai.isNotEmpty) queryParams['tanggal_mulai'] = tanggalMulai;
    if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) queryParams['tanggal_selesai'] = tanggalSelesai;
    if (bulan != null && bulan.isNotEmpty) queryParams['bulan'] = bulan;
    if (tahun != null) queryParams['tahun'] = tahun.toString();

    final (bmStart, bmEnd) = _resolvePeriodDateBounds(
      filter: filter,
      tanggal: tanggal,
      tanggalMulai: tanggalMulai,
      tanggalSelesai: tanggalSelesai,
      bulan: bulan,
      tahun: tahun,
    );

    try {
      final profitUri = Uri.parse(ApiEndpoints.profitPeriode).replace(queryParameters: queryParams);
      final breakdownUri = Uri.parse(ApiEndpoints.pengeluaranBreakdown).replace(queryParameters: queryParams);

      final responses = await Future.wait([
        http.get(profitUri, headers: _headers).timeout(const Duration(seconds: 10)),
        http.get(breakdownUri, headers: _headers).timeout(const Duration(seconds: 10)),
      ]);

      if (responses[0].statusCode == 200) {
        _profitReport = ProfitReportModel.fromJson(jsonDecode(responses[0].body));
      }
      if (responses[1].statusCode == 200) {
        _breakdownReport = ExpenseBreakdownReportModel.fromJson(jsonDecode(responses[1].body));
      }
      await loadBarangMasukRekap(
        tanggalMulai: bmStart ?? _profitReport?.periodeMulai,
        tanggalSelesai: bmEnd ?? _profitReport?.periodeSelesai,
        notify: false,
      );
    } catch (_) {
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadBarangMasukRekap({
    String? tanggalMulai,
    String? tanggalSelesai,
    String? area,
    bool notify = true,
  }) async {
    if (_auth?.token == null) return;
    try {
      final rekap = await fetchBarangMasukRekap(
        headers: _headers,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        area: area,
      );
      if (rekap != null) {
        _barangMasukRekap = rekap;
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }

  Future<void> loadPengeluaran({
    String? tipe,
    String? kategoriId,
    bool includeBarangMasuk = true,
    bool notify = true,
  }) async {
    if (_auth?.token == null) return;
    final queryParams = <String, String>{};
    if (tipe != null && tipe.isNotEmpty) queryParams['tipe'] = tipe;
    if (kategoriId != null && kategoriId.isNotEmpty) queryParams['kategori_id'] = kategoriId;
    if (includeBarangMasuk) queryParams['include_barang_masuk'] = 'true';

    try {
      final uri = Uri.parse(ApiEndpoints.pengeluaran).replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _pengeluaranList = list
            .map((e) => PengeluaranModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }

  Future<ActionResult> createPengeluaran({
    required String tipe,
    String? kategoriId,
    String? namaPengeluaran,
    required double nominal,
    String? bulan,
    String? tanggal,
    String? keterangan,
  }) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final body = <String, dynamic>{
        'tipe': tipe,
        'nominal': nominal,
      };
      if (kategoriId != null && kategoriId.trim().isNotEmpty) {
        body['kategori_id'] = kategoriId.trim();
      }
      if (namaPengeluaran != null && namaPengeluaran.trim().isNotEmpty) {
        body['nama_pengeluaran'] = namaPengeluaran.trim();
      }
      if (tipe == 'bulanan' && bulan != null && bulan.isNotEmpty) {
        body['bulan'] = bulan;
      }
      if (tipe == 'mendadak' && tanggal != null && tanggal.isNotEmpty) {
        body['tanggal'] = tanggal;
      }
      if (keterangan != null && keterangan.trim().isNotEmpty) {
        body['keterangan'] = keterangan.trim();
      }

      final resp = await http.post(
        Uri.parse(ApiEndpoints.pengeluaran),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await loadPengeluaran();
        return const ActionResult(success: true, message: 'Pengeluaran berhasil dicatat!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal mencatat pengeluaran',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<ActionResult> updatePengeluaran(
    String id, {
    String? tipe,
    String? kategoriId,
    String? namaPengeluaran,
    double? nominal,
    String? bulan,
    String? tanggal,
    String? keterangan,
  }) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final body = <String, dynamic>{};
      if (tipe != null) body['tipe'] = tipe;
      if (kategoriId != null) body['kategori_id'] = kategoriId;
      if (namaPengeluaran != null) body['nama_pengeluaran'] = namaPengeluaran;
      if (nominal != null) body['nominal'] = nominal;
      if (bulan != null) body['bulan'] = bulan;
      if (tanggal != null) body['tanggal'] = tanggal;
      if (keterangan != null) body['keterangan'] = keterangan;

      final resp = await http.put(
        Uri.parse('${ApiEndpoints.pengeluaran}/$id'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await loadPengeluaran();
        return const ActionResult(success: true, message: 'Pengeluaran berhasil diperbarui!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal memperbarui pengeluaran',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<ActionResult> deletePengeluaran(String id) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final resp = await http.delete(
        Uri.parse('${ApiEndpoints.pengeluaran}/$id'),
        headers: _headers,
      );
      if (resp.statusCode == 200) {
        await loadPengeluaran();
        return const ActionResult(success: true, message: 'Data pengeluaran berhasil dihapus!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal menghapus pengeluaran',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<void> loadKategori({bool includeNonaktif = true, bool notify = true}) async {
    if (_auth?.token == null) return;
    try {
      final uri = Uri.parse(ApiEndpoints.kategoriPengeluaran).replace(
        queryParameters: {'include_nonaktif': includeNonaktif.toString()},
      );
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _kategoriList = list
            .map((e) => KategoriPengeluaranModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }

  Future<ActionResult> createKategori(String nama) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final resp = await http.post(
        Uri.parse(ApiEndpoints.kategoriPengeluaran),
        headers: _headers,
        body: jsonEncode({'nama': nama.trim(), 'status_aktif': true}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await loadKategori();
        return const ActionResult(success: true, message: 'Kategori pengeluaran berhasil ditambahkan!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal menambahkan kategori',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<ActionResult> updateKategori(
    String id, {
    String? nama,
    bool? statusAktif,
  }) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final body = <String, dynamic>{};
      if (nama != null) body['nama'] = nama.trim();
      if (statusAktif != null) body['status_aktif'] = statusAktif;

      final resp = await http.put(
        Uri.parse('${ApiEndpoints.kategoriPengeluaran}/$id'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await loadKategori();
        return const ActionResult(success: true, message: 'Kategori pengeluaran berhasil diperbarui!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal memperbarui kategori',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<void> loadStokMenipis({bool notify = true}) async {
    if (_auth?.token == null) return;
    try {
      final resp = await http
          .get(Uri.parse(ApiEndpoints.stokMenipis), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _stokMenipisList = list
            .map((e) => StokMenipisItemModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }

  Future<void> loadHppMenuReport({
    String? area,
    bool includeNonaktif = false,
    bool notify = true,
  }) async {
    if (_auth?.token == null) return;
    try {
      final qp = <String, String>{};
      if (area != null && area.isNotEmpty && area != 'semua') qp['area'] = area;
      if (includeNonaktif) qp['include_nonaktif'] = 'true';
      final uri = Uri.parse(ApiEndpoints.hppMenu).replace(
        queryParameters: qp.isEmpty ? null : qp,
      );
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _hppMenuReport = HppMenuReportModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }
}
