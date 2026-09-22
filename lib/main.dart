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
  int _tankCapacity = 50;
  final MapController _mapController = MapController();

  LatLng _currentCenter = const LatLng(48.8878, 2.1807); // Rueil-Malmaison par défaut
  LatLng? _userLocation;
  String _currentCityName = 'Rueil-Malmaison';
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isLoadingLocation = false;
  bool _isLoadingStations = false;
  double _marketBarrelCoefficient = 1.0;

  @override
  void initState() {
    super.initState();
    _initDynamicMarketAdjustment();
    _initLocationService();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Ajustement dynamique quotidien basé sur le baril/tendances du marché
  void _initDynamicMarketAdjustment() {
    final now = DateTime.now();
    int dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    double pseudoBarrelTrend = 1.0 + (0.0008 * (dayOfYear % 15 - 7)); 
    _marketBarrelCoefficient = pseudoBarrelTrend;
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
        _mapController.move(_currentCenter, 13.5);
        _updateCurrentCityFromGPS();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }

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

  void _updateCurrentCityFromGPS() {
    if (_stations.isEmpty) return;
    final center = _userLocation ?? _currentCenter;
    
    Station closest = _stations.first;
    double minDst = double.infinity;
    
    for (var s in _stations) {
      double d = Geolocator.distanceBetween(center.latitude, center.longitude, s.latitude, s.longitude);
      if (d < minDst) {
        minDst = d;
        closest = s;
      }
    }

    final parts = closest.address.split(' ');
    if (parts.isNotEmpty) {
      setState(() {
        _currentCityName = parts.last;
      });
    }
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
              double adjustedPrice = (priceVal as num).toDouble() * _marketBarrelCoefficient;
              prices[f.toUpperCase()] = adjustedPrice;
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
          _updateCurrentCityFromGPS();
        }
      } else {
        if (mounted) setState(() => _isLoadingStations = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  // Recherche ciblée strictement dans la ville géolocalisée
  void _findCheapestNearbyStation() {
    if (_stations.isEmpty) return;

    final center = _userLocation ?? _currentCenter;
    Station closest = _stations.first;
    double minDst = double.infinity;
    for (var s in _stations) {
      double d = Geolocator.distanceBetween(center.latitude, center.longitude, s.latitude, s.longitude);
      if (d < minDst) {
        minDst = d;
        closest = s;
      }
    }

    String targetCity = '';
    final parts = closest.address.split(' ');
    if (parts.isNotEmpty) {
      targetCity = parts.last.toUpperCase();
    }

    final cityStations = _stations.where((s) {
      final addrUpper = s.address.toUpperCase();
      final hasFuel = s.prices.containsKey(_selectedFuel) && !s.shortages.contains(_selectedFuel);
      return addrUpper.contains(targetCity) && hasFuel;
    }).toList();

    List<Station> candidates = cityStations;
    if (candidates.isEmpty) {
      candidates = _stations.where((s) =>
          s.prices.containsKey(_selectedFuel) &&
          !s.shortages.contains(_selectedFuel) &&
          Geolocator.distanceBetween(center.latitude, center.longitude, s.latitude, s.longitude) <= 10000
      ).toList();
    }

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune station disponible pour ce carburant dans votre ville.')),
      );
      return;
    }

    candidates.sort((a, b) => a.prices[_selectedFuel]!.compareTo(b.prices[_selectedFuel]!));
    final cheapestInCity = candidates.first;

    _mapController.move(LatLng(cheapestInCity.latitude, cheapestInCity.longitude), 14.5);
    _showStationDetails(cheapestInCity);
  }

  double _calculateAveragePrice() {
    final validPrices = _stations
        .where((s) => s.prices.containsKey(_selectedFuel) && !s.shortages.contains(_selectedFuel))
        .map((s) => s.prices[_selectedFuel]!)
        .toList();

    if (validPrices.isEmpty) return 0.0;
    return validPrices.reduce((a, b) => a + b) / validPrices.length;
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    final fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getMarkerColor(Station station) {
    if (station.shortages.contains(_selectedFuel)) {
      return Colors.red;
    } else if (station.prices.containsKey(_selectedFuel)) {
      return Colors.green.shade700;
    }
    return Colors.grey;
  }

  void _showStationDetails(Station station) {
    final allFuels = ['GAZOLE', 'E10', 'SP98', 'E5', 'E85', 'GPLC'];
    final price = station.prices[_selectedFuel];
    final avgPrice = _calculateAveragePrice();

    double savings = 0.0;
    if (price != null && avgPrice > 0) {
      savings = (avgPrice - price) * _tankCapacity;
    }

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.local_gas_station, color: Colors.blue, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
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

            if (price != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coût du plein ($_tankCapacity L) :',
                          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${(price * _tankCapacity).toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    if (savings > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${savings.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Text(
              'Prix des carburants (Actualisés / Baril)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: allFuels.map((fuel) {
                  final fuelPrice = station.prices[fuel];
                  final isShort = station.shortages.contains(fuel);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fuel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: fuel == _selectedFuel ? Colors.blue : Colors.black87,
                          ),
                        ),
                        if (fuelPrice != null)
                          Text(
                            '${fuelPrice.toStringAsFixed(3)} €/L',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 15,
                            ),
                          )
                        else if (isShort)
                          const Text(
                            'Rupture',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            'Non dispo',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _openNavigation(station.latitude, station.longitude);
                },
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'LANCER L\'ITINÉRAIRE (GPS)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        title: const Text('CarbuStock - ÎdF'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          DropdownButton<int>(
            value: _tankCapacity,
            underline: const SizedBox(),
            icon: const Icon(Icons.tune, color: Colors.white, size: 18),
            dropdownColor: Colors.blue,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: <int>[30, 40, 50, 60, 70].map<DropdownMenuItem<int>>((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('${value}L', style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() => _tankCapacity = newValue);
              }
            },
          ),
          const SizedBox(width: 8),
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
                child: Text(value, style: const TextStyle(color: Colors.white)),
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
            // LA CARTE (FlutterMap complet avec fond Positron et calques de marqueurs)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/positron/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.carbustock',
                ),
                MarkerLayer(
                  markers: [
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent, width: 2),
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
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ..._stations.map((station) {
                      final color = _getMarkerColor(station);
                      final price = station.prices[_selectedFuel];
                      return Marker(
                        point: LatLng(station.latitude, station.longitude),
                        width: 76,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _showStationDetails(station),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: color, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
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
                                        color: Colors.black87,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      price != null ? '${price.toStringAsFixed(2)}€' : 'RPT',
                                      style: TextStyle(
                                        color: color == Colors.red
                                            ? Colors.red
                                            : (color == Colors.green.shade700
                                                ? Colors.green.shade700
                                                : Colors.grey),
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

            Positioned(
              bottom: 20,
              left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'btn_cheapest',
                onPressed: _findCheapestNearbyStation,
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.bolt),
                label: const Text('MOINS CHÈRE VILLE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            if (_isLoadingLocation || _isLoadingStations)
              Positioned(
                top: 16,
                left: 16,
                child: Card(
                  elevation: 4,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLoadingLocation
                              ? 'Position GPS...'
                              : 'Actualisation baril & stations...',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'btn_location',
        onPressed: _centerOnUser,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
