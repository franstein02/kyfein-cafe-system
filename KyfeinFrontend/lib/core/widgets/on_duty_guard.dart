import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../features/attendance/presentation/screens/kasir_absensi_screen.dart';
import '../../features/attendance/presentation/screens/kasir_jadwal_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

/// Penjaga akses layar operasional (POS, KDS, Stok Gudang, Stok Opname, Rekap Stok).
/// - Admin/Owner selalu diizinkan masuk.
/// - Karyawan wajib memiliki jadwal shift aktif hari ini, sudah Absen Masuk, dan belum Absen Pulang.
/// - Jika [allowedAreas] ditentukan, area_kerja shift aktif juga harus cocok.
class OnDutyGuard extends StatelessWidget {
  final Widget child;
  final String featureName;
  final List<String>? allowedAreas;

  const OnDutyGuard({
    super.key,
    required this.child,
    required this.featureName,
    this.allowedAreas,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.role != 'karyawan') {
      return child;
    }

    DashboardProvider? dashboard;
    try {
      dashboard = context.watch<DashboardProvider>();
    } catch (_) {
      return child;
    }

    final shift = dashboard.shiftAktif;
    final bool isOnDuty = dashboard.isOnDuty;

    String? blockTitle;
    String? blockDescription;
    IconData blockIcon = Icons.lock_clock_rounded;
    Color accentColor = const Color(0xFFB45309);

    if (!isOnDuty) {
      if (shift == null) {
        blockTitle = 'Sedang Off-Shift / Libur';
        blockDescription =
            'Akses ke "$featureName" dikunci karena Anda tidak memiliki jadwal shift aktif saat ini. Periksa jadwal kerja Anda atau hubungi Admin.';
        blockIcon = Icons.event_busy_rounded;
        accentColor = Colors.grey.shade700;
      } else if (!shift.sudahAbsenMasuk) {
        blockTitle = 'Absen Masuk Diperlukan';
        blockDescription =
            'Shift Anda (${shift.shiftNama ?? shift.shift.replaceAll('_', ' ').toUpperCase()} · ${shift.jamMulai}–${shift.jamSelesai}) sudah terjadwal, namun Anda wajib melakukan Absen Masuk terlebih dahulu sebelum membuka "$featureName".';
        blockIcon = Icons.fingerprint_rounded;
        accentColor = const Color(0xFFD97706);
      } else if (shift.sudahAbsenPulang) {
        blockTitle = 'Shift Anda Sudah Selesai';
        blockDescription =
            'Anda sudah melakukan Absen Pulang pada shift ini sehingga akses ke "$featureName" kembali dikunci.';
        blockIcon = Icons.check_circle_outline_rounded;
        accentColor = const Color(0xFF1B4332);
      }
    } else if (allowedAreas != null &&
        allowedAreas!.isNotEmpty &&
        shift != null &&
        !allowedAreas!.contains(shift.areaKerja.toLowerCase())) {
      blockTitle = 'Area Kerja Tidak Sesuai';
      blockDescription =
          'Fitur "$featureName" hanya dapat diakses saat bertugas di area ${allowedAreas!.map((e) => e.toUpperCase()).join(" / ")}. Shift aktif Anda saat ini di area ${shift.areaKerja.toUpperCase()}.';
      blockIcon = Icons.block_rounded;
      accentColor = Colors.red.shade700;
    }

    if (blockTitle == null) {
      return child;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(blockIcon, size: 40, color: accentColor),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    blockTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1D1B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    blockDescription!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (shift != null && !shift.sudahAbsenMasuk)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.fingerprint_rounded, size: 18),
                          label: const Text('Buka Absensi Masuk'),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const KasirAbsensiScreen(),
                              ),
                            );
                            if (context.mounted) {
                              await context.read<DashboardProvider>().refresh();
                            }
                          },
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: const Text('Lihat Jadwal Saya'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const KasirJadwalScreen(),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        onPressed: () => dashboard?.refresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Muat Ulang Status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
