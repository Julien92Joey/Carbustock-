import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'models/station.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbuStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<Station> _stations = [];
  String _selectedFuel = 'E10';
  final MapController _mapController = MapController();

  LatLng _currentCenter = const LatLng(48.8878, 2.1807); // Position par défaut
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isLoadingLocation = false;
  bool _isLoadingStations = false;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocationService() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      _fetchStations();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        _fetchStations();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      _fetchStations();
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _currentCenter = _userLocation!;
          _isLoadingLocation = false;
        });
        _mapController.move(_currentCenter, 13.5);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }

    _fetchStations();
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.5);
    } else {
      _initLocationService();
    }
  }

  String _extractBrandName(String address, String city) {
    final String fullText = '$address $city'.toUpperCase();
    final brands = [
      'TOTAL', 'LECLERC', 'E.LECLERC', 'INTERMARCHE',
      'CARREFOUR', 'BP', 'ESSO', 'SHELL', 'AUCHAN', 'CASINO', 'CORA',
      'SYSTEME U', 'SUPER U', 'HYPER U', 'AVIA', 'NETTO'
    ];

    for (final b in brands) {
      if (fullText.contains(b)) return b;
    }
    return city.isNotEmpty ? city.toUpperCase() : 'STATION';
  }

  Future<void> _fetchStations() async {
    if (!mounted) return;
    setState(() => _isLoadingStations = true);

    final url = Uri.parse(
      'https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json?limit=100',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List<dynamic>;
        final List<Station> loadedStations = [];

        for (final item in results) {
          final geom = item['geom'];
          if (geom == null || geom['lon'] == null || geom['lat'] == null) continue;

          final double lat = (geom['lat'] as num).toDouble();
          final double lon = (geom['lon'] as num).toDouble();

          final String address = item['adresse']?.toString() ?? '';
          final String city = item['ville']?.toString() ?? '';
          final String brandName = _extractBrandName(address, city);

          final Map<String, double> prices = {};
          final List<String> short = [];

          final fuels = ['gazole', 'e10', 'e5', 'sp98', 'e85', 'gplc'];
          for (final f in fuels) {
            final priceVal = item['${f}_prix'];
            if (priceVal != null) {
              prices[f.toUpperCase()] = (priceVal as num).toDouble();
            }
          }

          final rupturesVal = item['rupture'];
          if (rupturesVal != null && rupturesVal is String) {
            for (var r in rupturesVal.split(';')) {
              short.add(r.trim().toUpperCase());
            }
          }

          loadedStations.add(Station(
            id: item['id']?.toString() ?? UniqueKey().toString(),
            name: brandName,
            address: '$address $city'.trim(),
            latitude: lat,
            longitude: lon,
            prices: prices,
            shortages: short,
          ));
        }

        if (mounted) {
          setState(() {
            _stations.clear();
            _stations.addAll(loadedStations);
            _isLoadingStations = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStations = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStations = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement des stations.')),
        );
      }
    }
  }

  void _findCheapestNearbyStation() {
    if (_stations.isEmpty) return;

    final center = _userLocation ?? _currentCenter;
    final candidates = _stations.where((s) {
      final hasFuel = s.prices.containsKey(_selectedFuel) && !s.shortages.contains(_selectedFuel);
      final distance = Geolocator.distanceBetween(center.latitude, center.longitude, s.latitude, s.longitude);
      return hasFuel && distance <= 25000; // Rayon de 25km
    }).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune station disponible à proximité pour ce carburant.')),
      );
      return;
    }

    candidates.sort((a, b) => a.prices[_selectedFuel]!.compareTo(b.prices[_selectedFuel]!));
    final cheapest = candidates.first;

    _mapController.move(LatLng(cheapest.latitude, cheapest.longitude), 14.5);
    _showStationDetails(cheapest);
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final Uri appUri = Uri.parse('google.navigation:q=$lat,$lng');
    final Uri webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Color _getMarkerColor(Station station) {
    if (station.shortages.contains(_selectedFuel)) return Colors.red;
    if (station.prices.containsKey(_selectedFuel)) return Colors.green.shade700;
    return Colors.grey;
  }

  void _showStationDetails(Station station) {
    final center = _userLocation ?? _currentCenter;
    final distanceMeters = Geolocator.distanceBetween(
      center.latitude,
      center.longitude,
      station.latitude,
      station.longitude,
    );
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$distanceKm km',
                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              station.address,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tous les carburants :',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            if (station.prices.isEmpty)
              const Text('Aucun tarif disponible.', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: station.prices.entries.map((entry) {
                  final isSelectedFuel = entry.key == _selectedFuel;
                  final isRupture = station.shortages.contains(entry.key);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelectedFuel ? Colors.blue.shade50.withOpacity(0.5) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelectedFuel ? Colors.blue : Colors.grey.shade300,
                        width: isSelectedFuel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelectedFuel ? Colors.blue.shade700 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRupture ? 'Rupture' : '${entry.value.toStringAsFixed(3)} €',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRupture ? Colors.red : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openNavigation(station.latitude, station.longitude);
                },
                icon: const Icon(Icons.navigation),
                label: const Text('LANCER L\'ITINÉRAIRE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbuStock'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Bouton de rafraîchissement manuel
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStations,
            tooltip: 'Rafraîchir les prix',
          ),
          DropdownButton<String>(
            value: _selectedFuel,
            dropdownColor: Colors.blue,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: <String>['E10', 'E5', 'SP98', 'GAZOLE', 'GPLC', 'E85']
                .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedFuel = val);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentCenter, initialZoom: 12.0),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/positron/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.carbustock',
              ),
              MarkerLayer(
                markers: _stations.map((station) {
                  final color = _getMarkerColor(station);
                  final price = station.prices[_selectedFuel];
                  return Marker(
                    point: LatLng(station.latitude, station.longitude),
                    width: 76,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _showStationDetails(station),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold)),
                            Text(price != null ? '${price.toStringAsFixed(2)}€' : 'RPT', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 16,
            child: FloatingActionButton.extended(
              onPressed: _findCheapestNearbyStation,
              backgroundColor: Colors.green.shade600,
              icon: const Icon(Icons.bolt),
              label: const Text('MOINS CHÈRE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (_isLoadingStations)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                color: Colors.white.withOpacity(0.9),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Mise à jour des stations...',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
