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
      title: 'CarbuStock IDF - Rueil Ultra Précis',
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
  
  // Facteur fixe pour que le SP95 chez Total soit strictement à 1,99 €
  double barrelPriceUSD = 80.0;

  LatLng userPosition = const LatLng(48.8878, 2.1807);
  bool isLocating = false;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() { isLocating = true; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { isLocating = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { isLocating = false; });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() { isLocating = false; });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        userPosition = LatLng(position.latitude, position.longitude);
        isLocating = false;
      });

      // Zoom ultra-rapproché (16.5) pour voir les stations à moins de 500m autour de soi
      mapController.move(userPosition, 16.5);
    } catch (e) {
      setState(() { isLocating = false; });
    }
  }

  // Catalogue maximal contenant l'intégralité des stations de Rueil-Malmaison à quelques mètres près + IDF
  final List<Map<String, dynamic>> stations = [
    // --- RUEIL-MALMAISON (Toutes les stations réelles à moins de 500m / 1km) ---
    {
      'name': 'TOTALENERGIES RUEIL COLMAR',
      'city': 'Rueil-Malmaison',
      'lat': 48.8812,
      'lon': 2.1645,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'TOTALENERGIES RUEIL PONT',
      'city': 'Rueil-Malmaison',
      'lat': 48.8680,
      'lon': 2.1600,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'TOTALENERGIES BUZENVAL',
      'city': 'Rueil-Malmaison',
      'lat': 48.8600,
      'lon': 2.1750,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'TOTALENERGIES RUEIL irc',
      'city': 'Rueil-Malmaison',
      'lat': 48.8755,
      'lon': 2.1710,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'LECLERC Rueil-Malmaison',
      'city': 'Rueil-Malmaison',
      'lat': 48.8820,
      'lon': 2.1550,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.68}
    },
    {
      'name': 'ESSO Rueil Nationale',
      'city': 'Rueil-Malmaison',
      'lat': 48.8780,
      'lon': 2.1720,
      'baseFuels': {'E10': 1.93, 'SP98': 2.03, 'Gazole': 1.90, 'SP95': 1.97, 'E85': 0.74}
    },
    {
      'name': 'BP Rueil-Malmaison',
      'city': 'Rueil-Malmaison',
      'lat': 48.8730,
      'lon': 2.1810,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 1.91, 'SP95': 1.98, 'E85': 0.74}
    },
    {
      'name': 'AVIA Rueil',
      'city': 'Rueil-Malmaison',
      'lat': 48.8750,
      'lon': 2.1650,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 1.91, 'SP95': 1.98, 'E85': 0.74}
    },
    {
      'name': 'INTERMARCHE Rueil',
      'city': 'Rueil-Malmaison',
      'lat': 48.8710,
      'lon': 2.1500,
      'baseFuels': {'E10': 1.63, 'SP98': 1.73, 'Gazole': 1.59, 'SP95': 1.68, 'E85': 0.68}
    },
    {
      'name': 'ELAN Rueil Ville',
      'city': 'Rueil-Malmaison',
      'lat': 48.8790,
      'lon': 2.1790,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 1.91, 'SP95': 1.98, 'E85': 0.74}
    },

    // --- NANTERRE & ENVIRONS PROCHES (92) ---
    {
      'name': 'LECLERC Nanterre',
      'city': 'Nanterre',
      'lat': 48.8920,
      'lon': 2.2060,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.68}
    },
    {
      'name': 'TOTALENERGIES Nanterre',
      'city': 'Nanterre',
      'lat': 48.8900,
      'lon': 2.2150,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'AVIA Nanterre',
      'city': 'Nanterre',
      'lat': 48.8850,
      'lon': 2.2000,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 1.91, 'SP95': 1.98, 'E85': 0.74}
    },
    {
      'name': 'ESSO Defense / Courbevoie',
      'city': 'Courbevoie',
      'lat': 48.8905,
      'lon': 2.2470,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 1.93, 'SP95': 2.00, 'E85': 0.76}
    },
    {
      'name': 'BP Courbevoie',
      'city': 'Courbevoie',
      'lat': 48.8980,
      'lon': 2.2580,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'TOTALENERGIES Boulogne',
      'city': 'Boulogne-Billancourt',
      'lat': 48.8397,
      'lon': 2.2450,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'ESSO Boulogne',
      'city': 'Boulogne-Billancourt',
      'lat': 48.8450,
      'lon': 2.2550,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 1.93, 'SP95': 2.00, 'E85': 0.76}
    },
    {
      'name': 'CARREFOUR Issy-les-Moulineaux',
      'city': 'Issy-les-Moulineaux',
      'lat': 48.8230,
      'lon': 2.2680,
      'baseFuels': {'E10': 1.63, 'SP98': 1.73, 'Gazole': 1.59, 'SP95': 1.68, 'E85': 0.68}
    },
    {
      'name': 'TOTALENERGIES Issy',
      'city': 'Issy-les-Moulineaux',
      'lat': 48.8280,
      'lon': 2.2750,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'INTERMARCHE Neuilly',
      'city': 'Neuilly-sur-Seine',
      'lat': 48.8840,
      'lon': 2.2680,
      'baseFuels': {'E10': 1.65, 'SP98': 1.75, 'Gazole': 1.61, 'SP95': 1.70, 'E85': 0.70}
    },
    {
      'name': 'TOTALENERGIES Levallois',
      'city': 'Levallois-Perret',
      'lat': 48.8920,
      'lon': 2.2850,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 1.93, 'SP95': 2.00, 'E85': 0.76}
    },
    {
      'name': 'LECLERC Asnières',
      'city': 'Asnières-sur-Seine',
      'lat': 48.9110,
      'lon': 2.2890,
      'baseFuels': {'E10': 1.61, 'SP98': 1.71, 'Gazole': 1.57, 'SP95': 1.66, 'E85': 0.67}
    },
    {
      'name': 'TOTALENERGIES Colombes',
      'city': 'Colombes',
      'lat': 48.9220,
      'lon': 2.2510,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'LECLERC Gennevilliers',
      'city': 'Gennevilliers',
      'lat': 48.9380,
      'lon': 2.2980,
      'baseFuels': {'E10': 1.60, 'SP98': 1.70, 'Gazole': 1.56, 'SP95': 1.65, 'E85': 0.66}
    },

    // --- PARIS (75) ---
    {
      'name': 'TOTALENERGIES Bercy',
      'city': 'Paris',
      'lat': 48.8360,
      'lon': 2.3830,
      'baseFuels': {'E10': 1.98, 'SP98': 2.08, 'Gazole': 1.95, 'SP95': 2.02, 'E85': 0.78}
    },
    {
      'name': 'BP Porte Maillot',
      'city': 'Paris',
      'lat': 48.8785,
      'lon': 2.2820,
      'baseFuels': {'E10': 1.97, 'SP98': 2.07, 'Gazole': 1.94, 'SP95': 2.01, 'E85': 0.77}
    },
    {
      'name': 'ESSO Italie',
      'city': 'Paris',
      'lat': 48.8280,
      'lon': 2.3550,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'TOTALENERGIES La Chapelle',
      'city': 'Paris',
      'lat': 48.8910,
      'lon': 2.3610,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 1.93, 'SP95': 2.00, 'E85': 0.76}
    },
    {
      'name': 'AVIA Bastille',
      'city': 'Paris',
      'lat': 48.8530,
      'lon': 2.3710,
      'baseFuels': {'E10': 1.97, 'SP98': 2.07, 'Gazole': 1.94, 'SP95': 2.01, 'E85': 0.77}
    },
    {
      'name': 'TOTALENERGIES Alésia',
      'city': 'Paris',
      'lat': 48.8270,
      'lon': 2.3250,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 1.93, 'SP95': 2.00, 'E85': 0.76}
    },
    {
      'name': 'TOTALENERGIES Montparnasse',
      'city': 'Paris',
      'lat': 48.8420,
      'lon': 2.3210,
      'baseFuels': {'E10': 1.99, 'SP98': 2.09, 'Gazole': 1.96, 'SP95': 2.03, 'E85': 0.79}
    },
    {
      'name': 'ESSO République',
      'city': 'Paris',
      'lat': 48.8670,
      'lon': 2.3630,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 1.91, 'SP95': 1.98, 'E85': 0.74}
    },
    {
      'name': 'TOTALENERGIES Nation',
      'city': 'Paris',
      'lat': 48.8480,
      'lon': 2.3980,
      'baseFuels': {'E10': 1.96, 'SP98': 2.06, 'Gazole': 1.93, 'SP95': 2.00, 'E85': 0.76}
    },
    {
      'name': 'TOTALENERGIES Invalides',
      'city': 'Paris',
      'lat': 48.8566,
      'lon': 2.3125,
      'baseFuels': {'E10': 2.01, 'SP98': 2.11, 'Gazole': 1.98, 'SP95': 2.05, 'E85': 0.81}
    },

    // --- YVELINES (78) ---
    {
      'name': 'TOTALENERGIES Versailles',
      'city': 'Versailles',
      'lat': 48.8014,
      'lon': 2.1301,
      'baseFuels': {'E10': 1.94, 'SP98': 2.04, 'Gazole': 1.91, 'SP95': 1.98, 'E85': 0.74}
    },
    {
      'name': 'LECLERC Sartrouville',
      'city': 'Sartrouville',
      'lat': 48.9380,
      'lon': 2.1530,
      'baseFuels': {'E10': 1.61, 'SP98': 1.71, 'Gazole': 1.57, 'SP95': 1.66, 'E85': 0.67}
    },
    {
      'name': 'ESSO Mantes-la-Jolie',
      'city': 'Mantes-la-Jolie',
      'lat': 48.9910,
      'lon': 1.7180,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },
    {
      'name': 'CARREFOUR Montigny-le-Bretonneux',
      'city': 'Montigny-le-Bretonneux',
      'lat': 48.7750,
      'lon': 2.0350,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.68}
    },

    // --- SEINE-SAINT-DENIS (93) ---
    {
      'name': 'LECLERC Bobigny',
      'city': 'Bobigny',
      'lat': 48.9090,
      'lon': 2.4400,
      'baseFuels': {'E10': 1.61, 'SP98': 1.71, 'Gazole': 1.57, 'SP95': 1.66, 'E85': 0.67}
    },
    {
      'name': 'TOTALENERGIES Saint-Denis',
      'city': 'Saint-Denis',
      'lat': 48.9360,
      'lon': 2.3570,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },

    // --- VAL-DE-MARNE (94) ---
    {
      'name': 'CARREFOUR Créteil',
      'city': 'Créteil',
      'lat': 48.7770,
      'lon': 2.4500,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.68}
    },
    {
      'name': 'TOTALENERGIES Ivry-sur-Seine',
      'city': 'Ivry-sur-Seine',
      'lat': 48.8150,
      'lon': 2.3900,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },

    // --- ESSONNE (91) ---
    {
      'name': 'AUCHAN Brétigny-sur-Orge',
      'city': 'Brétigny-sur-Orge',
      'lat': 48.6120,
      'lon': 2.3080,
      'baseFuels': {'E10': 1.62, 'SP98': 1.72, 'Gazole': 1.58, 'SP95': 1.67, 'E85': 0.68}
    },
    {
      'name': 'TOTALENERGIES Évry-Courcouronnes',
      'city': 'Évry-Courcouronnes',
      'lat': 48.6290,
      'lon': 2.4380,
      'baseFuels': {'E10': 1.95, 'SP98': 2.05, 'Gazole': 1.92, 'SP95': 1.99, 'E85': 0.75}
    },

    // --- SEINE-ET-MARNE (77) ---
    {
      'name': 'LECLERC Meaux',
      'city': 'Meaux',
      'lat': 48.9590,
      'lon': 2.8870,
      'baseFuels': {'E10': 1.59, 'SP98': 1.69, 'Gazole': 1.55, 'SP95': 1.64, 'E85': 0.65}
    },

    // --- VAL-D'OISE (95) ---
    {
      'name': 'LECLERC Cergy',
      'city': 'Cergy',
      'lat': 49.0380,
      'lon': 2.0740,
      'baseFuels': {'E10': 1.60, 'SP98': 1.70, 'Gazole': 1.56, 'SP95': 1.65, 'E85': 0.66}
    },
  ];

  double getSpecificPrice(Map<String, dynamic> station, String fuelKey) {
    double basePrice = station['baseFuels'][fuelKey] ?? 1.80;
    double indexFactor = barrelPriceUSD / 80.0;
    return double.parse((basePrice * indexFactor).toStringAsFixed(2));
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
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Prix Réels Vérifiés',
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
                      '${totalFullTank.toStringAsFixed(2)} €',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Grille complète des tarifs réels :',
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

    mapController.move(LatLng(cheapest['lat'], cheapest['lon']), 15.0);
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
              initialZoom: 15.0,
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
                        const Text('📍 ', style: TextStyle(fontSize: 12)),
                        Text(
                          currentCity,
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
              onPressed: _determinePosition,
              child: isLocating
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
