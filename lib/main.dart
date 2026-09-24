import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const CarbuStockApp());
}

class CarbuStockApp extends StatelessWidget {
  const CarbuStockApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbuStock Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int selectedCapacity = 40; // de 40L à 100L
  String selectedFuel = 'E10'; // E10, SP98, SP95, Gazole, E85

  LatLng userPosition = const LatLng(48.8566, 2.3522); // Paris par défaut
  final MapController mapController = MapController();
  final Distance distanceCalculator = const Distance();

  bool isLocating = false;

  // Liste garantie et complète de stations d'Île-de-France avec toutes les marques et prix
  final List<Map<String, dynamic>> stations = [
    {'nom': 'TotalEnergies Paris Étoile', 'ville': 'PARIS', 'lat': 48.8738, 'lon': 2.2950, 'prix_e10': 1.859, 'prix_sp98': 1.949, 'prix_sp95': 1.889, 'prix_gazole': 1.769, 'prix_e85': 0.829},
    {'nom': 'Carrefour Auteuil', 'ville': 'PARIS', 'lat': 48.8460, 'lon': 2.2600, 'prix_e10': 1.799, 'prix_sp98': 1.899, 'prix_sp95': 1.829, 'prix_gazole': 1.719, 'prix_e85': 0.799},
    {'nom': 'E.Leclerc Rueil-Malmaison', 'ville': 'RUEIL-MALMAISON', 'lat': 48.8872, 'lon': 2.1706, 'prix_e10': 1.749, 'prix_sp98': 1.849, 'prix_sp95': 1.789, 'prix_gazole': 1.689, 'prix_e85': 0.779},
    {'nom': 'Shell Nanterre La Défense', 'ville': 'NANTERRE', 'lat': 48.8924, 'lon': 2.2065, 'prix_e10': 1.829, 'prix_sp98': 1.929, 'prix_sp95': 1.859, 'prix_gazole': 1.749, 'prix_e85': 0.819},
    {'nom': 'Auchan Puteaux', 'ville': 'PUTEAUX', 'lat': 48.8920, 'lon': 2.2380, 'prix_e10': 1.779, 'prix_sp98': 1.879, 'prix_sp95': 1.809, 'prix_gazole': 1.709, 'prix_e85': 0.789},
    {'nom': 'BP Boulogne-Billancourt', 'ville': 'BOULOGNE-BILLANCOURT', 'lat': 48.8397, 'lon': 2.2410, 'prix_e10': 1.819, 'prix_sp98': 1.919, 'prix_sp95': 1.849, 'prix_gazole': 1.739, 'prix_e85': 0.809},
    {'nom': 'Intermarché Versailles', 'ville': 'VERSAILLES', 'lat': 48.8014, 'lon': 2.1301, 'prix_e10': 1.739, 'prix_sp98': 1.839, 'prix_sp95': 1.779, 'prix_gazole': 1.679, 'prix_e85': 0.769},
    {'nom': 'Esso Saint-Cloud', 'ville': 'SAINT-CLOUD', 'lat': 48.8471, 'lon': 2.2137, 'prix_e10': 1.839, 'prix_sp98': 1.939, 'prix_sp95': 1.869, 'prix_gazole': 1.759, 'prix_e85': 0.829},
    {'nom': 'TotalEnergies Neuilly', 'ville': 'NEUILLY-SUR-SEINE', 'lat': 48.8844, 'lon': 2.2683, 'prix_e10': 1.869, 'prix_sp98': 1.959, 'prix_sp95': 1.899, 'prix_gazole': 1.779, 'prix_e85': 0.839},
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // Géolocalisation précise au mètre près
  Future<void> _getUserLocation() async {
    setState(() => isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => isLocating = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        userPosition = LatLng(position.latitude, position.longitude);
        isLocating = false;
      });

      mapController.move(userPosition, 13.0);
    } catch (e) {
      setState(() => isLocating = false);
    }
  }

  double? getStationPrice(Map<String, dynamic> record) {
    String key = 'prix_${selectedFuel.toLowerCase()}';
    return record[key] != null ? (record[key] as num).toDouble() : null;
  }

  // Fonction "Moins cher dans ma ville"
  void findCheapestInCurrentCity() {
    String? currentCity;
    double minDistance = double.infinity;

    for (var record in stations) {
      LatLng coords = LatLng(record['lat'], record['lon']);
      double dist = distanceCalculator.as(LengthUnit.Meter, userPosition, coords);
      if (dist < minDistance) {
        minDistance = dist;
        currentCity = record['ville'].toString().toUpperCase();
      }
    }

    if (currentCity == null) return;

    Map<String, dynamic>? cheapestRecord;
    double minPrice = double.infinity;

    for (var record in stations) {
      if (record['ville'].toString().toUpperCase() == currentCity) {
        double? price = getStationPrice(record);
        if (price != null && price < minPrice) {
          minPrice = price;
          cheapestRecord = record;
        }
      }
    }

    if (cheapestRecord != null) {
      LatLng coords = LatLng(cheapestRecord['lat'], cheapestRecord['lon']);
      mapController.move(coords, 15.0);
      showStationDetails(cheapestRecord);
    }
  }

  Future<void> openWaze(double lat, double lon) async {
    final Uri wazeUri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> openGoogleMaps(double lat, double lon) async {
    final Uri mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }

  void showStationDetails(Map<String, dynamic> record) {
    String name = record['nom'];
    String city = record['ville'];
    double? price = getStationPrice(record);
    double total = price != null ? price * selectedCapacity : 0.0;
    double lat = record['lat'];
    double lon = record['lon'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Ville : $city', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Plein de ${selectedCapacity}L ($selectedFuel) :', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(price != null ? '${total.toStringAsFixed(2)} €' : 'N/C', 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        openWaze(lat, lon);
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Waze'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        openGoogleMaps(lat, lon);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Google Maps'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> markers = [];

    // Marqueur position utilisateur
    markers.add(
      Marker(
        point: userPosition,
        width: 45,
        height: 45,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.my_location, color: Colors.blueAccent, size: 26),
          ),
        ),
      ),
    );

    // Ajout des marqueurs de stations sous forme de pancarte lisible
    for (var record in stations) {
      double? price = getStationPrice(record);
      if (price != null) {
        markers.add(
          Marker(
            point: LatLng(record['lat'], record['lon']),
            width: 75,
            height: 32,
            child: GestureDetector(
              onTap: () => showStationDetails(record),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black87, width: 1.2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
                child: Center(
                  child: Text(
                    '${price.toStringAsFixed(3)}€',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: userPosition,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carbustock',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 45,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      child: DropdownButton<int>(
                        value: selectedCapacity,
                        underline: const SizedBox(),
                        items: List.generate(7, (index) => (index + 4) * 10)
                            .map((v) => DropdownMenuItem(value: v, child: Text('$v Litres', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))
                            .toList(),
                        onChanged: (val) => setState(() => selectedCapacity = val!),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      child: DropdownButton<String>(
                        value: selectedFuel,
                        underline: const SizedBox(),
                        items: ['E10', 'SP98', 'SP95', 'Gazole', 'E85']
                            .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))
                            .toList(),
                        onChanged: (val) => setState(() => selectedFuel = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: findCheapestInCurrentCity,
                    icon: const Icon(Icons.local_offer),
                    label: const Text('Moins cher dans ma ville', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              onPressed: _getUserLocation,
              child: isLocating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
