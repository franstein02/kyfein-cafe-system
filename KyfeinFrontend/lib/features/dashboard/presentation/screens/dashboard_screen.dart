import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/admin_jadwal_screen.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/admin_absensi_screen.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/kasir_jadwal_screen.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/kasir_absensi_screen.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../pos/presentation/screens/pos_screen.dart';
import '../../../pos/presentation/screens/transaksi_screen.dart';
import '../../../master_data/presentation/screens/master_data_screen.dart';
import '../../../../core/services/firebase_messaging_service.dart';
import '../../../notifications/presentation/screens/notification_screen.dart';
import '../../../notifications/providers/notification_provider.dart';
import '../../../stok/presentation/screens/stok_gudang_screen.dart';
import '../../../stok/presentation/screens/catat_opname_screen.dart';
import '../../../stok/presentation/screens/stok_opname_hub_screen.dart';
import '../../../stok/presentation/widgets/opname_launcher.dart';
import '../../../stok/providers/stok_models.dart';
import '../../../reporting/presentation/screens/reporting_screen.dart';
import '../../../kds/presentation/screens/kds_screen.dart';
import '../widgets/admin_analytics_widgets.dart';

// ─── Formatters ───────────────────────────────────────────────────────────────
final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

// ─── Constants ────────────────────────────────────────────────────────────────
const _brown = Color(0xFF1B4332);

const _cream = Color(0xFFF6F8F6);
const _gold = Color(0xFFD4A373);
const _surface = Colors.white;
const _textDim = Color(0xFF7A7A7A);

// ─── Sidebar menu item models ─────────────────────────────────────────────────
class _NavSubItem {
  final String id;
  final IconData icon;
  final String label;
  final Widget Function(BuildContext) pageBuilder;

  const _NavSubItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.pageBuilder,
  });
}

class _NavItem {
  final String id;
  final IconData icon;
  final String label;
  final List<_NavSubItem> children;
  final Widget Function(BuildContext)? pageBuilder;

  const _NavItem({
    required this.id,
    required this.icon,
    required this.label,
    this.children = const [],
    this.pageBuilder,
  });
}

