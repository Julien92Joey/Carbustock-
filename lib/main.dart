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
      title: 'CarbuStock Île-de-France',
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
  
  // Ville ou zone active par défaut (Rueil-Malmaison)
  String currentCity = 'Rueil-Malmaison';

  // Prix du baril de Brent de référence (en dollars) - Indexation dynamique
  double barrelPriceUSD = 99.33;

  // Position GPS par défaut (Rueil-Malmaison)
  final LatLng userPosition = const LatLng(48.8738, 2.1704);

  final MapController mapController = MapController();

  // Liste complète des stations en Île-de-France
  final List<Map<String, dynamic>> stations = [
    // Rueil-Malmaison & Hauts-de-Seine (92)
    {
      'name': 'LECLERC RUEIL', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8820, 
      'lon': 2.1550,
      'baseFuels': {'E10': 1.65, 'SP98': 1.75, 'Gazole': 1.62, 'SP95': 1.70, 'E85': 0.70}
    },
    {
      'name': 'TOTAL 18 JUIN', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8680, 
      'lon': 2.1600,
      'baseFuels': {'E10': 1.85, 'SP98': 1.95, 'Gazole': 2.05, 'SP95': 1.88, 'E85': 0.78}
    },
    {
      'name': 'AVIA DOUMER', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8750, 
      'lon': 2.1650,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 2.15, 'SP95': 1.99, 'E85': 0.85}
    },
    {
      'name': 'ESSO EMPEREUR', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8780, 
      'lon': 2.1720,
      'baseFuels': {'E10': 1.90, 'SP98': 2.02, 'Gazole': 2.10, 'SP95': 1.94, 'E85': 0.82}
    },
    {
      'name': 'TOTAL POMPIDOU', 
      'city': 'Rueil-Malmaison',
      'lat': 48.8684, 
      'lon': 2.1987,
      'baseFuels': {'E10': 1.82, 'SP98': 1.92, 'Gazole': 2.02, 'SP95': 1.85, 'E85': 0.76}
    },
    {
      'name': 'LECLERC NANTERRE', 
      'city': 'Nanterre',
      'lat': 48.8920, 
      'lon': 2.2060,
      'baseFuels': {'E10': 1.64, 'SP98': 1.74, 'Gazole': 1.60, 'SP95': 1.69, 'E85': 0.71}
    },
    {
      'name': 'ESSO DEFENSE', 
      'city': 'Courbevoie',
      'lat': 48.8905, 
      'lon': 2.2470,
      'baseFuels': {'E10': 1.92, 'SP98': 2.02, 'Gazole': 2.12, 'SP95': 1.95, 'E85': 0.83}
    },
    {
      'name': 'TOTAL BOULOGNE', 
      'city': 'Boulogne-Billancourt',
      'lat': 48.8397, 
      'lon': 2.2450,
      'baseFuels': {'E10': 1.89, 'SP98': 1.99, 'Gazole': 2.09, 'SP95': 1.92, 'E85': 0.81}
    },

    // Paris (75)
    {
      'name': 'TOTAL PARIS BERCY', 
      'city': 'Paris',
      'lat': 48.8360, 
      'lon': 2.3830,
      'baseFuels': {'E10': 1.98, 'SP98': 2.09, 'Gazole': 2.18, 'SP95': 2.01, 'E85': 0.88}
    },
    {
      'name': 'BP PORTE MAILLOT', 
      'city': 'Paris',
      'lat': 48.8785, 
      'lon': 2.2820,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 2.15, 'SP95': 1.99, 'E85': 0.86}
    },
    {
      'name': 'AVIA ITALIE', 
      'city': 'Paris',
      'lat': 48.8280, 
      'lon': 2.3550,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 2.13, 'SP95': 1.97, 'E85': 0.84}
    },

    // Seine-Saint-Denis (93)
    {
      'name': 'LECLERC BOBIGNY', 
      'city': 'Bobigny',
      'lat': 48.9090, 
      'lon': 2.4400,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.69}
    },
    {
      'name': 'TOTAL SAINT-DENIS', 
      'city': 'Saint-Denis',
      'lat': 48.9360, 
      'lon': 2.3570,
      'baseFuels': {'E10': 1.86, 'SP98': 1.96, 'Gazole': 2.06, 'SP95': 1.89, 'E85': 0.79}
    },

    // Val-de-Marne (94)
    {
      'name': 'CARREFOUR CRETEIL', 
      'city': 'Créteil',
      'lat': 48.7770, 
      'lon': 2.4500,
      'baseFuels': {'E10': 1.63, 'SP98': 1.73, 'Gazole': 1.59, 'SP95': 1.68, 'E85': 0.70}
    },
    {
      'name': 'TOTAL IVRY', 
      'city': 'Ivry-sur-Seine',
      'lat': 48.8150, 
      'lon': 2.3900,
      'baseFuels': {'E10': 1.88, 'SP98': 1.98, 'Gazole': 2.08, 'SP95': 1.91, 'E85': 0.80}
    },

    // Yvelines (78)
    {
      'name': 'TOTAL VERSAILLES', 
      'city': 'Versailles',
      'lat': 48.8014, 
      'lon': 2.1301,
      'baseFuels': {'E10': 1.84, 'SP98': 1.94, 'Gazole': 2.04, 'SP95': 1.87, 'E85': 0.77}
    },
    {
      'name': 'LECLERC SARTROUVILLE', 
      'city': 'Sartrouville',
      'lat': 48.9380, 
      'lon': 2.1530,
      'baseFuels': {'E10': 1.61, 'SP98': 1.71, 'Gazole': 1.57, 'SP95': 1.66, 'E85': 0.68}
    },

    // Essonne (91)
    {
      'name': 'AUCHAN BRETIGNY', 
      'city': 'Brétigny-sur-Orge',
      'lat': 48.6120, 
      'lon': 2.3080,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.69}
    },
    {
      'name': 'TOTAL EVRY', 
      'city': 'Évry-Courcouronnes',
      'lat': 48.6290, 
      'lon': 2.4380,
      'baseFuels': {'E10': 1.87, 'SP98': 1.97, 'Gazole': 2.07, 'SP95': 1.90, 'E85': 0.80}
    },

    // Seine-et-Marne (77)
    {
      'name': 'LECLERC MEAUX', 
      'city': 'Meaux',
      'lat': 48.9590, 
      'lon': 2.8870,
      'baseFuels': {'E10': 1.60, 'SP98': 1.70, 'Gazole': 1.56, 'SP95': 1.65, 'E85': 0.67}
    },
    {
      'name': 'TOTAL CHELLES', 
      'city': 'Chelles',
      'lat': 48.8780, 
      'lon': 2.5920,
      'baseFuels': {'E10': 1.85, 'SP98': 1.95, 'Gazole': 2.05, 'SP95': 1.88, 'E85': 0.78}
    },

    // Val-d'Oise (95)
    {
      'name': 'LECLERC CERGY', 
      'city': 'Cergy',
      'lat': 49.0380, 
      'lon': 2.0740,
      'baseFuels': {'E10': 1.61, 'SP98': 1.71, 'Gazole': 1.57, 'SP95': 1.66, 'E85': 0.68}
    },
    {
      'name': 'TOTAL ARGENTEUIL', 
      'city': 'Argenteuil',
      'lat': 48.9480, 
      'lon': 2.2480,
      'baseFuels': {'E10': 1.86, 'SP98': 1.96, 'Gazole': 2.06, 'SP95': 1.89, 'E85': 0.79}
    },
  ];

  // Calcul du prix indexé sur le baril
  double getSpecificPrice(Map<String, dynamic> station, String fuelKey) {
    double basePrice = station['baseFuels'][fuelKey] ?? 1.80;
    double indexFactor = barrelPriceUSD / 80.0;
    double calculatedPrice = basePrice * indexFactor;
    return double.parse(calculatedPrice.toStringAsFixed(2));
  }

  double getStationPrice(Map<String, dynamic> station) {
    return getSpecificPrice(station, selectedFuel);
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
    Map<String, dynamic> baseFuels = station['baseFuels'];
    double liters = getSelectedLiters();
    double currentFuelPrice = getSpecificPrice(station, selectedFuel);
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
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Baril : ${barrelPriceUSD.toStringAsFixed(1)} \$',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
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

              // Encadré Estimation du Plein
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
                      '${totalFullTank.toStringAsFixed(2)} €',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'Grille complète des tarifs :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: baseFuels.keys.map((fuelKey) {
                    double price = getSpecificPrice(station, fuelKey);
                    bool isSelected = (fuelKey == selectedFuel);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
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

  // Bouton "Moins chère" filtré par la ville active (ex: Rueil ou Paris, etc.)
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
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: userPosition,
              initialZoom: 11.0, // Zoom adapté pour voir toute l'Île-de-France
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carbustock',
              ),
              MarkerLayer(
                markers: [
                  // Marqueur de la géolocalisation utilisateur
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
                  // Marqueurs de toutes les stations d'Île-de-France (taille optimisée)
                  ...stations.map((station) {
                    double currentPrice = getStationPrice(station);
                    return Marker(
                      point: LatLng(station['lat'], station['lon']),
                      width: 82, // Légèrement plus compact
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
                                  fontSize: 7.5, // Nom plus petit et lisible
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 0.5),
                              Text(
                                '$currentPrice€',
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

          // En-tête / Filtres
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
                    Row(
                      children: [
                        const Text(
                          '📍 ',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          currentCity,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              barrelPriceUSD = barrelPriceUSD == 99.33 ? 105.0 : 99.33;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '🛢️ ${barrelPriceUSD.toStringAsFixed(1)}\$',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
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

          // Bouton recentrage GPS utilisateur
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              onPressed: () {
                setState(() {
                  currentCity = 'Rueil-Malmaison';
                });
                mapController.move(userPosition, 12.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bouton "MOINS CHÈRE" pour la ville active
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
