import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KosService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final data = await _client
        .from('kos')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> add({
    required String name,
    required String address,
    required int price,
  }) async {
    await _client.from('kos').insert({
      'owner_id': _uid,
      'name': name,
      'address': address,
      'price': price,
    });
  }

  /// true = berhasil, false = ditolak RLS / data tidak ditemukan
  Future<bool> update(String id, Map<String, dynamic> values) async {
    final rows =
        await _client.from('kos').update(values).eq('id', id).select();
    return rows.isNotEmpty;
  }

  /// true = berhasil, false = ditolak RLS / data tidak ditemukan
  Future<bool> delete(String id) async {
    final rows = await _client.from('kos').delete().eq('id', id).select();
    return rows.isNotEmpty;
  }

  /// Helper untuk pengujian keamanan lintas akun (Praktik 6)
  Future<void> runSecurityTest(String kosIdMilikUserA, String uuidUserA) async {
    final updated = await update(kosIdMilikUserA, {'name': 'DIUBAH USER B'});
    debugPrint(updated
        ? '[FAIL] User B berhasil mengubah data User A'
        : '[PASS] UPDATE ditolak oleh RLS');

    final deleted = await delete(kosIdMilikUserA);
    debugPrint(deleted
        ? '[FAIL] User B berhasil menghapus data User A'
        : '[PASS] DELETE ditolak oleh RLS');

    try {
      await _client.from('kos').insert({
        'owner_id': uuidUserA,
        'name': 'Kos palsu',
        'address': 'Alamat palsu',
        'price': 500000,
      });
      debugPrint('[FAIL] INSERT atas nama user lain berhasil');
    } on PostgrestException catch (e) {
      debugPrint('[PASS] INSERT ditolak: ${e.code} - ${e.message}');
    }
  }
}