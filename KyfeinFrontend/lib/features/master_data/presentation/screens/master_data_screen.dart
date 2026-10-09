import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import 'package:intl/intl.dart';

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
                      onTap: () {
                        // TODO: Implement image picker and upload to Supabase
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur upload foto belum disambungkan ke Supabase')),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text('Pilih Foto Menu', style: TextStyle(color: Colors.grey.shade600)),
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
                  onPressed: () async {
                    if (nama.isEmpty || kodeMenu.isEmpty || hargaStr.isEmpty || kategoriId == null) return;
                    final harga = double.tryParse(hargaStr) ?? 0;
                    
                    final data = {
                      'nama': nama,
                      'kode_menu': kodeMenu,
                      'harga': harga,
                      'kategori_id': kategoriId,
                      if (!isEdit) 'status_aktif': true,
                    };
                    
                    bool success;
                    if (isEdit) {
                      success = await provider.updateMenu(menu.id, data);
                    } else {
                      success = await provider.createMenu(data);
                    }
                    
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Berhasil menyimpan menu')),
                      );
                    }
                  },
                  child: const Text('Simpan'),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                color: Theme.of(context).scaffoldBackgroundColor,
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
                            ),
                            child: Icon(Icons.image_rounded, color: Colors.grey.shade400),
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
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                onPressed: () => _showMenuForm(context, menu),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                onPressed: () {
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
                                },
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedKategoriId = id);
          }
        },
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