// ─── Dashboard Screen ─────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedGroupId = 'dashboard';
  String? _selectedSubId;
  String _activePageLabel = 'Dashboard';
  final Set<String> _expandedGroupIds = {
    'pos_group',
    'stok_group',
    'kasir_jadwal_group',
    'laporan_group',
  };
  Widget? _currentPage;
  bool _fcmInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fcmInitialized) {
        final auth = context.read<AuthProvider>();
        final notifProvider = context.read<NotificationProvider>();
        FirebaseMessagingService.init(notifProvider);
        if (auth.token != null) {
          FirebaseMessagingService.sendTokenToBackend(auth.token!);
        }
        _fcmInitialized = true;
      }
    });
  }

  List<_NavItem> _getNavItems(String? role, String? divisi, String? activeAreaKerja) {
    final isAdminOrOwner = role == 'admin' || role == 'owner';
    final isKaryawan = role == 'karyawan';
    final effectiveArea = (activeAreaKerja != null && activeAreaKerja.isNotEmpty)
        ? activeAreaKerja
        : ((divisi == 'bar' || divisi == 'kitchen' || divisi == 'kasir') ? divisi! : 'kasir');

    return [
      const _NavItem(
        id: 'dashboard',
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      if (isAdminOrOwner) ...[
        _NavItem(
          id: 'pos_group',
          icon: Icons.point_of_sale_rounded,
          label: 'Kasir & Pesanan',
          children: [
            _NavSubItem(
              id: 'pos_kasir',
              icon: Icons.storefront_rounded,
              label: 'Kasir POS',
              pageBuilder: (_) => const PosScreen(),
            ),
            _NavSubItem(
              id: 'pos_transaksi',
              icon: Icons.receipt_long_rounded,
              label: 'Riwayat Transaksi',
              pageBuilder: (_) => const TransaksiScreen(),
            ),
            _NavSubItem(
              id: 'pos_kds',
              icon: Icons.tv_rounded,
              label: 'Layar Pesanan KDS',
              pageBuilder: (_) => const KdsScreen(areaProduksi: 'all'),
            ),
          ],
        ),
        _NavItem(
          id: 'master_group',
          icon: Icons.restaurant_menu_rounded,
          label: 'Master Data',
          children: [
            _NavSubItem(
              id: 'master_menu',
              icon: Icons.fastfood_rounded,
              label: 'Menu & Resep POS',
              pageBuilder: (_) => const MasterDataScreen(
                key: ValueKey('master_0'),
                initialSection: 0,
              ),
            ),
            _NavSubItem(
              id: 'master_kategori',
              icon: Icons.category_rounded,
              label: 'Kategori Menu',
              pageBuilder: (_) => const MasterDataScreen(
                key: ValueKey('master_1'),
                initialSection: 1,
              ),
            ),
            _NavSubItem(
              id: 'master_bahan',
              icon: Icons.inventory_2_rounded,
              label: 'Master Bahan Baku',
              pageBuilder: (_) => const MasterDataScreen(
                key: ValueKey('master_2'),
                initialSection: 2,
              ),
            ),
            _NavSubItem(
              id: 'master_kasir',
              icon: Icons.badge_rounded,
              label: 'Kelola Karyawan',
              pageBuilder: (_) => const MasterDataScreen(
                key: ValueKey('master_3'),
                initialSection: 3,
              ),
            ),
          ],
        ),
        _NavItem(
          id: 'stok_group',
          icon: Icons.warehouse_rounded,
          label: 'Stok & Opname',
          children: [
            _NavSubItem(
              id: 'stok_gudang',
              icon: Icons.warehouse_rounded,
              label: 'Stok Gudang & Mutasi',
              pageBuilder: (_) => const StokGudangScreen(),
            ),
            _NavSubItem(
              id: 'opname_awal',
              icon: Icons.wb_sunny_rounded,
              label: 'Opname Awal Shift',
              pageBuilder: (_) => const CatatOpnameScreen(
                key: ValueKey('opname_0'),
                initialSection: 0,
              ),
            ),
            _NavSubItem(
              id: 'opname_akhir',
              icon: Icons.nights_stay_rounded,
              label: 'Opname Akhir Shift',
              pageBuilder: (_) => const CatatOpnameScreen(
                key: ValueKey('opname_1'),
                initialSection: 1,
              ),
            ),
            _NavSubItem(
              id: 'hub_harian',
              icon: Icons.calendar_view_day_rounded,
              label: 'Rekap Stok Harian',
              pageBuilder: (_) => const StokOpnameHubScreen(
                key: ValueKey('hub_0'),
                initialSection: 0,
              ),
            ),
            _NavSubItem(
              id: 'hub_audit',
              icon: Icons.fact_check_rounded,
              label: 'Audit Pemakaian BOM',
              pageBuilder: (_) => const StokOpnameHubScreen(
                key: ValueKey('hub_1'),
                initialSection: 1,
              ),
            ),
          ],
        ),
        _NavItem(
          id: 'jadwal_group',
          icon: Icons.calendar_month_rounded,
          label: 'Jadwal & Absensi',
          children: [
            _NavSubItem(
              id: 'adm_jadwal_atur',
              icon: Icons.edit_calendar_rounded,
              label: 'Atur Jadwal Shift',
              pageBuilder: (_) => const AdminJadwalScreen(
                key: ValueKey('adm_jadwal_0'),
                initialSection: 0,
              ),
            ),
            _NavSubItem(
              id: 'adm_jadwal_template',
              icon: Icons.tune_rounded,
              label: 'Template Shift',
              pageBuilder: (_) => const AdminJadwalScreen(
                key: ValueKey('adm_jadwal_2'),
                initialSection: 2,
              ),
            ),
            _NavSubItem(
              id: 'adm_jadwal_approval',
              icon: Icons.fact_check_rounded,
              label: 'Approval Izin & Off',
              pageBuilder: (_) => const AdminJadwalScreen(
                key: ValueKey('adm_jadwal_1'),
                initialSection: 1,
              ),
            ),
            _NavSubItem(
              id: 'adm_absensi_monitor',
              icon: Icons.fingerprint_rounded,
              label: 'Monitoring Absensi',
              pageBuilder: (_) => const AdminAbsensiScreen(
                key: ValueKey('adm_abs_1'),
                initialSection: 1,
              ),
            ),
            _NavSubItem(
              id: 'adm_absensi_lokasi',
              icon: Icons.location_on_rounded,
              label: 'Titik & Radius GPS',
              pageBuilder: (_) => const AdminAbsensiScreen(
                key: ValueKey('adm_abs_0'),
                initialSection: 0,
              ),
            ),
          ],
        ),
        _NavItem(
          id: 'laporan_group',
          icon: Icons.analytics_rounded,
          label: 'Laporan & Biaya',
          children: [
            _NavSubItem(
              id: 'rep_keuangan',
              icon: Icons.trending_up_rounded,
              label: 'Laba Rugi & Penjualan',
              pageBuilder: (_) => const ReportingScreen(
                key: ValueKey('rep_0'),
                initialSection: 0,
              ),
            ),
            _NavSubItem(
              id: 'rep_stok',
              icon: Icons.inventory_2_rounded,
              label: 'Laporan Stok & Opname',
              pageBuilder: (_) => const ReportingScreen(
                key: ValueKey('rep_1'),
                initialSection: 1,
              ),
            ),
            _NavSubItem(
              id: 'rep_absensi',
              icon: Icons.badge_rounded,
              label: 'Laporan Absensi',
              pageBuilder: (_) => const ReportingScreen(
                key: ValueKey('rep_2'),
                initialSection: 2,
              ),
            ),
            _NavSubItem(
              id: 'rep_pengeluaran',
              icon: Icons.receipt_long_rounded,
              label: 'Catat Pengeluaran',
              pageBuilder: (_) => const ReportingScreen(
                key: ValueKey('rep_3'),
                initialSection: 3,
              ),
            ),
            _NavSubItem(
              id: 'rep_kategori_biaya',
              icon: Icons.category_rounded,
              label: 'Kategori Biaya',
              pageBuilder: (_) => const ReportingScreen(
                key: ValueKey('rep_4'),
                initialSection: 4,
              ),
            ),
          ],
        ),
      ],
      if (isKaryawan) ...[
        if (effectiveArea == 'kasir') ...[
          _NavItem(
            id: 'pos_group',
            icon: Icons.point_of_sale_rounded,
            label: 'Kasir & Transaksi',
            children: [
              _NavSubItem(
                id: 'pos_kasir',
                icon: Icons.storefront_rounded,
                label: 'Kasir POS',
                pageBuilder: (_) => const PosScreen(),
              ),
              _NavSubItem(
                id: 'pos_transaksi',
                icon: Icons.receipt_long_rounded,
                label: 'Riwayat Transaksi',
                pageBuilder: (_) => const TransaksiScreen(),
              ),
            ],
          ),
          _NavItem(
            id: 'stok_group',
            icon: Icons.warehouse_rounded,
            label: 'Stok Gudang',
            children: [
              _NavSubItem(
                id: 'stok_gudang',
                icon: Icons.warehouse_rounded,
                label: 'Ambil Barang Gudang',
                pageBuilder: (_) => const StokGudangScreen(),
              ),
              _NavSubItem(
                id: 'hub_harian',
                icon: Icons.calendar_view_day_rounded,
                label: 'Rekap Stok Harian',
                pageBuilder: (_) => const StokOpnameHubScreen(
                  key: ValueKey('hub_kasir_0'),
                  initialSection: 0,
                ),
              ),
            ],
          ),
        ],
        if (effectiveArea == 'kitchen') ...[
          _NavItem(
            id: 'kds_kitchen',
            icon: Icons.soup_kitchen_rounded,
            label: 'Layar Pesanan KDS',
            pageBuilder: (_) => const KdsScreen(
              key: ValueKey('kds_kitchen'),
              areaProduksi: 'kitchen',
            ),
          ),
          _NavItem(
            id: 'stok_group',
            icon: Icons.warehouse_rounded,
            label: 'Stok & Opname Kitchen',
            children: [
              _NavSubItem(
                id: 'stok_gudang',
                icon: Icons.warehouse_rounded,
                label: 'Ambil Barang Gudang',
                pageBuilder: (_) => const StokGudangScreen(),
              ),
              _NavSubItem(
                id: 'opname_awal',
                icon: Icons.wb_sunny_rounded,
                label: 'Opname Awal Shift',
                pageBuilder: (_) => const CatatOpnameScreen(
                  key: ValueKey('opname_kitchen_0'),
                  initialSection: 0,
                  initialTitik: TitikStok.kitchen,
                ),
              ),
              _NavSubItem(
                id: 'opname_akhir',
                icon: Icons.nights_stay_rounded,
                label: 'Opname Akhir Shift',
                pageBuilder: (_) => const CatatOpnameScreen(
                  key: ValueKey('opname_kitchen_1'),
                  initialSection: 1,
                  initialTitik: TitikStok.kitchen,
                ),
              ),
              _NavSubItem(
                id: 'hub_harian',
                icon: Icons.calendar_view_day_rounded,
                label: 'Rekap Stok Harian',
                pageBuilder: (_) => const StokOpnameHubScreen(
                  key: ValueKey('hub_kitchen_0'),
                  initialSection: 0,
                ),
              ),
            ],
          ),
        ],
        if (effectiveArea == 'bar') ...[
          _NavItem(
            id: 'kds_bar',
            icon: Icons.local_cafe_rounded,
            label: 'Layar Pesanan KDS (Bar)',
            pageBuilder: (_) => const KdsScreen(
              key: ValueKey('kds_bar'),
              areaProduksi: 'bar',
            ),
          ),
          _NavItem(
            id: 'stok_group',
            icon: Icons.warehouse_rounded,
            label: 'Stok & Opname Bar',
            children: [
              _NavSubItem(
                id: 'stok_gudang',
                icon: Icons.warehouse_rounded,
                label: 'Ambil Barang Gudang',
                pageBuilder: (_) => const StokGudangScreen(),
              ),
              _NavSubItem(
                id: 'opname_awal',
                icon: Icons.wb_sunny_rounded,
                label: 'Opname Awal Shift',
                pageBuilder: (_) => const CatatOpnameScreen(
                  key: ValueKey('opname_bar_0'),
                  initialSection: 0,
                  initialTitik: TitikStok.bar,
                ),
              ),
              _NavSubItem(
                id: 'opname_akhir',
                icon: Icons.nights_stay_rounded,
                label: 'Opname Akhir Shift',
                pageBuilder: (_) => const CatatOpnameScreen(
                  key: ValueKey('opname_bar_1'),
                  initialSection: 1,
                  initialTitik: TitikStok.bar,
                ),
              ),
              _NavSubItem(
                id: 'hub_harian',
                icon: Icons.calendar_view_day_rounded,
                label: 'Rekap Stok Harian',
                pageBuilder: (_) => const StokOpnameHubScreen(
                  key: ValueKey('hub_bar_0'),
                  initialSection: 0,
                ),
              ),
            ],
          ),
        ],
        _NavItem(
          id: 'kasir_jadwal_group',
          icon: Icons.calendar_today_rounded,
          label: 'Jadwal & Absensi',
          children: [
            _NavSubItem(
              id: 'ksr_jadwal_saya',
              icon: Icons.calendar_month_rounded,
              label: 'Jadwal Kerja Saya',
              pageBuilder: (_) => const KasirJadwalScreen(
                key: ValueKey('ksr_jadwal_0'),
                initialSection: 0,
              ),
            ),
            _NavSubItem(
              id: 'ksr_pengajuan_izin',
              icon: Icons.assignment_turned_in_rounded,
              label: 'Pengajuan Izin & Off',
              pageBuilder: (_) => const KasirJadwalScreen(
                key: ValueKey('ksr_jadwal_1'),
                initialSection: 1,
              ),
            ),
            _NavSubItem(
              id: 'ksr_absensi_gps',
              icon: Icons.badge_rounded,
              label: 'Absensi Masuk & Pulang',
              pageBuilder: (_) => const KasirAbsensiScreen(),
            ),
          ],
        ),
      ],
    ];
  }

  void _onGroupTap(_NavItem item) {
    setState(() {
      if (item.children.isEmpty) {
        _selectedGroupId = item.id;
        _selectedSubId = null;
        _activePageLabel = item.label;
        _currentPage = item.pageBuilder?.call(context);
      } else {
        if (_expandedGroupIds.contains(item.id)) {
          _expandedGroupIds.remove(item.id);
        } else {
          _expandedGroupIds.add(item.id);
        }
      }
    });
  }

  void _onSubItemTap(_NavItem group, _NavSubItem sub) {
    setState(() {
      _selectedGroupId = group.id;
      _selectedSubId = sub.id;
      _activePageLabel = sub.label;
      _expandedGroupIds.add(group.id);
      _currentPage = sub.pageBuilder(context);
    });
  }

  void _navigateToNav(List<_NavItem> navItems, String groupId, [String? subId]) {
    for (final group in navItems) {
      if (group.id == groupId) {
        if (subId == null) {
          _onGroupTap(group);
          return;
        }
        for (final sub in group.children) {
          if (sub.id == subId) {
            _onSubItemTap(group, sub);
            return;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final navItems = _getNavItems(
      auth.role,
      auth.divisi,
      dashboard.shiftAktif?.areaKerja,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _WebLayout(
            auth: auth,
            dashboard: dashboard,
            navItems: navItems,
            selectedGroupId: _selectedGroupId,
            selectedSubId: _selectedSubId,
            expandedGroupIds: _expandedGroupIds,
            currentPage: _currentPage,
            onGroupTap: _onGroupTap,
            onSubItemTap: _onSubItemTap,
            onNavigate: (g, [s]) => _navigateToNav(navItems, g, s),
          );
        }
        return _MobileLayout(
          auth: auth,
          dashboard: dashboard,
          navItems: navItems,
          selectedGroupId: _selectedGroupId,
          selectedSubId: _selectedSubId,
          activePageLabel: _activePageLabel,
          expandedGroupIds: _expandedGroupIds,
          currentPage: _currentPage,
          onGroupTap: _onGroupTap,
          onSubItemTap: _onSubItemTap,
          onNavigate: (g, [s]) => _navigateToNav(navItems, g, s),
        );
      },
    );
  }
}

// ─── Web / Desktop Layout ─────────────────────────────────────────────────────
class _WebLayout extends StatelessWidget {
  final AuthProvider auth;
  final DashboardProvider dashboard;
  final List<_NavItem> navItems;
  final String selectedGroupId;
  final String? selectedSubId;
  final Set<String> expandedGroupIds;
  final Widget? currentPage;
  final ValueChanged<_NavItem> onGroupTap;
  final void Function(_NavItem, _NavSubItem) onSubItemTap;
  final void Function(String groupId, [String? subId]) onNavigate;

  const _WebLayout({
    required this.auth,
    required this.dashboard,
    required this.navItems,
    required this.selectedGroupId,
    required this.selectedSubId,
    required this.expandedGroupIds,
    required this.currentPage,
    required this.onGroupTap,
    required this.onSubItemTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────
          _Sidebar(
            auth: auth,
            activeAreaKerja: dashboard.shiftAktif?.areaKerja,
            navItems: navItems,
            selectedGroupId: selectedGroupId,
            selectedSubId: selectedSubId,
            expandedGroupIds: expandedGroupIds,
            onGroupTap: onGroupTap,
            onSubItemTap: onSubItemTap,
          ),
          // ── Main Content ─────────────────────────────────
          Expanded(
            child: currentPage ??
                _DashboardContent(
                  auth: auth,
                  dashboard: dashboard,
                  onNavigate: onNavigate,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final AuthProvider auth;
  final String? activeAreaKerja;
  final List<_NavItem> navItems;
  final String selectedGroupId;
  final String? selectedSubId;
  final Set<String> expandedGroupIds;
  final ValueChanged<_NavItem> onGroupTap;
  final void Function(_NavItem, _NavSubItem) onSubItemTap;

  const _Sidebar({
    required this.auth,
    this.activeAreaKerja,
    required this.navItems,
    required this.selectedGroupId,
    required this.selectedSubId,
    required this.expandedGroupIds,
    required this.onGroupTap,
    required this.onSubItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: _brown,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.coffee_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kyfein',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _roleBadge(
                        auth.role,
                        divisi: auth.divisi,
                        activeAreaKerja: activeAreaKerja,
                      ),
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // User info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _gold,
                    child: Text(
                      (auth.nama ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          color: _brown, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      auth.nama ?? 'User',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'MENU NAVIGASI',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // Nav items with expandable dropdown children
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (_, i) {
                final item = navItems[i];
                final hasChildren = item.children.isNotEmpty;
                final isGroupSelected = item.id == selectedGroupId;
                final isExpanded = expandedGroupIds.contains(item.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onGroupTap(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: (isGroupSelected && !hasChildren)
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : (isGroupSelected && hasChildren)
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon,
                                    color: isGroupSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 19),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isGroupSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 13.5,
                                      fontWeight: isGroupSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (hasChildren)
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white60,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (hasChildren && isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                          child: Column(
                            children: item.children.map((sub) {
                              final isSubSelected = sub.id == selectedSubId;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => onSubItemTap(item, sub),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isSubSelected
                                            ? Colors.white.withValues(alpha: 0.18)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sub.icon,
                                            size: 16,
                                            color: isSubSelected
                                                ? _gold
                                                : Colors.white54,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              sub.label,
                                              style: TextStyle(
                                                color: isSubSelected
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontSize: 12.5,
                                                fontWeight: isSubSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => auth.logout(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.white54, size: 20),
                      SizedBox(width: 12),
                      Text('Logout',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

String _roleBadge(String? role, {String? divisi, String? activeAreaKerja}) {
  switch (role) {
    case 'owner':
      return '★ OWNER';
    case 'admin':
      return '⚙ ADMIN';
    case 'karyawan':
      final area = (activeAreaKerja != null && activeAreaKerja.isNotEmpty)
          ? activeAreaKerja
          : divisi;
      switch (area) {
        case 'kitchen':
          return '🍳 KITCHEN';
        case 'bar':
          return '☕ BAR / BARISTA';
        case 'kasir':
          return '🧾 KASIR';
        default:
          return '👤 KARYAWAN';
      }
    default:
      return role?.toUpperCase() ?? '';
  }
}

// ─── Main Dashboard Content Area ─────────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final AuthProvider auth;
  final DashboardProvider dashboard;
  final void Function(String groupId, [String? subId]) onNavigate;

  const _DashboardContent({
    required this.auth,
    required this.dashboard,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (dashboard.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _brown),
      );
    }

    return RefreshIndicator(
      color: _brown,
      onRefresh: dashboard.refresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _cream,
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingText(),
                  style: const TextStyle(
                      color: _textDim, fontSize: 13, fontWeight: FontWeight.w400),
                ),
                Text(
                  auth.nama ?? 'User',
                  style: GoogleFonts.outfit(
                    color: _brown,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _brown),
                onPressed: dashboard.refresh,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            sliver: SliverToBoxAdapter(
              child: _buildRoleContent(context),
            ),
          ),
        ],
      ),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  Widget _buildRoleContent(BuildContext context) {
    switch (auth.role) {
      case 'karyawan':
        return _KaryawanContent(
          auth: auth,
          dashboard: dashboard,
          onNavigate: onNavigate,
        );
      case 'admin':
        return _AdminContent(dashboard: dashboard);
      case 'owner':
        return _OwnerContent(dashboard: dashboard);
      default:
        return const Center(child: Text('Role tidak dikenali'));
    }
  }
}

// ─── Karyawan Dashboard Content ───────────────────────────────────────────────
class _KaryawanContent extends StatelessWidget {
  final AuthProvider auth;
  final DashboardProvider dashboard;
  final void Function(String groupId, [String? subId]) onNavigate;

  const _KaryawanContent({
    required this.auth,
    required this.dashboard,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveArea = dashboard.shiftAktif?.areaKerja ?? auth.divisiEfektif;
    final isKasir = effectiveArea == 'kasir';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shift card
        _ShiftCard(shift: dashboard.shiftAktif),
        const SizedBox(height: 20),
        // Quick actions
        const _SectionTitle('Aksi Cepat'),
        const SizedBox(height: 12),
        if (dashboard.shiftAktif != null)
          _QuickActions(
            shift: dashboard.shiftAktif!,
            onNavigate: onNavigate,
          )
        else
          _NoShiftQuickActions(
            effectiveArea: effectiveArea,
            onNavigate: onNavigate,
          ),
        const SizedBox(height: 20),
        if (isKasir) ...[
          const _SectionTitle('Laporan Shift Aktif'),
          const SizedBox(height: 12),
          _LaporanShiftCard(laporan: dashboard.laporanShift),
        ] else ...[
          _SectionTitle(
            effectiveArea == 'kitchen' ? 'Ruang Kerja Kitchen' : 'Ruang Kerja Bar',
          ),
          const SizedBox(height: 12),
          _ProduksiFocusCard(
            area: effectiveArea,
            onOpenKds: () => onNavigate(
              effectiveArea == 'kitchen' ? 'kds_kitchen' : 'kds_bar',
            ),
            onOpenStok: () => onNavigate('stok_group', 'stok_gudang'),
            onOpenAbsensi: () => onNavigate('kasir_jadwal_group', 'ksr_absensi_gps'),
          ),
        ],
        const SizedBox(height: 20),
        // Notifikasi
        const _SectionTitle('Notifikasi'),
        const SizedBox(height: 12),
        _EmptyNotifCard(),
      ],
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ShiftAktif? shift;
  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    if (shift == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded,
                  color: Colors.grey, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tidak ada jadwal hari ini',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Hubungi admin untuk informasi jadwal',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C3D2E), _brown],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _brown.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        color: Color(0xFF4ADE80), size: 8),
                    const SizedBox(width: 6),
                    Text(
                      'Shift Aktif',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                () {
                  try {
                    return DateFormat('EEEE, d MMM', 'id_ID').format(DateTime.now());
                  } catch (_) {
                    return DateFormat('EEEE, d MMM').format(DateTime.now());
                  }
                }(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            shift!.shift.replaceAll('_', ' ').toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ShiftChip(
                  icon: Icons.access_time_rounded,
                  label: '${shift!.jamMulai} – ${shift!.jamSelesai}'),
              const SizedBox(width: 8),
              _ShiftChip(
                  icon: Icons.place_rounded,
                  label: shift!.areaKerja.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ShiftChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ShiftAktif shift;
  final void Function(String groupId, [String? subId]) onNavigate;

  const _QuickActions({
    required this.shift,
    required this.onNavigate,
  });

  Future<void> _jalankanOpname(BuildContext context, TipeOpname tipe) async {
    final dashboard = context.read<DashboardProvider>();
    final ok = await bukaOpname(context, areaKerja: shift.areaKerja, tipe: tipe);
    if (ok) await dashboard.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isProduksi = shift.areaKerja == 'bar' || shift.areaKerja == 'kitchen';
    final isKitchen = shift.areaKerja == 'kitchen';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.fingerprint_rounded,
          label: shift.sudahAbsenMasuk && !shift.sudahAbsenPulang ? 'Absen Pulang' : 'Absen Masuk',
          color: shift.sudahAbsenMasuk && !shift.sudahAbsenPulang ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KasirAbsensiScreen()),
            );
            if (context.mounted) {
              context.read<DashboardProvider>().refresh();
            }
          },
        ),
        if (isProduksi)
          if (!shift.opnameAwalSubmit)
            _ActionButton(
              icon: Icons.inventory_2_rounded,
              label: 'Opname Awal Shift',
              color: const Color(0xFFF59E0B),
              onTap: () => _jalankanOpname(context, TipeOpname.awalShift),
            )
          else
            _ActionButton(
              icon: Icons.inventory_2_rounded,
              label: 'Opname Akhir Shift',
              color: const Color(0xFFF59E0B),
              onTap: () => _jalankanOpname(context, TipeOpname.akhirShift),
            ),
        if (shift.areaKerja == 'kasir')
          _ActionButton(
            icon: Icons.point_of_sale_rounded,
            label: 'Buka POS',
            color: _brown,
            onTap: () => onNavigate('pos_group', 'pos_kasir'),
          ),
        if (isProduksi)
          _ActionButton(
            icon: isKitchen ? Icons.soup_kitchen_rounded : Icons.local_cafe_rounded,
            label: isKitchen ? 'Buka KDS Kitchen' : 'Buka KDS Bar',
            color: const Color(0xFF6366F1),
            onTap: () => onNavigate(isKitchen ? 'kds_kitchen' : 'kds_bar'),
          ),
      ],
    );
  }
}

class _NoShiftQuickActions extends StatelessWidget {
  final String effectiveArea;
  final void Function(String groupId, [String? subId]) onNavigate;

  const _NoShiftQuickActions({
    required this.effectiveArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isKitchen = effectiveArea == 'kitchen';
    final isBar = effectiveArea == 'bar';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.fingerprint_rounded,
          label: 'Absensi GPS',
          color: const Color(0xFF10B981),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KasirAbsensiScreen()),
            );
            if (context.mounted) {
              context.read<DashboardProvider>().refresh();
            }
          },
        ),
        _ActionButton(
          icon: Icons.calendar_month_rounded,
          label: 'Jadwal Kerja Saya',
          color: _brown,
          onTap: () => onNavigate('kasir_jadwal_group', 'ksr_jadwal_saya'),
        ),
        if (isKitchen || isBar)
          _ActionButton(
            icon: isKitchen ? Icons.soup_kitchen_rounded : Icons.local_cafe_rounded,
            label: isKitchen ? 'Buka KDS Kitchen' : 'Buka KDS Bar',
            color: const Color(0xFF6366F1),
            onTap: () => onNavigate(isKitchen ? 'kds_kitchen' : 'kds_bar'),
          )
        else
          _ActionButton(
            icon: Icons.point_of_sale_rounded,
            label: 'Buka POS',
            color: _brown,
            onTap: () => onNavigate('pos_group', 'pos_kasir'),
          ),
      ],
    );
  }
}

class _ProduksiFocusCard extends StatelessWidget {
  final String area;
  final VoidCallback onOpenKds;
  final VoidCallback onOpenStok;
  final VoidCallback onOpenAbsensi;

  const _ProduksiFocusCard({
    required this.area,
    required this.onOpenKds,
    required this.onOpenStok,
    required this.onOpenAbsensi,
  });

  @override
  Widget build(BuildContext context) {
    final isKitchen = area == 'kitchen';
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isKitchen ? Icons.soup_kitchen_rounded : Icons.local_cafe_rounded,
                    color: _brown,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKitchen ? 'Fokus Operasional Kitchen' : 'Fokus Operasional Bar',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isKitchen
                            ? 'Pantau antrian masak realtime di KDS Kitchen, stok bahan dapur, serta jadwal & absensi.'
                            : 'Pantau antrian minuman di KDS Bar, stok bahan bar, serta jadwal & absensi.',
                        style: const TextStyle(fontSize: 12.5, color: _textDim),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenKds,
                  icon: const Icon(Icons.tv_rounded, size: 17),
                  label: Text(isKitchen ? 'Antrian KDS Kitchen' : 'Antrian KDS Bar'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenStok,
                  icon: const Icon(Icons.warehouse_rounded, size: 17),
                  label: const Text('Ambil Barang Gudang'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenAbsensi,
                  icon: const Icon(Icons.fingerprint_rounded, size: 17),
                  label: const Text('Halaman Absensi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaporanShiftCard extends StatelessWidget {
  final LaporanShift? laporan;
  const _LaporanShiftCard({required this.laporan});

  @override
  Widget build(BuildContext context) {
    if (laporan == null) {
      return const _Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Data laporan tidak tersedia',
                style: TextStyle(color: _textDim)),
          ),
        ),
      );
    }

    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(
                label: 'Total Pendapatan',
                value: _idr.format(laporan!.totalPendapatan),
                valueColor: _brown,
                large: true),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatRow(
                      label: 'Transaksi',
                      value: '${laporan!.jumlahTransaksi}x'),
                ),
                Expanded(
                  child: _StatRow(
                      label: 'Cash',
                      value: _idr.format(laporan!.totalCash)),
                ),
                Expanded(
                  child: _StatRow(
                      label: 'QRIS',
                      value: _idr.format(laporan!.totalQris)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.notifications_none_rounded,
                color: Colors.grey, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak ada notifikasi baru',
                style: TextStyle(color: _textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin Dashboard Content ──────────────────────────────────────────────────
class _AdminContent extends StatelessWidget {
  final DashboardProvider dashboard;
  const _AdminContent({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPeriodFilterBar(dashboard: dashboard),
        const SizedBox(height: 16),
        AdminKpiSection(dashboard: dashboard),
        const SizedBox(height: 16),
        AdminSalesChartCard(dashboard: dashboard),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AdminEmployeeBehaviorCard(dashboard: dashboard),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                            'Approval Menunggu (${dashboard.pendingApprovals.length})'),
                        const SizedBox(height: 12),
                        _ApprovalCard(items: dashboard.pendingApprovals),
                        const SizedBox(height: 20),
                        _SectionTitle(
                            'Stok Menipis (${dashboard.stokMenipis.length})'),
                        const SizedBox(height: 12),
                        _StokMenipisCard(items: dashboard.stokMenipis),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminEmployeeBehaviorCard(dashboard: dashboard),
                const SizedBox(height: 20),
                _SectionTitle(
                    'Stok Menipis (${dashboard.stokMenipis.length})'),
                const SizedBox(height: 12),
                _StokMenipisCard(items: dashboard.stokMenipis),
                const SizedBox(height: 20),
                _SectionTitle(
                    'Approval Menunggu (${dashboard.pendingApprovals.length})'),
                const SizedBox(height: 12),
                _ApprovalCard(items: dashboard.pendingApprovals),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StokMenipisCard extends StatelessWidget {
  final List<StokMenipis> items;
  const _StokMenipisCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Semua stok aman',
                    style: TextStyle(color: _textDim)),
              ),
            ],
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        children: items
            .map((s) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.warning_rounded,
                        color: Colors.red.shade400, size: 18),
                  ),
                  title: Text(s.namaBahan,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Sisa: ${s.jumlahSisa} ${s.satuan} (min: ${s.stokMinimum})',
                    style: const TextStyle(fontSize: 12, color: _textDim),
                  ),
                  dense: true,
                ))
            .toList(),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final List<PendingApproval> items;
  const _ApprovalCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Tidak ada approval menunggu',
                    style: TextStyle(color: _textDim)),
              ),
            ],
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        children: items
            .map((p) => _ApprovalTile(item: p))
            .toList(),
      ),
    );
  }
}

