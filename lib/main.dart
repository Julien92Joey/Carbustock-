import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CarbuStockApp());
}

class CarbuStockApp extends StatelessWidget {
  const CarbuStockApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbuStock - Île-de-France',
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
  String selectedVolume = '50L';
  String selectedFuel = 'E10';
  
  // Ville ou zone active par défaut
  String currentCity = 'Rueil-Malmaison';

  // Indice d'évolution des prix basé sur le baril de pétrole
  double barrelPriceIndex = 1.02;

  final MapController mapController = MapController();

  // Liste complète des stations en Île-de-France
  final List<Map<String, dynamic>> stations = [
    // Rueil-Malmaison (Hauts-de-Seine)
    {
      'name': 'AVIA PAUL DOUMER', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8750, 
      'lon': 2.1650,
      'fuels': {'E10': 2.339, 'SP98': 2.449, 'Gazole': 2.569, 'SP95': 2.389, 'E85': 0.995}
    },
    {
      'name': 'ESSO EMPEREUR', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8780, 
      'lon': 2.1720,
      'fuels': {'E10': 2.279, 'SP98': 2.449, 'Gazole': 2.529, 'SP95': 2.350, 'E85': 0.950}
    },
    {
      'name': 'TOTAL 18 JUIN', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8680, 
      'lon': 2.1600,
      'fuels': {'E10': 1.990, 'SP98': 1.990, 'Gazole': 2.250, 'SP95': 1.950, 'E85': 0.850}
    },
    {
      'name': 'TOTAL POMPIDOU', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8684, 
      'lon': 2.1987,
      'fuels': {'E10': 1.950, 'SP98': 2.020, 'Gazole': 2.190, 'SP95': 1.980, 'E85': 0.820}
    },
    // Paris
    {
      'name': 'TOTALENERGIES P16', 
      'city': 'Paris',
      'lat': 48.8566, 
      'lon': 2.2770,
      'fuels': {'E10': 2.050, 'SP98': 2.150, 'Gazole': 2.100, 'SP95': 2.080, 'E85': 0.890}
    },
    {
      'name': 'BP PORTE MAILLOT', 
      'city': 'Paris',
      'lat': 48.8785, 
      'lon': 2.2820,
      'fuels': {'E10': 2.120, 'SP98': 2.220, 'Gazole': 2.180, 'SP95': 2.150, 'E85': 0.920}
    },
    // Nanterre (Hauts-de-Seine)
    {
      'name': 'LECLERC NANTERRE', 
      'city': 'Nanterre',
      'lat': 48.8920, 
      'lon': 2.2060,
      'fuels': {'E10': 1.750, 'SP98': 1.850, 'Gazole': 1.700, 'SP95': 1.800, 'E85': 0.750}
    },
    // Versailles (Yvelines)
    {
      'name': 'TOTAL VERSAILLES', 
      'city': 'Versailles',
      'lat': 48.8014, 
      'lon': 2.1301,
      'fuels': {'E10': 1.960, 'SP98': 2.040, 'Gazole': 1.920, 'SP95': 1.990, 'E85': 0.830}
    },
    // Saint-Denis (Seine-Saint-Denis)
    {
      'name': 'CARREFOUR ST-DENIS', 
      'city': 'Saint-Denis',
      'lat': 48.9360, 
      'lon': 2.3570,
      'fuels': {'E10': 1.780, 'SP98': 1.880, 'Gazole': 1.740, 'SP95': 1.820, 'E85': 0.780}
    },
  ];

  // Calcule le prix en fonction du carburant choisi et de l'indice du baril
  double getStationPrice(Map<String, dynamic> station) {
    double rawPrice = station['fuels'][selectedFuel] ?? 2.00;
    return double.parse((rawPrice * barrelPriceIndex).toStringAsFixed(2));
  }

  // Fonction pour ouvrir Waze
  Future<void> openWaze(double lat, double lon) async {
    final Uri wazeUri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback web si l'application Waze n'est pas installée
      final Uri webWaze = Uri.parse('https://www.waze.com/ul?ll=$lat,$lon&navigate=yes');
      await launchUrl(webWaze, mode: LaunchMode.externalApplication);
    }
  }

  // Fonction pour ouvrir Google Maps
  Future<void> openGoogleMaps(double lat, double lon) async {
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  // Affiche la modale d'information et de choix de GPS lorsqu'on clique sur une station
  void showStationDetails(Map<String, dynamic> station) {
    double price = getStationPrice(station);
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
              Text(
                station['name'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Ville : ${station['city']}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                'Prix actuel ($selectedFuel) : $price €',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 20),
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
                        backgroundColor: const Color(0xFF33CCFF), // Couleur Waze
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
                        backgroundColor: Colors.redAccent, // Couleur Google Maps
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

  // Trouve la station la moins chère dans la ville/zone actuelle
  void goToCheapestInCurrentCity() {
    List<Map<String, dynamic>> localStations = stations
        .where((station) => station['city'].toLowerCase() == currentCity.toLowerCase())
        .toList();

    if (localStations.isEmpty) {
      localStations = stations;
    }

    Map<String, dynamic> cheapest = localStations.first;
    double minPrice = getStationPrice(cheapest);

    for (var station in localStations) {
      double price = getStationPrice(station);
      if (price < minPrice) {
        minPrice = price;
        cheapest = station;
      }
    }

    setState(() {
      currentCity = cheapest['city'];
    });

    mapController.move(LatLng(cheapest['lat'], cheapest['lon']), 13.0);
    showStationDetails(cheapest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fond de carte OpenStreetMap
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(48.8738, 2.1704),
              initialZoom: 11.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carbustock',
              ),
              MarkerLayer(
                markers: stations.map((station) {
                  double currentPrice = getStationPrice(station);
                  return Marker(
                    point: LatLng(station['lat'], station['lon']),
                    width: 95,
                    height: 42,
                    child: GestureDetector(
                      onTap: () => showStationDetails(station), // Clic sur la station
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.black54, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 3,
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
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$currentPrice€',
                              style: const TextStyle(
                                fontSize: 11,
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
              ),
            ],
          ),

          // En-tête avec filtres et zone actuelle
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
                      'CarbuStock IDF',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text(
                      '📍 $currentCity',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Capacité du réservoir (20L à 80L)
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
                    // Type de carburant
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

          // Bouton de géolocalisation globale (bas droite)
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: () {
                setState(() {
                  currentCity = 'Rueil-Malmaison';
                });
                mapController.move(const LatLng(48.8738, 2.1704), 12.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bouton "MOINS CHÈRE" (bas gauche)
          Positioned(
            bottom: 30,
            left: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: goToCheapestInCurrentCity,
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
