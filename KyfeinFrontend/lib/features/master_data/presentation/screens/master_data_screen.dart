import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/master_data_provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _ResepInputItem {
  String? bahanId;
  final TextEditingController qtyController;

  _ResepInputItem({this.bahanId, double qty = 0.0})
      : qtyController = TextEditingController(
          text: qty > 0 ? (qty % 1 == 0 ? qty.toInt().toString() : qty.toString()) : '',
        );

  void dispose() {
    qtyController.dispose();
  }
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  String _selectedKategoriId = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterDataProvider>().loadData();
    });
  }

  void _showMenuForm(BuildContext context, [MasterMenu? menu]) {
    final isEdit = menu != null;
    final provider = context.read<MasterDataProvider>();
    
    String nama = menu?.nama ?? '';
    String kodeMenu = menu?.kodeMenu ?? '';
    String hargaStr = menu?.harga.toInt().toString() ?? '';
    String? kategoriId = menu?.kategoriId;
    
    // Fallback if kategoriId is not in categories
    if (kategoriId != null && !provider.categories.any((c) => c.id == kategoriId)) {
      kategoriId = null;
    }
    if (kategoriId == null && provider.categories.isNotEmpty) {
      kategoriId = provider.categories.first.id;
    }
    
    File? selectedImage;
    String? currentFotoUrl = menu?.fotoId;
    bool isUploading = false;

    // Resep BOM inputs
    final List<_ResepInputItem> resepInputs = [];
    if (menu != null && menu.resep.isNotEmpty) {
      for (final r in menu.resep) {
        resepInputs.add(_ResepInputItem(bahanId: r.bahanId, qty: r.jumlahTerpakai));
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isEdit ? 'Edit Menu' : 'Tambah Menu'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(labelText: 'Kode Menu'),
                        controller: TextEditingController(text: kodeMenu)..selection = TextSelection.collapsed(offset: kodeMenu.length),
                        onChanged: (val) => kodeMenu = val,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Nama Menu'),
                        controller: TextEditingController(text: nama)..selection = TextSelection.collapsed(offset: nama.length),
                        onChanged: (val) => nama = val,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Harga'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: hargaStr)..selection = TextSelection.collapsed(offset: hargaStr.length),
                        onChanged: (val) => hargaStr = val,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        initialValue: kategoriId,
                        items: provider.categories.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.nama));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => kategoriId = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Placeholder untuk Input Foto Menu (Disiapkan untuk Supabase)
                      InkWell(
                        onTap: isUploading ? null : () {
                          showModalBottomSheet(
                            context: context,
                            builder: (bc) {
                              return SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Galeri'),
                                      onTap: () async {
                                        Navigator.pop(bc);
                                        final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                                        if (pickedFile != null) {
                                          setState(() => selectedImage = File(pickedFile.path));
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_camera),
                                      title: const Text('Kamera'),
                                      onTap: () async {
                                        Navigator.pop(bc);
                                        final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                                        if (pickedFile != null) {
                                          setState(() => selectedImage = File(pickedFile.path));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                            image: selectedImage != null
                                ? DecorationImage(image: FileImage(selectedImage!), fit: BoxFit.cover)
                                : (currentFotoUrl != null && currentFotoUrl!.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(currentFotoUrl!.startsWith('http') ? currentFotoUrl! : '${ApiConfig.baseUrl}/foto/$currentFotoUrl'), fit: BoxFit.cover)
                                    : null),
                          ),
                          child: Stack(
                            children: [
                              if (selectedImage == null && (currentFotoUrl == null || currentFotoUrl!.isEmpty))
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey.shade600),
                                      const SizedBox(height: 8),
                                      Text('Pilih Foto Menu', style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              if (selectedImage != null || (currentFotoUrl != null && currentFotoUrl!.isNotEmpty))
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.black45,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          selectedImage = null;
                                          currentFotoUrl = null;
                                        });
                                      },
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Section Resep & Bahan Baku (BOM)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAF9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF1B4332)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Resep & Bahan (BOM)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${resepInputs.length} Bahan',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B4332),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Komposisi bahan per 1 porsi menu untuk audit stok opname.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 12),
                            if (resepInputs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Belum ada resep bahan baku.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(resepInputs.length, (idx) {
                                final item = resepInputs[idx];
                                final selectedBahan = provider.bahanList
                                    .where((b) => b.id == item.bahanId)
                                    .firstOrNull;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              isDense: true,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                labelText: 'Bahan Baku',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                border: OutlineInputBorder(),
                                              ),
                                              initialValue: item.bahanId,
                                              items: provider.bahanList.map((b) {
                                                return DropdownMenuItem<String>(
                                                  value: b.id,
                                                  child: Text(
                                                    '${b.nama} (${b.satuan})',
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  item.bahanId = val;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                resepInputs.removeAt(idx);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: item.qtyController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                labelText: 'Jumlah Pemakaian',
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                border: const OutlineInputBorder(),
                                                suffixText: selectedBahan?.satuan ?? '',
                                                suffixStyle: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1B4332),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1B4332),
                                  side: const BorderSide(color: Color(0xFF1B4332)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah Bahan ke Resep', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  setState(() {
                                    final usedIds = resepInputs.map((e) => e.bahanId).toSet();
                                    final availableBahan = provider.bahanList
                                        .where((b) => !usedIds.contains(b.id))
                                        .firstOrNull ??
                                        provider.bahanList.firstOrNull;
                                    resepInputs.add(_ResepInputItem(bahanId: availableBahan?.id, qty: 1.0));
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4332),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isUploading ? null : () async {
                    if (nama.isEmpty || kodeMenu.isEmpty || hargaStr.isEmpty || kategoriId == null) return;
                    final harga = double.tryParse(hargaStr) ?? 0;
                    
                    setState(() => isUploading = true);
                    
                    String? uploadedFotoUrl = currentFotoUrl;
                    if (selectedImage != null) {
                      final url = await provider.uploadImage(selectedImage!);
                      if (url != null) {
                        uploadedFotoUrl = url;
                      }
                    }

                    final resepPayload = <Map<String, dynamic>>[];
                    for (final r in resepInputs) {
                      if (r.bahanId != null && r.bahanId!.isNotEmpty) {
                        final qty = double.tryParse(r.qtyController.text) ?? 0.0;
                        if (qty > 0) {
                          resepPayload.add({
                            'bahan_id': r.bahanId,
                            'jumlah_terpakai': qty,
                          });
                        }
                      }
                    }
                    
                    final data = {
                      'nama': nama,
                      'kode_menu': kodeMenu,
                      'harga': harga,
                      'kategori_id': kategoriId,
                      'foto_id': uploadedFotoUrl,
                      'resep': resepPayload,
                      if (!isEdit) 'status_aktif': true,
                    };
                    
                    bool success;
                    if (isEdit) {
                      success = await provider.updateMenu(menu.id, data);
                    } else {
                      success = await provider.createMenu(data);
                    }
                    
                    if (context.mounted) {
                      setState(() => isUploading = false);
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Berhasil menyimpan menu & resep')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gagal menyimpan menu')),
                        );
                      }
                    }
                  },
                  child: isUploading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<MasterDataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.menus.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.errorMessage.isNotEmpty && provider.menus.isEmpty) {
            return Center(child: Text(provider.errorMessage));
          }

          // Filter menus
          final filteredMenus = _selectedKategoriId == 'Semua' 
              ? provider.menus 
              : provider.menus.where((m) => m.kategoriId == _selectedKategoriId).toList();

          return Column(
            children: [
              // Filter categories
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'Semua'),
                      ...provider.categories.map((c) => _buildFilterChip(c.id, c.nama)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filteredMenus.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _buildAddMenuBlock(),
                          const SizedBox(height: 48),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu_outlined, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada menu di kategori ini',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: filteredMenus.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildAddMenuBlock();
                          }
                          final menu = filteredMenus[index - 1];
                          final kategori = provider.categories.where((c) => c.id == menu.kategoriId).firstOrNull?.nama ?? '-';
              
                          return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              image: (menu.fotoId != null && menu.fotoId!.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(menu.fotoId!.startsWith('http') ? menu.fotoId! : '${ApiConfig.baseUrl}/foto/${menu.fotoId}'), 
                                    fit: BoxFit.cover
                                  )
                                : null,
                            ),
                            child: (menu.fotoId == null || menu.fotoId!.isEmpty) 
                                ? Icon(Icons.image_rounded, color: Colors.grey.shade400)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(menu.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('${menu.kodeMenu} • $kategori', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(_currencyFormat.format(menu.harga), style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _showResepDetailModal(context, menu),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: menu.resep.isNotEmpty ? const Color(0xFFE9F5E6) : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: menu.resep.isNotEmpty ? const Color(0xFF1B4332).withValues(alpha: 0.3) : Colors.amber.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          menu.resep.isNotEmpty ? Icons.receipt_long_rounded : Icons.warning_amber_rounded,
                                          size: 13,
                                          color: menu.resep.isNotEmpty ? const Color(0xFF1B4332) : Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          menu.resep.isNotEmpty
                                              ? '${menu.resep.length} Bahan Resep (BOM)'
                                              : 'Belum Ada Resep (BOM)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: menu.resep.isNotEmpty ? const Color(0xFF1B4332) : Colors.amber.shade900,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: menu.statusAktif,
                                activeThumbColor: Colors.green,
                                onChanged: (val) {
                                  provider.toggleMenuStatus(menu.id, menu.statusAktif);
                                },
                              ),
                              Text(menu.statusAktif ? 'Aktif' : 'Nonaktif', 
                                style: TextStyle(
                                  color: menu.statusAktif ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showMenuForm(context, menu);
                                  } else if (value == 'hapus') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Menu'),
                                        content: Text('Apakah Anda yakin ingin menghapus ${menu.nama}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              final success = await provider.deleteMenu(menu.id);
                                              if (success && context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Berhasil menghapus menu')),
                                                );
                                              }
                                            },
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'hapus',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Hapus', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  },
),
    );
  }

  Widget _buildAddMenuBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4332).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMenuForm(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tambah Menu Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedKategoriId == id;
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedKategoriId = id);
          }
        },
        showCheckmark: false,
        selectedColor: primaryColor.withValues(alpha: 0.15),
        checkmarkColor: primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? primaryColor : Colors.grey.shade600,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? primaryColor : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  void _showResepDetailModal(BuildContext context, MasterMenu menu) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bc) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F5E6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1B4332)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resep / BOM: ${menu.nama}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Komposisi bahan terpakai per 1 porsi transaksi', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (menu.resep.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 36, color: Colors.amber.shade800),
                        const SizedBox(height: 8),
                        Text(
                          'Menu ini belum memiliki resep bahan baku.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transaksi menu ini belum terhitung ke audit stok opname. Klik tombol di bawah untuk menambah resep.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: menu.resep.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final r = menu.resep[idx];
                        final qtyStr = r.jumlahTerpakai % 1 == 0
                            ? r.jumlahTerpakai.toInt().toString()
                            : r.jumlahTerpakai.toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1B4332).withValues(alpha: 0.1),
                            child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B4332))),
                          ),
                          title: Text(
                            r.namaBahan.isNotEmpty ? r.namaBahan : r.bahanId,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$qtyStr ${r.satuan}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B4332)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4332),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit Menu & Resep'),
                    onPressed: () {
                      Navigator.pop(bc);
                      _showMenuForm(context, menu);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
