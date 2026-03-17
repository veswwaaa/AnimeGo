import 'package:http/http.dart' as http;
import 'dart:convert';


// api top rated
class ApiToprated {
  static Future<List<dynamic>> fetchData() async {
    try {
      final response = await http.get( 
        Uri.parse('kevinapienim.vercel.app/api/nimegami/top-rated')
      ); 

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        print('Data fetched: $data');
        return data; // Return list langsung
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    }catch (e) {
      print('Error fetching data: $e');
      return []; // Return empty list on error
  }
  }
}