class _ApprovalTile extends StatefulWidget {
  final PendingApproval item;
  const _ApprovalTile({required this.item});

  @override
  State<_ApprovalTile> createState() => _ApprovalTileState();
}

class _ApprovalTileState extends State<_ApprovalTile> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.read<DashboardProvider>();
    return ListTile(
      leading: _typeIcon(widget.item.type),
      title: Text(widget.item.namaKaryawan,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${_typeLabel(widget.item.type)} · ${widget.item.tanggal}${widget.item.keterangan.isNotEmpty ? '\nAlasan: ${widget.item.keterangan}' : ''}',
        style: const TextStyle(fontSize: 12, color: _textDim),
      ),
      dense: true,
      trailing: _processing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 22),
                  onPressed: () async {
                    setState(() => _processing = true);
                    await dashboard.approveItem(
                        widget.item.id, widget.item.type);
                    if (mounted) setState(() => _processing = false);
                  },
                  tooltip: 'Approve',
                ),
                IconButton(
                  icon: Icon(Icons.cancel_rounded,
                      color: Colors.red.shade400, size: 22),
                  onPressed: () async {
                    setState(() => _processing = true);
                    await dashboard.rejectItem(
                        widget.item.id, widget.item.type);
                    if (mounted) setState(() => _processing = false);
                  },
                  tooltip: 'Tolak',
                ),
              ],
            ),
    );
  }

  Widget _typeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'swap_shift':
        icon = Icons.swap_horiz_rounded;
        color = const Color(0xFF6366F1);
        break;
      case 'izin_telat':
        icon = Icons.access_time_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'request_off':
        icon = Icons.event_busy_rounded;
        color = Colors.deepOrange;
        break;
      default:
        icon = Icons.beach_access_rounded;
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'swap_shift':
        return 'Tukar Shift';
      case 'izin_telat':
        return 'Izin Telat';
      case 'izin_tidak_masuk':
        return 'Izin Tidak Masuk';
      case 'request_off':
        return 'Request Off (Libur)';
      default:
        return type;
    }
  }
}

