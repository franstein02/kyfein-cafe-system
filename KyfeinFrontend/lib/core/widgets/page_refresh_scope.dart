import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

typedef PageRefreshCallback = Future<void> Function();

/// Controller bersama untuk tombol Refresh di AppBar utama (Mobile) dan TopBar (Desktop),
/// sehingga setiap halaman tidak perlu lagi membuat blok header & tombol refresh terpisah.
class PageRefreshController extends ChangeNotifier {
  PageRefreshCallback? _callback;
  bool _isRefreshing = false;

  bool get hasCallback => _callback != null;
  bool get isRefreshing => _isRefreshing;

  void register(PageRefreshCallback callback) {
    if (_callback == callback) return;
    _callback = callback;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void unregister(PageRefreshCallback callback) {
    if (_callback != callback) return;
    _callback = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> triggerRefresh({PageRefreshCallback? fallback}) async {
    final cb = _callback ?? fallback;
    if (cb == null || _isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      await cb();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}

class PageRefreshScope extends InheritedWidget {
  final PageRefreshController controller;

  const PageRefreshScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static PageRefreshController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PageRefreshScope>()
        ?.controller;
  }

  static PageRefreshController? readOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<PageRefreshScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(PageRefreshScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Mendaftarkan aksi refresh halaman aktif ke [PageRefreshScope] terdekat.
class PageRefreshRegistrar extends StatefulWidget {
  final PageRefreshCallback onRefresh;
  final Widget child;

  const PageRefreshRegistrar({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<PageRefreshRegistrar> createState() => _PageRefreshRegistrarState();
}

class _PageRefreshRegistrarState extends State<PageRefreshRegistrar> {
  PageRefreshController? _controller;

  Future<void> _handleRefresh() => widget.onRefresh();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PageRefreshScope.readOf(context);
    if (_controller != next) {
      _controller?.unregister(_handleRefresh);
      _controller = next;
      _controller?.register(_handleRefresh);
    }
  }

  @override
  void dispose() {
    _controller?.unregister(_handleRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// AppBar ringan yang otomatis tampil HANYA ketika layar dibuka langsung via
/// `Navigator.push` (di luar shell [DashboardScreen]), menyediakan tombol kembali
/// dan tombol refresh tanpa memakan ruang saat dibuka lewat menu hamburger.
PreferredSizeWidget? buildStandaloneAppBar(
  BuildContext context, {
  required String title,
  PageRefreshCallback? onRefresh,
}) {
  final insideShell = PageRefreshScope.readOf(context) != null;
  final canPop = ModalRoute.of(context)?.canPop ?? false;
  if (insideShell || !canPop) return null;

  return AppBar(
    backgroundColor: const Color(0xFF1B4332),
    foregroundColor: Colors.white,
    elevation: 0,
    title: Text(
      title,
      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
      overflow: TextOverflow.ellipsis,
    ),
    actions: [
      if (onRefresh != null)
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Segarkan Data',
          onPressed: () => onRefresh(),
        ),
    ],
  );
}
