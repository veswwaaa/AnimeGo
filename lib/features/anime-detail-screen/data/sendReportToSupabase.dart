import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

void sendReportToSupabase({
  required String animeName,
  required String email,
  required String reason,
  required String animeUrl,
}) async {
  print('Mengirim laporan ke Supabase dengan data:');
  print('Nama Anime: $animeName');
  print('Email: $email');
  print('Alasan: $reason');
  print('URL Anime: $animeUrl');
  try {
    await _supabase.from('animeReports').insert({
      'anime-name': animeName,
      'email': email,
      'reason': reason,
      'anime-url': animeUrl,
    });
    print('Laporan berhasil dikirim ke Supabase');
  } catch (e) {
    print('Error saat mengirim laporan: $e');
  }
}
