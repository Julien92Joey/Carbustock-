import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CarbuStockApp());
}

class CarbuStockApp extends StatelessWidget {
  const CarbuStockApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbuStock IDF - Live API',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
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
  String currentCity = 'Rueil-Malmaison';

  LatLng userPosition = const LatLng(48.8878, 2.1807); // Position par défaut (Rueil)
  bool isLocating = false;
  bool isLoadingStations = false;
  final MapController mapController = MapController();

  List<Map<String, dynamic>> stations = [];

  @override
  void initState() {
    super.initState();
    _determinePositionAndFetch();
  }

  Future<void> _determinePositionAndFetch() async {
    setState(() { isLocating = true; isLoadingStations = true; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { isLocating = false; isLoadingStations = false; });
        _fetchStationsFromApi(userPosition.latitude, userPosition.longitude);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { isLocating = false; isLoadingStations = false; });
          _fetchStationsFromApi(userPosition.latitude, userPosition.longitude);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() { isLocating = false; isLoadingStations = false; });
        _fetchStationsFromApi(userPosition.latitude, userPosition.longitude);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        userPosition = LatLng(position.latitude, position.longitude);
        isLocating = false;
      });

      mapController.move(userPosition, 15.5);
      await _fetchStationsFromApi(userPosition.latitude, userPosition.longitude);

    } catch (e) {
      setState(() { isLocating = false; isLoadingStations = false; });
      _fetchStationsFromApi(userPosition.latitude, userPosition.longitude);
    }
  }

  Future<void> _fetchStationsFromApi(double lat, double lon) async {
    setState(() { isLoadingStations = true; });
    try {
      final url = Uri.parse(
        'https://prix-carburants.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane/records?'
        'where=distance(geom, geompoint($lon, $lat), 15km)&limit=100'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        List<Map<String, dynamic>> loadedStations = [];

        for (var record in results) {
          final geom = record['geom']?['coordinates'];
          if (geom != null && geom.length >= 2) {
            double stationLon = geom[0];
            double stationLat = geom[1];
            String name = record['brand'] ?? record['name'] ?? 'Station Service';
            String city = record['ville'] ?? 'Île-de-France';
            
            Map<String, double> fuels = {};
            
            if (record['sp95_prix'] != null) fuels['SP95'] = (record['sp95_prix'] as num).toDouble();
            if (record['sp98_prix'] != null) fuels['SP98'] = (record['sp98_prix'] as num).toDouble();
            if (record['e10_prix'] != null) fuels['E10'] = (record['e10_prix'] as num).toDouble();
            if (record['gazole_prix'] != null) fuels['Gazole'] = (record['gazole_prix'] as num).toDouble();
            if (record['e85_prix'] != null) fuels['E85'] = (record['e85_prix'] as num).toDouble();

            if (fuels.isNotEmpty) {
              loadedStations.add({
                'name': name.toUpperCase(),
                'city': city,
                'lat': stationLat,
                'lon': stationLon,
                'baseFuels': fuels,
              });
            }
          }
        }

        setState(() {
          stations = loadedStations;
          isLoadingStations = false;
        });
      } else {
        setState(() { isLoadingStations = false; });
      }
    } catch (e) {
      setState(() { isLoadingStations = false; });
    }
  }

  double getStationPrice(Map<String, dynamic> station) {
    Map<String, dynamic> fuels = station['baseFuels'];
    if (fuels.containsKey(selectedFuel)) {
      return fuels[selectedFuel];
    }
    if (fuels.isNotEmpty) {
      return fuels.values.first;
    }
    return 0.0;
  }

  double getSelectedLiters() {
    return double.parse(selectedVolume.replaceAll('L', ''));
  }

  Future<void> openWaze(double lat, double lon) async {
    final Uri wazeUri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri webWaze = Uri.parse('https://www.waze.com/ul?ll=$lat,$lon&navigate=yes');
      await launchUrl(webWaze, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> openGoogleMaps(double lat, double lon) async {
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  void showStationDetails(Map<String, dynamic> station) {
    Map<String, dynamic> fuels = station['baseFuels'];
    double liters = getSelectedLiters();
    double currentFuelPrice = getStationPrice(station);
    double totalFullTank = currentFuelPrice * liters;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      station['name'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'API Officielle Live',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Ville : ${station['city']}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Plein de $selectedVolume en $selectedFuel :',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade900, fontSize: 13),
                    ),
                    Text(
                      '${totalFullTank > 0 ? totalFullTank.toStringAsFixed(2) : "N/C"} €',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tarifs en direct de la station :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: fuels.keys.map((fuelKey) {
                    double price = fuels[fuelKey];
                    bool isSelected = (fuelKey == selectedFuel);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fuelKey,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.blue.shade700 : Colors.black87,
                            ),
                          ),
                          Text(
                            '$price € /L',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.blue.shade700 : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'S\'y rendre avec :',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF33CCFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        openWaze(station['lat'], station['lon']);
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Waze', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        openGoogleMaps(station['lat'], station['lon']);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void goToCheapestStation() {
    if (stations.isEmpty) return;

    Map<String, dynamic> cheapest = stations.first;
    double minPrice = getStationPrice(cheapest);

    for (var station in stations) {
      double price = getStationPrice(station);
      if (price > 0 && price < minPrice) {
        minPrice = price;
        cheapest = station;
      }
    }

    mapController.move(LatLng(cheapest['lat'], cheapest['lon']), 16.0);
    showStationDetails(cheapest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: userPosition,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carbustock',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: userPosition,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location,
                          color: Colors.blueAccent,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  ...stations.map((station) {
                    double currentPrice = getStationPrice(station);
                    return Marker(
                      point: LatLng(station['lat'], station['lon']),
                      width: 82,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => showStationDetails(station),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black54, width: 0.7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                station['name'],
                                style: const TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 0.5),
                              Text(
                                currentPrice > 0 ? '$currentPrice€' : 'N/C',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          Positioned(
            top: 45,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CarbuStock Live',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Row(
                      children: [
                        const Text('📍 ', style: TextStyle(fontSize: 12)),
                        Text(
                          isLoadingStations ? 'Chargement live...' : '${stations.length} stations proches',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: selectedVolume,
                      underline: const SizedBox(),
                      items: ['20L', '30L', '40L', '50L', '60L', '70L', '80L']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedVolume = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedFuel,
                      underline: const SizedBox(),
                      items: ['E10', 'SP98', 'SP95', 'Gazole', 'E85']
                          .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontWeight: FontWeight.bold))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedFuel = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              onPressed: _determinePositionAndFetch,
              child: isLocating || isLoadingStations
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: goToCheapestStation,
              icon: const Icon(Icons.navigation, size: 16),
              label: const Text(
                'MOINS CHÈRE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
