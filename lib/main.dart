import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
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
      title: 'CarbuStock',
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
  String selectedFuel = 'SP95';

  LatLng userPosition = const LatLng(48.8566, 2.3522); // Paris par défaut
  final MapController mapController = MapController();
  final Distance distanceCalculator = const Distance();

  List<dynamic> stations = [];
  bool isLoading = true;
  bool isLocating = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    fetchAllStations();
  }

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

  // Récupération et parsing blindé des stations
  Future<void> fetchAllStations() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records?limit=1000'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List allResults = data['results'] ?? [];

        // Filtrage local Île-de-France élargi et sécurisé
        stations = allResults.where((record) {
          LatLng? coords = getStationCoordinates(record);
          if (coords == null) return false;
          return coords.latitude >= 48.15 && 
                 coords.latitude <= 49.25 && 
                 coords.longitude >= 1.45 && 
                 coords.longitude <= 3.55;
        }).toList();

        setState(() => isLoading = false);
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  double? getPriceForFuel(dynamic record, String fuelName) {
    try {
      var prices = record['prix'];
      if (prices is List) {
        for (var p in prices) {
          if ((p['nom'] ?? '').toString().toUpperCase() == fuelName.toUpperCase()) {
            return (p['valeur'] as num).toDouble();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Extraction robuste des coordonnées (gère tous les formats possibles de l'API)
  LatLng? getStationCoordinates(dynamic record) {
    try {
      // 1. Format geom standard {lat: ..., lon: ...}
      var geom = record['geom'];
      if (geom != null) {
        if (geom['lat'] != null && geom['lon'] != null) {
          return LatLng(double.parse(geom['lat'].toString()), double.parse(geom['lon'].toString()));
        }
        // Format geom de type GeoJSON {lat: ..., lon: ...} ou coordinates [lon, lat]
        if (geom['coordinates'] is List && geom['coordinates'].length >= 2) {
          return LatLng(
            double.parse(geom['coordinates'][1].toString()),
            double.parse(geom['coordinates'][0].toString()),
          );
        }
      }

      // 2. Format coor
      var coor = record['coor'];
      if (coor != null && coor['lat'] != null && coor['lon'] != null) {
        return LatLng(double.parse(coor['lat'].toString()), double.parse(coor['lon'].toString()));
      }

      // 3. Champs directs latitude / longitude
      if (record['latitude'] != null && record['longitude'] != null) {
        return LatLng(
          double.parse(record['latitude'].toString()),
          double.parse(record['longitude'].toString()),
        );
      }
    } catch (_) {}
    return null;
  }

  void findCheapestInUserZone() {
    if (stations.isEmpty) return;

    dynamic cheapestRecord;
    double minPrice = double.infinity;
    double maxRadiusMeters = 15000; 

    for (var record in stations) {
      LatLng? coords = getStationCoordinates(record);
      double? price = getPriceForFuel(record, selectedFuel);

      if (coords != null && price != null) {
        double distance = distanceCalculator.as(LengthUnit.Meter, userPosition, coords);
        if (distance <= maxRadiusMeters && price < minPrice) {
          minPrice = price;
          cheapestRecord = record;
        }
      }
    }

    if (cheapestRecord != null) {
      LatLng? coords = getStationCoordinates(cheapestRecord);
      if (coords != null) {
        mapController.move(coords, 14.0);
      }
      showAllFuelPrices(cheapestRecord);
    } else {
      for (var record in stations) {
        double? price = getPriceForFuel(record, selectedFuel);
        if (price != null && price < minPrice) {
          minPrice = price;
          cheapestRecord = record;
        }
      }
      if (cheapestRecord != null) {
        LatLng? coords = getStationCoordinates(cheapestRecord);
        if (coords != null) mapController.move(coords, 12.0);
        showAllFuelPrices(cheapestRecord);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucune station trouvée pour le $selectedFuel')),
        );
      }
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

  void showAllFuelPrices(dynamic record) {
    String name = record['nom'] ?? record['adresse']?['ligne'] ?? 'Station service';
    String city = record['ville'] ?? record['adresse']?['ville'] ?? '';
    LatLng? coords = getStationCoordinates(record);

    List<String> fuels = ['SP95', 'SP98', 'E10', 'Gazole', 'E85'];

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
              const Text('Tous les prix disponibles :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Column(
                children: fuels.map((fuel) {
                  double? price = getPriceForFuel(record, fuel);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fuel, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(price != null ? '${price.toStringAsFixed(3)} €' : 'Non disponible',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: price != null ? Colors.black87 : Colors.grey,
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (coords != null)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          openWaze(coords.latitude, coords.longitude);
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
                          openGoogleMaps(coords.latitude, coords.longitude);
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

    for (var record in stations) {
      LatLng? coords = getStationCoordinates(record);
      double? price = getPriceForFuel(record, selectedFuel);

      if (coords != null && price != null) {
        markers.add(
          Marker(
            point: coords,
            width: 70,
            height: 30,
            child: GestureDetector(
              onTap: () => showAllFuelPrices(record),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black87, width: 1),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
                child: Center(
                  child: Text(
                    '${price.toStringAsFixed(3)}€',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
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
          if (isLoading)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Chargement des stations d\'IDF...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 45,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Carburant :', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: selectedFuel,
                        underline: const SizedBox(),
                        items: ['SP95', 'SP98', 'E10', 'Gazole', 'E85']
                            .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))))
                            .toList(),
                        onChanged: (val) => setState(() => selectedFuel = val!),
                      ),
                    ],
                  ),
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
                    onPressed: findCheapestInUserZone,
                    icon: const Icon(Icons.local_offer),
                    label: Text('Station la moins chère autour de moi ($selectedFuel)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
