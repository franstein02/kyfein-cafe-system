import 'package:flutter/material.dart';

class AdminAbsensiScreen extends StatelessWidget {
  const AdminAbsensiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Absensi'),
        backgroundColor: const Color(0xFF1B4332),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Data Monitoring Absensi & GPS Masuk/Pulang',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
      ),
    );
  }
}