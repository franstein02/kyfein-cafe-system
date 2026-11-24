import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/master_data_provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/page_refresh_scope.dart';
import '../widgets/kelola_karyawan_view.dart';

class MasterDataScreen extends StatefulWidget {
  final int initialSection;

  const MasterDataScreen({super.key, this.initialSection = 0});

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
  final _numberFormat = NumberFormat('#,##0.###', 'id_ID');
  String _selectedKategoriId = 'Semua';
  String _selectedBahanArea = 'semua_tab'; // semua_tab | bar | kitchen
  late int _currentSection;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterDataProvider>().loadData();
    });
  }

  @override
  void didUpdateWidget(covariant MasterDataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _currentSection = widget.initialSection.clamp(0, 3);
      });
    }
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
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        initialValue: kategoriId,
                        items: provider.categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
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
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          (currentFotoUrl == menu?.fotoId ? menu?.resolvedFotoUrl : null) ??
                                              (currentFotoUrl!.startsWith('http') ? currentFotoUrl! : '${ApiConfig.baseUrl}/foto/$currentFotoUrl'),
                                        ),
                                        fit: BoxFit.cover,
                                      )
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
    return PageRefreshRegistrar(
      onRefresh: () => context.read<MasterDataProvider>().loadData(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: buildStandaloneAppBar(
          context,
          title: 'Master Data',
          onRefresh: () => context.read<MasterDataProvider>().loadData(),
        ),
        body: Consumer<MasterDataProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.menus.isEmpty && provider.categories.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            switch (_currentSection) {
              case 0:
                return _buildMenuTab(provider);
              case 1:
                return _buildKategoriTab(provider);
              case 2:
                return _buildBahanTab(provider);
              case 3:
                return const KelolaKaryawanView();
              default:
                return _buildMenuTab(provider);
            }
          },
        ),
      ),
    );
  }

  Widget _buildMenuTab(MasterDataProvider provider) {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                              image: (menu.resolvedFotoUrl != null)
                                ? DecorationImage(
                                    image: NetworkImage(menu.resolvedFotoUrl!), 
                                    fit: BoxFit.cover
                                  )
                                : null,
                            ),
                            child: (menu.resolvedFotoUrl == null) 
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
                                        Flexible(
                                          child: Text(
                                            menu.resep.isNotEmpty
                                                ? '${menu.resep.length} Bahan Resep (BOM)'
                                                : 'Belum Ada Resep (BOM)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: menu.resep.isNotEmpty ? const Color(0xFF1B4332) : Colors.amber.shade900,
                                            ),
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
                const Flexible(
                  child: Text(
                    'Tambah Menu Baru',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
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

  // ── TAB 2: KATEGORI MENU (PROSES 3) ─────────────────────────────────────────
  Widget _buildKategoriTab(MasterDataProvider provider) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _buildActionBlock(
          label: 'Tambah Kategori Menu Baru',
          onTap: () => _showKategoriForm(context, provider),
        ),
        const SizedBox(height: 8),
        if (provider.categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Belum ada kategori menu.')),
          )
        else
          ...provider.categories.map((kat) {
            final isKitchen = kat.areaProduksi == 'kitchen';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isKitchen ? Colors.orange.shade50 : Colors.blue.shade50,
                  child: Icon(
                    isKitchen ? Icons.soup_kitchen_rounded : Icons.local_cafe_rounded,
                    color: isKitchen ? Colors.orange.shade800 : Colors.blue.shade800,
                  ),
                ),
                title: Text(kat.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Area Produksi KDS: ${kat.areaProduksi.toUpperCase()} • ${kat.statusAktif ? "Aktif" : "Nonaktif"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: kat.statusAktif,
                      activeThumbColor: Colors.green,
                      onChanged: (v) {
                        provider.updateKategoriMenu(kat.id, {'status_aktif': v});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      onPressed: () => _showKategoriForm(context, provider, kat),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showKategoriForm(
    BuildContext context,
    MasterDataProvider provider, [
    MasterKategoriMenu? existing,
  ]) {
    final namaC = TextEditingController(text: existing?.nama ?? '');
    String areaProduksi = existing?.areaProduksi ?? 'bar';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Kategori Menu' : 'Tambah Kategori Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaC,
                decoration: const InputDecoration(labelText: 'Nama Kategori Menu'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Area Produksi (KDS)'),
                initialValue: areaProduksi,
                items: const [
                  DropdownMenuItem(
                    value: 'bar',
                    child: Text(
                      'BAR (Minuman / Coffee)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'kitchen',
                    child: Text(
                      'KITCHEN (Makanan / Dapur)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => areaProduksi = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4332),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nama = namaC.text.trim();
                if (nama.isEmpty) return;
                bool ok;
                if (existing != null) {
                  ok = await provider.updateKategoriMenu(existing.id, {
                    'nama': nama,
                    'area_produksi': areaProduksi,
                  });
                } else {
                  ok = await provider.createKategoriMenu({
                    'nama': nama,
                    'area_produksi': areaProduksi,
                    'status_aktif': true,
                  });
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Kategori menu berhasil disimpan'
                          : 'Gagal menyimpan kategori menu'),
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 3: BAHAN BAKU (PROSES 3) ────────────────────────────────────────────
  Widget _buildBahanTab(MasterDataProvider provider) {
    final filteredBahan = provider.bahanList.where((b) {
      if (_selectedBahanArea == 'bar') return b.area == 'bar' || b.area == 'semua';
      if (_selectedBahanArea == 'kitchen') return b.area == 'kitchen' || b.area == 'semua';
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _buildActionBlock(
          label: 'Tambah Bahan Baku Baru',
          onTap: () => _showBahanForm(context, provider),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Semua (${provider.bahanList.length})'),
              selected: _selectedBahanArea == 'semua_tab',
              onSelected: (_) => setState(() => _selectedBahanArea = 'semua_tab'),
            ),
            ChoiceChip(
              label: const Text('Bar (Minuman)'),
              selected: _selectedBahanArea == 'bar',
              onSelected: (_) => setState(() => _selectedBahanArea = 'bar'),
            ),
            ChoiceChip(
              label: const Text('Kitchen (Dapur)'),
              selected: _selectedBahanArea == 'kitchen',
              onSelected: (_) => setState(() => _selectedBahanArea = 'kitchen'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredBahan.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Belum ada master bahan baku untuk area ini.')),
          )
        else
          ...filteredBahan.map((b) {
            final detailLines = <String>[
              'Area: ${b.areaLabel}',
              'Satuan: ${b.satuan}',
              if (b.punyaKemasan)
                'Isi/Kemasan: ${_numberFormat.format(b.isiPerKemasan)} ${b.satuan}',
              b.punyaKemasan
                  ? 'Stok Min: ${_numberFormat.format(b.stokMinimum)} kemasan (${_numberFormat.format(b.batasMinimumSatuanKecil)} ${b.satuan})'
                  : 'Stok Min: ${_numberFormat.format(b.stokMinimum)} ${b.satuan}',
              'Harga Rata-rata (HPP): ${_currencyFormat.format(b.hargaRataRata)} / ${b.satuan}',
            ];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: CircleAvatar(
                        backgroundColor: Color(0xFFE9F5E6),
                        child: Icon(Icons.inventory_2_rounded, color: Color(0xFF1B4332)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...detailLines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      onPressed: () => _showBahanForm(context, provider, b),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showBahanForm(
    BuildContext context,
    MasterDataProvider provider, [
    MasterBahan? existing,
  ]) {
    final namaC = TextEditingController(text: existing?.nama ?? '');
    final satuanC = TextEditingController(text: existing?.satuan ?? 'gram');
    final isiC = TextEditingController(
      text: existing != null ? existing.isiPerKemasan.toInt().toString() : '1000',
    );
    final minC = TextEditingController(
      text: existing != null ? existing.stokMinimum.toInt().toString() : '10',
    );
    final hargaC = TextEditingController(
      text: existing != null ? existing.hargaRataRata.toString() : '0',
    );
    String selectedArea = existing?.area ?? 'bar';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Bahan Baku' : 'Tambah Bahan Baku'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaC,
                  decoration: const InputDecoration(labelText: 'Nama Bahan Baku'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedArea,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Area Penggunaan Stok'),
                  items: const [
                    DropdownMenuItem(value: 'bar', child: Text('Bar (Minuman)')),
                    DropdownMenuItem(value: 'kitchen', child: Text('Kitchen (Dapur)')),
                    DropdownMenuItem(value: 'semua', child: Text('Bar & Kitchen (Umum)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedArea = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: satuanC,
                  decoration: const InputDecoration(
                    labelText: 'Satuan Kecil (gram / ml / pcs)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: isiC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Isi per Kemasan Besar',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Batas Stok Minimum (Kemasan Besar)',
                    helperText: 'Dalam jumlah kemasan/pcs besar (mis. 50 kemasan)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hargaC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Harga Rata-rata per Satuan Kecil (Rp)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4332),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nama = namaC.text.trim();
                final satuan = satuanC.text.trim();
                if (nama.isEmpty || satuan.isEmpty) return;
                final payload = {
                  'nama': nama,
                  'satuan': satuan,
                  'area': selectedArea,
                  'isi_per_kemasan': double.tryParse(isiC.text.trim()) ?? 1.0,
                  'stok_minimum': double.tryParse(minC.text.trim()) ?? 0.0,
                  'harga_rata_rata': double.tryParse(hargaC.text.trim()) ?? 0.0,
                };
                final ok = existing != null
                    ? await provider.updateBahan(existing.id, payload)
                    : await provider.createBahan(payload);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Bahan baku berhasil disimpan'
                          : 'Gagal menyimpan bahan baku'),
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBlock({required String label, required VoidCallback onTap}) {
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
          onTap: onTap,
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
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
