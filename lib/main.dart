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
  String selectedVolume = '40L';
  String selectedFuel = 'E10';

  LatLng userPosition = const LatLng(48.8878, 2.1807); // Position par défaut (ex: Île-de-France)
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

  // Géolocalisation de l'utilisateur
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

      mapController.move(userPosition, 14.0);
    } catch (e) {
      setState(() => isLocating = false);
    }
  }

  // Chargement de toutes les stations depuis l'API officielle
  Future<void> fetchAllStations() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://prix-carburants.gouv.fr/api/records/1.0/search/?dataset=prix-des-carburants-j-1&rows=10000'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          stations = data['records'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  double? getStationPrice(Map<String, dynamic> record) {
    final fields = record['fields'];
    if (fields == null) return null;

    String? key;
    if (selectedFuel == 'E10') key = 'prix_e10';
    else if (selectedFuel == 'SP98') key = 'prix_sp98';
    else if (selectedFuel == 'SP95') key = 'prix_sp95';
    else if (selectedFuel == 'Gazole') key = 'prix_gazole';
    else if (selectedFuel == 'E85') key = 'prix_e85';

    if (key != null && fields[key] != null) {
      return (fields[key] as num).toDouble();
    }
    return null;
  }

  LatLng? getStationCoordinates(Map<String, dynamic> record) {
    final geometry = record['geometry'];
    if (geometry != null && geometry['coordinates'] != null) {
      final coords = geometry['coordinates'];
      return LatLng(coords[1], coords[0]);
    }
    
    final fields = record['fields'];
    if (fields != null && fields['coor'] != null) {
      List coords = fields['coor'];
      if (coords.length >= 2) {
        return LatLng(coords[0] / 100000.0, coords[1] / 100000.0);
      }
    }
    return null;
  }

  // Trouver la station la moins chère dans la ville actuelle
  void findCheapestInCurrentCity() {
    if (stations.isEmpty) return;

    String? currentCity;
    double minDistance = double.infinity;

    for (var record in stations) {
      LatLng? coords = getStationCoordinates(record);
      if (coords != null) {
        double dist = distanceCalculator.as(LengthUnit.Meter, userPosition, coords);
        if (dist < minDistance) {
          minDistance = dist;
          currentCity = record['fields']?['ville']?.toString().toUpperCase();
        }
      }
    }

    if (currentCity == null) return;

    Map<String, dynamic>? cheapestRecord;
    double minPrice = double.infinity;

    for (var record in stations) {
      final fields = record['fields'];
      if (fields != null) {
        String? city = fields['ville']?.toString().toUpperCase();
        if (city == currentCity) {
          double? price = getStationPrice(record);
          if (price != null && price < minPrice) {
            minPrice = price;
            cheapestRecord = record;
          }
        }
      }
    }

    if (cheapestRecord != null) {
      LatLng? coords = getStationCoordinates(cheapestRecord);
      if (coords != null) {
        mapController.move(coords, 15.0);
      }
      showStationDetails(cheapestRecord);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune station avec $selectedFuel trouvée à $currentCity')),
      );
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
    final fields = record['fields'];
    if (fields == null) return;

    String name = fields['nom'] ?? fields['adresse'] ?? 'Station service';
    String city = fields['ville'] ?? '';
    double? price = getStationPrice(record);
    double liters = double.parse(selectedVolume.replaceAll('L', ''));
    double total = price != null ? price * liters : 0.0;
    LatLng? coords = getStationCoordinates(record);

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
                    Text('Plein de $selectedVolume ($selectedFuel) :', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(price != null ? '${total.toStringAsFixed(2)} €' : 'N/C', 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
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
                    const SizedBox(width: 10),
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

    // Marqueur utilisateur
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

    // Ajout des marqueurs de stations
    for (var record in stations) {
      LatLng? coords = getStationCoordinates(record);
      double? price = getStationPrice(record);

      if (coords != null && price != null) {
        markers.add(
          Marker(
            point: coords,
            width: 75,
            height: 35,
            child: GestureDetector(
              onTap: () => showStationDetails(record),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black45, width: 0.8),
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
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Chargement de toutes les stations...', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      child: DropdownButton<String>(
                        value: selectedVolume,
                        underline: const SizedBox(),
                        items: ['20L', '30L', '40L', '50L', '60L', '70L']
                            .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (val) => setState(() => selectedVolume = val!),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      child: DropdownButton<String>(
                        value: selectedFuel,
                        underline: const SizedBox(),
                        items: ['E10', 'SP98', 'SP95', 'Gazole', 'E85']
                            .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontWeight: FontWeight.bold))))
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
                    label: const Text('Moins cher dans ma ville', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                  ? const SizedBox(width:, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) // correction syntaxe éventuelle si besoin
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
