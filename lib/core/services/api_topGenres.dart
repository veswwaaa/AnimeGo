import 'dart:convert';
import 'package:http/http.dart' as http;


//api top genre
class ApiTopGenres {
  static Future<List<dynamic>> fetchData(String genre) async {
    try {
      final response = await http.get(
        Uri.parse('https://kevinapienim.vercel.app/api/nimegami/top-genre?genre=$genre'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        print('Data fetched: $data');
        return data; // Return list langsung
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      return []; // Return empty list on error
    }
  }
}