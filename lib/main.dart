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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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

  LatLng _currentCenter = const LatLng(48.8566, 2.3522);
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
      _fetchIDFStations();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        _fetchIDFStations();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      _fetchIDFStations();
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
        _mapController.move(_currentCenter, 13.0);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }

    // Suivi continu en temps réel
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });

    _fetchIDFStations();
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
    } else {
      _initLocationService();
    }
  }

  String _extractBrandName(String address, String city) {
    final String fullText = '$address $city'.toUpperCase();
    final brands = [
      'TOTAL', 'TOTALACCESS', 'LECLERC', 'E.LECLERC', 'INTERMARCHE',
      'CARREFOUR', 'BP', 'ESSO', 'SHELL', 'AUCHAN', 'CASINO', 'CORA',
      'SYSTEME U', 'SUPER U', 'HYPER U', 'AVIA', 'NETTO', 'AGIP', 'DINETT'
    ];

    for (final b in brands) {
      if (fullText.contains(b)) {
        return b;
      }
    }
    return city.isNotEmpty ? city.toUpperCase() : 'STATION';
  }

  Future<void> _fetchIDFStations() async {
    if (!mounted) return;
    setState(() => _isLoadingStations = true);

    final url = Uri.parse(
      'https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json?where=region%3D%22%C3%8Ele-de-France%22',
    );

    try {
      final response = await http.get(url);
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
            final splitRuptures = rupturesVal.split(';');
            for (var r in splitRuptures) {
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
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    final fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getMarkerColor(Station station) {
    if (station.shortages.contains(_selectedFuel)) {
      return Colors.red;
    } else if (station.prices.containsKey(_selectedFuel)) {
      return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbuStock - ÎdF'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          DropdownButton<String>(
            value: _selectedFuel,
            underline: const SizedBox(),
            icon: const Icon(Icons.local_gas_station, color: Colors.white),
            dropdownColor: Colors.blue,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: <String>['E10', 'E5', 'SP98', 'GAZOLE', 'GPLC', 'E85']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: const TextStyle(color: Colors.black)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFuel = newValue;
                });
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 11.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.carbustock',
                ),
                MarkerLayer(
                  markers: [
                    // Repère de localisation de l'utilisateur
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 1.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Marqueurs des stations de service
                    ..._stations.map((station) {
                      final color = _getMarkerColor(station);
                      final price = station.prices[_selectedFuel];
                      return Marker(
                        point: LatLng(station.latitude, station.longitude),
                        width: 76,
                        height: 48,
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(station.name, style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 4),
                                    Text(station.address),
                                    const SizedBox(height: 12),
                                    Text(
                                      price != null
                                          ? 'Prix $_selectedFuel : ${price.toStringAsFixed(3)} €/L'
                                          : 'Carburant $_selectedFuel non disponible ou en rupture.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: color == Colors.red ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _openNavigation(station.latitude, station.longitude);
                                        },
                                        icon: const Icon(Icons.navigation),
                                        label: const Text('Y ALLER (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: color, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    )
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      station.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      price != null ? '${price.toStringAsFixed(2)}€' : 'RPT',
                                      style: TextStyle(
                                        color: color == Colors.red
                                            ? Colors.redAccent
                                            : (color == Colors.green ? Colors.lightGreenAccent : Colors.white70),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
            if (_isLoadingLocation || _isLoadingStations)
              Positioned(
                top: 16,
                left: 16,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(_isLoadingLocation
                            ? 'Position GPS...'
                            : 'Chargement des stations ÎdeF...'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
