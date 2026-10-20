import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/stok_models.dart';
import '../../providers/stok_gudang_provider.dart';

class EditStokGudangDialog extends StatefulWidget {
  final StokGudang stok;
  final StokGudangProvider provider;

  const EditStokGudangDialog({
    super.key,
    required this.stok,
    required this.provider,
  });

  static Future<bool?> show(
    BuildContext context, {
    required StokGudang stok,
    required StokGudangProvider provider,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditStokGudangDialog(stok: stok, provider: provider),
    );
  }

  @override
  State<EditStokGudangDialog> createState() => _EditStokGudangDialogState();
}

class _EditStokGudangDialogState extends State<EditStokGudangDialog> {
  late TextEditingController _kemasanController;
  late TextEditingController _eceranController;
  late TextEditingController _stokMinController;
  late TextEditingController _isiKemasanController;

  bool _isSaving = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _kemasanController = TextEditingController(text: widget.stok.jumlahKemasanBesar.toString());
    _eceranController = TextEditingController(text: formatAngka(widget.stok.jumlahSatuanKecil));
    _stokMinController = TextEditingController(text: formatAngka(widget.stok.bahan.stokMinimum));
    _isiKemasanController = TextEditingController(text: formatAngka(widget.stok.bahan.isiPerKemasan));
  }

  @override
  void dispose() {
    _kemasanController.dispose();
    _eceranController.dispose();
    _stokMinController.dispose();
    _isiKemasanController.dispose();
    super.dispose();
  }

  int get _kemasan => int.tryParse(_kemasanController.text) ?? 0;
  double get _eceran => double.tryParse(_eceranController.text.replaceAll(',', '.')) ?? 0;
  double get _isiKemasan => double.tryParse(_isiKemasanController.text.replaceAll(',', '.')) ?? widget.stok.bahan.isiPerKemasan;
  double get _totalKecil => (_kemasan * _isiKemasan) + _eceran;

  void _adjustKemasan(int delta) {
    final next = (_kemasan + delta).clamp(0, 99999);
    setState(() {
      _kemasanController.text = next.toString();
    });
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMsg = '';
    });

    final kemasan = _kemasan;
    final eceran = _eceran;
    final stokMin = double.tryParse(_stokMinController.text.replaceAll(',', '.'));
    final isiKemasan = double.tryParse(_isiKemasanController.text.replaceAll(',', '.'));

    final ok = await widget.provider.updateStokGudang(
      bahanId: widget.stok.bahan.id,
      jumlahKemasanBesar: kemasan,
      jumlahSatuanKecil: eceran,
      stokMinimum: stokMin,
      isiPerKemasan: isiKemasan,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isSaving = false;
        _errorMsg = widget.provider.errorMessage.isNotEmpty
            ? widget.provider.errorMessage
            : 'Gagal memperbarui stok gudang';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bahan = widget.stok.bahan;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Stok Gudang',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        bahan.nama,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMsg.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Live Stock Preview Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kalkulasi Total Stok Fisik:',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1B4332), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_kemasan kemasan + ${formatAngka(_eceran)} ${bahan.satuan} = ${formatAngka(_totalKecil)} ${bahan.satuan}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Field 1: Kemasan Besar with Stepper
            const Text(
              'Jumlah Kemasan Besar (Utuh/Pack/Botol)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D312E)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _adjustKemasan(-1),
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _kemasanController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      suffixText: 'kemasan',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _adjustKemasan(1),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Field 2: Satuan Kecil / Eceran
            Text(
              'Jumlah Satuan Kecil / Eceran (${bahan.satuan})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D312E)),
            ),
            const SizedBox(height: 4),
            Text(
              'Sisa isi dari kemasan yang sudah dibuka di gudang',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _eceranController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                suffixText: bahan.satuan,
              ),
            ),
            const SizedBox(height: 14),

            // Field 3 & 4: Isi per Kemasan & Ambang Stok Minimum
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Isi per Kemasan (${bahan.satuan})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D312E)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _isiKemasanController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          suffixText: bahan.satuan,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stok Minimum (${bahan.satuan})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D312E)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _stokMinController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          suffixText: bahan.satuan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
