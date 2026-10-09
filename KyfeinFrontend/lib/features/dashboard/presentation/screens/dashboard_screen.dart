import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../pos/presentation/screens/pos_screen.dart';
import '../../../master_data/presentation/screens/master_data_screen.dart';

// ─── Formatters ───────────────────────────────────────────────────────────────
final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

// ─── Constants ────────────────────────────────────────────────────────────────
const _brown = Color(0xFF1B4332);

const _cream = Color(0xFFE9F5E6);
const _gold = Color(0xFFD4A373);
const _surface = Colors.white;
const _textDim = Color(0xFF7A7A7A);

// ─── Sidebar menu item model ──────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final Widget Function(BuildContext)? pageBuilder;

  const _NavItem(this.icon, this.label, {this.pageBuilder});
}

// ─── Dashboard Screen ─────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Widget? _currentPage;

  List<_NavItem> _getNavItems(String? role) {
    return [
      const _NavItem(Icons.dashboard_rounded, 'Dashboard'),
      _NavItem(Icons.point_of_sale_rounded, 'POS',
          pageBuilder: (_) => const PosScreen()),
      _NavItem(Icons.restaurant_menu_rounded, 'Master Data',
          pageBuilder: (_) => const MasterDataScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final navItems = _getNavItems(auth.role);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _WebLayout(
            auth: auth,
            dashboard: dashboard,
            navItems: navItems,
            selectedIndex: _selectedIndex,
            currentPage: _currentPage,
            onNavTap: (i) {
              setState(() {
                _selectedIndex = i;
                final item = navItems[i];
                _currentPage = item.pageBuilder != null
                    ? item.pageBuilder!(context)
                    : null;
              });
            },
          );
        }
        return _MobileLayout(
          auth: auth,
          dashboard: dashboard,
          navItems: navItems,
          selectedIndex: _selectedIndex,
          currentPage: _currentPage,
          onNavTap: (i) {
            setState(() {
              _selectedIndex = i;
              final item = navItems[i];
              _currentPage = item.pageBuilder != null
                  ? item.pageBuilder!(context)
                  : null;
            });
          },
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
  final int selectedIndex;
  final Widget? currentPage;
  final ValueChanged<int> onNavTap;

  const _WebLayout({
    required this.auth,
    required this.dashboard,
    required this.navItems,
    required this.selectedIndex,
    required this.currentPage,
    required this.onNavTap,
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
            navItems: navItems,
            selectedIndex: selectedIndex,
            onNavTap: onNavTap,
          ),
          // ── Main Content ─────────────────────────────────
          Expanded(
            child: currentPage ??
                _DashboardContent(auth: auth, dashboard: dashboard),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final AuthProvider auth;
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;

  const _Sidebar({
    required this.auth,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C3D2E), _brown],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.coffee_rounded,
                      color: Colors.white, size: 24),
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
                      _roleBadge(auth.role),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
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
              'MENU',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: navItems.length,
              itemBuilder: (_, i) {
                final item = navItems[i];
                final isSelected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onNavTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(item.icon,
                                color: isSelected ? Colors.white : Colors.white60,
                                size: 20),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

String _roleBadge(String? role) {
  switch (role) {
    case 'owner':
      return '★ OWNER';
    case 'admin':
      return '⚙ ADMIN';
    case 'karyawan':
      return '☕ BARISTA';
    default:
      return role?.toUpperCase() ?? '';
  }
}

// ─── Main Dashboard Content Area ─────────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final AuthProvider auth;
  final DashboardProvider dashboard;

  const _DashboardContent({required this.auth, required this.dashboard});

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
        return _KaryawanContent(dashboard: dashboard);
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
  final DashboardProvider dashboard;
  const _KaryawanContent({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shift card
        _ShiftCard(shift: dashboard.shiftAktif),
        const SizedBox(height: 20),
        // Quick actions
        if (dashboard.shiftAktif != null) ...[
          const _SectionTitle('Aksi Cepat'),
          const SizedBox(height: 12),
          _QuickActions(shift: dashboard.shiftAktif!),
          const SizedBox(height: 20),
        ],
        // Laporan shift
        const _SectionTitle('Laporan Shift Aktif'),
        const SizedBox(height: 12),
        _LaporanShiftCard(laporan: dashboard.laporanShift),
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
                DateFormat('EEEE, d MMM', 'id_ID')
                    .format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            shift!.shift.toUpperCase(),
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
  const _QuickActions({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.fingerprint_rounded,
          label: 'Absen Masuk',
          color: const Color(0xFF10B981),
          onTap: () {},
        ),
        _ActionButton(
          icon: Icons.inventory_2_rounded,
          label: 'Opname Awal Shift',
          color: const Color(0xFFF59E0B),
          onTap: () {},
        ),
        if (shift.areaKerja == 'kasir')
          _ActionButton(
            icon: Icons.point_of_sale_rounded,
            label: 'Buka POS',
            color: _brown,
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PosScreen()));
            },
          ),
        if (shift.areaKerja == 'bar' || shift.areaKerja == 'kitchen')
          _ActionButton(
            icon: Icons.kitchen_rounded,
            label: 'Buka KDS',
            color: const Color(0xFF6366F1),
            onTap: () {},
          ),
      ],
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
            Text('Tidak ada notifikasi baru',
                style: TextStyle(color: _textDim)),
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
        // Summary cards row
        _SummaryCards(summary: dashboard.adminSummary),
        const SizedBox(height: 24),
        // Two-column layout for stok + approvals
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const _SectionTitle('Stok Menipis'),
                        const SizedBox(height: 12),
                        _StokMenipisCard(items: dashboard.stokMenipis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        const _SectionTitle('Approval Menunggu'),
                        const SizedBox(height: 12),
                        _ApprovalCard(items: dashboard.pendingApprovals),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Stok Menipis'),
                const SizedBox(height: 12),
                _StokMenipisCard(items: dashboard.stokMenipis),
                const SizedBox(height: 20),
                const _SectionTitle('Approval Menunggu'),
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

class _SummaryCards extends StatelessWidget {
  final AdminSummary? summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final isMobile = MediaQuery.of(context).size.width < 700;
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 1.6,
      children: [
        _SummaryCard(
          label: 'Total Penjualan',
          value: _idr.format(s?.totalPenjualan ?? 0),
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF10B981),
        ),
        _SummaryCard(
          label: 'Profit Harian',
          value: _idr.format(s?.profitHarian ?? 0),
          icon: Icons.savings_rounded,
          color: const Color(0xFF6366F1),
        ),
        _SummaryCard(
          label: 'Transaksi',
          value: '${s?.jumlahTransaksi ?? 0}',
          icon: Icons.receipt_rounded,
          color: _brown,
        ),
        _SummaryCard(
          label: 'Approval Pending',
          value: '${s?.pendingApprovals ?? 0}',
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
              Text('Semua stok aman', style: TextStyle(color: _textDim)),
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
              Text('Tidak ada approval menunggu',
                  style: TextStyle(color: _textDim)),
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
        '${_typeLabel(widget.item.type)} · ${widget.item.tanggal}',
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
  final int selectedIndex;
  final Widget? currentPage;
  final ValueChanged<int> onNavTap;

  const _MobileLayout({
    required this.auth,
    required this.dashboard,
    required this.navItems,
    required this.selectedIndex,
    required this.currentPage,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(auth.nama ?? 'User',
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text(_roleBadge(auth.role),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          if (auth.role == 'admin' || auth.role == 'owner')
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                    icon: const Icon(Icons.notifications_rounded),
                    onPressed: () {}),
                if ((dashboard.adminSummary?.pendingApprovals ?? 0) > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: _brown),
              accountName: Text(auth.nama ?? '',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              accountEmail: Text(_roleBadge(auth.role)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: _gold,
                child: Text(
                  (auth.nama ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                      color: _brown, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Icon(navItems[i].icon),
                  title: Text(navItems[i].label),
                  selected: i == selectedIndex,
                  selectedTileColor: _brown.withValues(alpha: 0.08),
                  selectedColor: _brown,
                  onTap: () {
                    Navigator.pop(context);
                    onNavTap(i);
                  },
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => auth.logout(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: currentPage ??
          _DashboardContent(auth: auth, dashboard: dashboard),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
