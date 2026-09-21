import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class FuelApiService {
  static const String baseUrl =
      'https://data.economie.gouv.fr/api/records/1.0/search/?dataset=prix-des-carburants-en-france-flux-instantane-v2&rows=50';

  Future<List<Station>> fetchNearbyStations(double lat, double lon) async {
    final url = Uri.parse('$baseUrl&geofilter.distance=$lat,$lon,10000');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> records = data['records'] ?? [];
        return records.map((record) => Station.fromJson(record)).toList();
      }
    } catch (e) {
      print('Erreur réseau / API : $e');
    }
    return [];
  }

  Future<Map<String, double>?> searchCityCoordinates(String cityName) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cityName)}&format=json&limit=1&countrycodes=fr',
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'CarbuStockApp/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return {'lat': lat, 'lon': lon};
        }
      }
    } catch (e) {
      print('Erreur lors de la recherche de la ville : $e');
    }
    return null;
  }
}
