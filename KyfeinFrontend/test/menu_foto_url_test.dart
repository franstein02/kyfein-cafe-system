import 'package:flutter_test/flutter_test.dart';
import 'package:kyfein_frontend/core/constants/api_endpoints.dart';
import 'package:kyfein_frontend/features/master_data/providers/master_data_provider.dart';
import 'package:kyfein_frontend/features/pos/providers/pos_provider.dart';

void main() {
  test('MasterMenu.resolvedFotoUrl prefers foto_url and falls back to /foto/id', () {
    const supaUrl =
        'https://psdeyhujegvaczqyozbz.supabase.co/storage/v1/object/public/Storage/menu/mnm01_coffee_latte.jpg';

    final withDirectUrl = MasterMenu.fromJson({
      'id': 'menu-1',
      'nama': 'Coffee Latte',
      'kode_menu': 'MNM01',
      'harga': 11000,
      'foto_id': 'foto-uuid-1',
      'foto_url': supaUrl,
      'kategori_id': 'kat-1',
      'status_aktif': true,
      'resep': [],
    });
    expect(withDirectUrl.fotoId, 'foto-uuid-1');
    expect(withDirectUrl.resolvedFotoUrl, supaUrl);

    final withFallbackUuid = MasterMenu.fromJson({
      'id': 'menu-2',
      'nama': 'Americano',
      'kode_menu': 'MNM03',
      'harga': 8000,
      'foto_id': 'foto-uuid-2',
      'kategori_id': 'kat-1',
      'status_aktif': true,
      'resep': [],
    });
    expect(withFallbackUuid.resolvedFotoUrl, '${ApiConfig.baseUrl}/foto/foto-uuid-2');

    final withoutPhoto = MasterMenu.fromJson({
      'id': 'menu-3',
      'nama': 'Plain',
      'kode_menu': 'MNM99',
      'harga': 5000,
      'kategori_id': 'kat-1',
      'status_aktif': true,
      'resep': [],
    });
    expect(withoutPhoto.resolvedFotoUrl, isNull);
  });

  test('MenuItem (POS) resolvedFotoUrl prefers foto_url and falls back to /foto/id', () {
    const supaUrl =
        'https://psdeyhujegvaczqyozbz.supabase.co/storage/v1/object/public/Storage/menu/mkn01_nasi_goreng.jpg';

    final posMenu = MenuItem.fromJson({
      'id': 'mkn-1',
      'nama': 'Nasi Goreng',
      'harga': 15000,
      'foto_id': 'foto-uuid-mkn1',
      'foto_url': supaUrl,
      'kategori_id': 'kat-mkn',
      'resep': [],
    });
    expect(posMenu.resolvedFotoUrl, supaUrl);

    final posFallback = MenuItem.fromJson({
      'id': 'mkn-2',
      'nama': 'Nasi Kebuli',
      'harga': 25000,
      'foto_id': 'foto-uuid-mkn2',
      'kategori_id': 'kat-mkn',
      'resep': [],
    });
    expect(posFallback.resolvedFotoUrl, '${ApiConfig.baseUrl}/foto/foto-uuid-mkn2');
  });
}

