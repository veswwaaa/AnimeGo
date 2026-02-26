import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<Map<String, dynamic>?> fetchData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://kevinapienim.vercel.app/api/nimegami/anime?url=aHR0cHM6Ly9uaW1lZ2FtaS5pZC9qdWp1dHN1LWthaXNlbi1zaGltZXRzdS1rYWl5dXUtemVucGVuLXN1Yi1pbmRvLw==',
        ),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        print('Data fetched: $data');
        // Response memiliki key "name" yang berisi data anime
        if (data.containsKey('name')) {
          return data['name'];
        }
        return data;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      return null;
    }
  }
}
