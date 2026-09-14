import 'package:flutter/material.dart';

class KdsScreen extends StatefulWidget {
  final String areaProduksi; // 'kitchen' or 'bar'
  const KdsScreen({super.key, required this.areaProduksi});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  @override
  Widget build(BuildContext context) {
    final title = widget.areaProduksi == 'kitchen' ? 'Layar KDS Kitchen (Lantai 2)' : 'Layar Bar Minuman';
    final areaColor = widget.areaProduksi == 'kitchen' ? Colors.orange[800] : Colors.brown[700];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: areaColor,
        actions: [
          Chip(
            label: Text('Area: ${widget.areaProduksi.toUpperCase()}'),
            backgroundColor: Colors.white24,
            labelStyle: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: areaColor!, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pesanan #${index + 101}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Chip(label: Text('Menunggu', style: TextStyle(fontSize: 12))),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: const [
                          Text('1x Kopi Espresso (Kode: KOP-01)'),
                          Text('Catatan: Less Sugar', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: areaColor),
                        onPressed: () {},
                        child: const Text('Tandai Selesai'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