// ─── Owner Dashboard Content ──────────────────────────────────────────────────
class _OwnerContent extends StatelessWidget {
  final DashboardProvider dashboard;
  const _OwnerContent({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Same as admin
        _AdminContent(dashboard: dashboard),
        const SizedBox(height: 24),
        // Owner-only: Role management card
        const _SectionTitle('Manajemen Role'),
        const SizedBox(height: 12),
        _RoleManagementCard(),
      ],
    );
  }
}

class _RoleManagementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kelola Akses Akun',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
                'Buat akun admin baru, promote karyawan, atau nonaktifkan akun admin.',
                style: TextStyle(fontSize: 13, color: _textDim)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ActionButton(
                  icon: Icons.person_add_rounded,
                  label: 'Buat Akun Admin',
                  color: _brown,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Fitur buat akun admin — coming soon')),
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.upgrade_rounded,
                  label: 'Promote Karyawan',
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Fitur promote karyawan — coming soon')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mobile Layout ────────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final AuthProvider auth;
  final DashboardProvider dashboard;
  final List<_NavItem> navItems;
  final String selectedGroupId;
  final String? selectedSubId;
  final String activePageLabel;
  final Set<String> expandedGroupIds;
  final Widget? currentPage;
  final ValueChanged<_NavItem> onGroupTap;
  final void Function(_NavItem, _NavSubItem) onSubItemTap;
  final void Function(String groupId, [String? subId]) onNavigate;

  const _MobileLayout({
    required this.auth,
    required this.dashboard,
    required this.navItems,
    required this.selectedGroupId,
    required this.selectedSubId,
    required this.activePageLabel,
    required this.expandedGroupIds,
    required this.currentPage,
    required this.onGroupTap,
    required this.onSubItemTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activePageLabel,
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${auth.nama ?? 'User'} · ${_roleBadge(auth.role, divisi: auth.divisi, activeAreaKerja: dashboard.shiftAktif?.areaKerja)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProv, _) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationScreen()),
                      );
                    },
                  ),
                  if (notifProv.hasUnread ||
                      (auth.role == 'admin' &&
                          (dashboard.adminSummary?.pendingApprovals ?? 0) > 0))
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: StatefulBuilder(
          builder: (drawerCtx, setDrawerState) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  decoration: const BoxDecoration(color: _brown),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _gold,
                        child: Text(
                          (auth.nama ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: _brown,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.nama ?? 'User',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _roleBadge(
                                auth.role,
                                divisi: auth.divisi,
                                activeAreaKerja: dashboard.shiftAktif?.areaKerja,
                              ),
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    itemCount: navItems.length,
                    itemBuilder: (_, i) {
                      final item = navItems[i];
                      final hasChildren = item.children.isNotEmpty;
                      final isGroupSelected = item.id == selectedGroupId;
                      final isExpanded = expandedGroupIds.contains(item.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (!hasChildren) {
                                    Navigator.pop(context);
                                    onGroupTap(item);
                                  } else {
                                    onGroupTap(item);
                                    setDrawerState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: (isGroupSelected && !hasChildren)
                                        ? _brown.withValues(alpha: 0.1)
                                        : (isGroupSelected && hasChildren)
                                            ? _brown.withValues(alpha: 0.05)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: 20,
                                        color: isGroupSelected
                                            ? _brown
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: isGroupSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isGroupSelected
                                                ? _brown
                                                : const Color(0xFF2D312E),
                                          ),
                                        ),
                                      ),
                                      if (hasChildren)
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons
                                                  .keyboard_arrow_down_rounded,
                                          size: 20,
                                          color: isGroupSelected
                                              ? _brown
                                              : Colors.grey.shade500,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (hasChildren && isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 18, top: 4, bottom: 4),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                          color: Color(0xFFE5EBE7), width: 2),
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Column(
                                    children: item.children.map((sub) {
                                      final isSubSelected =
                                          sub.id == selectedSubId;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () {
                                              Navigator.pop(context);
                                              onSubItemTap(item, sub);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isSubSelected
                                                    ? _brown.withValues(
                                                        alpha: 0.1)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    sub.icon,
                                                    size: 17,
                                                    color: isSubSelected
                                                        ? _brown
                                                        : Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      sub.label,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            isSubSelected
                                                                ? FontWeight
                                                                    .w700
                                                                : FontWeight
                                                                    .w500,
                                                        color: isSubSelected
                                                            ? _brown
                                                            : Colors
                                                                .grey.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5EBE7)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.logout_rounded,
                        color: Colors.red.shade700, size: 20),
                    title: Text(
                      'Keluar Akun (Logout)',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                    onTap: () => auth.logout(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: currentPage ??
          _DashboardContent(
            auth: auth,
            dashboard: dashboard,
            onNavigate: onNavigate,
          ),
    );
  }
}

// ─── Shared UI helpers ────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE7)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1A1A),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool large;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: _textDim, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: large ? 22 : 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

