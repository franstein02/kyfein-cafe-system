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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Menu' : 'Tambah Menu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
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
                    
                    final data = {
                      'nama': nama,
                      'kode_menu': kodeMenu,
                      'harga': harga,
                      'kategori_id': kategoriId,
                      'foto_id': uploadedFotoUrl,
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
                          const SnackBar(content: Text('Berhasil menyimpan menu')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gagal menyimpan menu')),
                        );
                      }
                    }
                  },
                  child: isUploading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredMenus.length,
                  itemBuilder: (context, index) {
                    final menu = filteredMenus[index];
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMenuForm(context),
        child: const Icon(Icons.add),
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
}
