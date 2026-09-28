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
  WidgetsFlutterBinding.ensureInitialized();
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
  final Set<String> _favoriteIds = {};
  
  String _selectedFuel = 'E10';
  String _selectedBrand = 'TOUTES';
  String _searchQuery = '';
  bool _isListView = false;
  bool _showFavoritesOnly = false;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _currentCenter = const LatLng(48.8878, 2.1807); // Position par défaut
  LatLng? _userLocation;

  bool _isLoadingLocation = false;
  bool _isLoadingStations = false;

  final List<String> _availableBrands = [
    'TOUTES',
    'LECLERC',
    'TOTAL',
    'BP',
    'ESSO',
    'INTERMARCHE',
    'CARREFOUR',
    'AUCHAN',
    'AVIA',
  ];

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        _mapController.move(_currentCenter, 14.5);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
    
    _fetchStations();
  }

  Future<void> _centerOnUser() async {
    await _initLocationService();
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    }
  }

  String _extractBrandName(String address, String city, String rawBrandName) {
    final String fullText = '$rawBrandName $address $city'.toUpperCase();
    final brands = [
      'TOTALENERGIES', 'TOTAL', 'LECLERC', 'E.LECLERC', 'INTERMARCHE',
      'CARREFOUR', 'BP', 'ESSO', 'SHELL', 'AUCHAN', 'CASINO', 'CORA',
      'SYSTEME U', 'SUPER U', 'HYPER U', 'AVIA', 'NETTO', 'TOTAL CONTACT'
    ];

    for (final b in brands) {
      if (fullText.contains(b)) {
        if (b == 'TOTALENERGIES' || b == 'TOTAL CONTACT') return 'TOTAL';
        if (b == 'E.LECLERC') return 'LECLERC';
        return b;
      }
    }
    return city.isNotEmpty ? city.toUpperCase() : 'STATION';
  }

  Future<void> _fetchStations() async {
    if (!mounted) return;
    setState(() => _isLoadingStations = true);

    final url = Uri.parse(
      'https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json?limit=10000',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 25));

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
          final String rawBrand = item['brand']?.toString() ?? item['nom']?.toString() ?? '';
          final String brandName = _extractBrandName(address, city, rawBrand);

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
    } catch (_) {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  void _toggleFavorite(String stationId) {
    setState(() {
      if (_favoriteIds.contains(stationId)) {
        _favoriteIds.remove(stationId);
      } else {
        _favoriteIds.add(stationId);
      }
    });
  }

  // Algorithme intelligent : Recherche prioritairement dans la ville de la géo-localisation du téléphone
  void _findCheapestNearbyStation() async {
    if (_userLocation == null) {
      await _initLocationService();
    }

    final center = _userLocation ?? _currentCenter;
    if (_stations.isEmpty) return;

    // 1. Identifier la station la plus proche du téléphone pour extraire la ville de sa géo-localisation
    Station nearestStation = _stations.first;
    double minInitialDist = double.infinity;
    for (var s in _stations) {
      double d = Geolocator.distanceBetween(center.latitude, center.longitude, s.latitude, s.longitude);
      if (d < minInitialDist) {
        minInitialDist = d;
        nearestStation = s;
      }
    }

    // Extraction du nom de la ville de la position actuelle
    String phoneCity = '';
    final parts = nearestStation.address.split(' ');
    if (parts.isNotEmpty) {
      phoneCity = parts.last.toUpperCase();
    }

    // 2. Filtrer les stations situées dans cette même ville
    List<Station> candidates = _stations.where((s) {
      final hasFuel = s.prices.containsKey(_selectedFuel) && !s.shortages.contains(_selectedFuel);
      final matchesBrand = _selectedBrand == 'TOUTES' || s.name == _selectedBrand;
      final isInCity = phoneCity.isNotEmpty && s.address.toUpperCase().contains(phoneCity);
      return hasFuel && matchesBrand && isInCity;
    }).toList();

    // 3. Si aucune station n'est trouvée dans la ville exacte, élargir à un rayon de 30 km autour du téléphone
    if (candidates.isEmpty) {
      candidates = _stations.where((s) {
        final hasFuel = s.prices.containsKey(_selectedFuel) && !s.shortages.contains(_selectedFuel);
        final matchesBrand = _selectedBrand == 'TOUTES' || s.name == _selectedBrand;
        final distance = Geolocator.distanceBetween(center.latitude, center.longitude, s.latitude, s.longitude);
        return hasFuel && matchesBrand && distance <= 30000;
      }).toList();
    }

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune station trouvée pour $_selectedBrand avec $_selectedFuel.')),
      );
      return;
    }

    // 4. Trouver le tarif le plus bas parmi ces candidats
    double minPrice = candidates.map((s) => s.prices[_selectedFuel]!).reduce((a, b) => a < b ? a : b);
    final bestCandidates = candidates.where((s) => s.prices[_selectedFuel]! <= minPrice + 0.02).toList();

    // 5. Trier par proximité par rapport à la position GPS du téléphone
    bestCandidates.sort((a, b) {
      final distA = Geolocator.distanceBetween(center.latitude, center.longitude, a.latitude, a.longitude);
      final distB = Geolocator.distanceBetween(center.latitude, center.longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    final targetStation = bestCandidates.first;

    setState(() => _isListView = false);
    _mapController.move(LatLng(targetStation.latitude, targetStation.longitude), 15.5);
    _showStationDetails(targetStation);
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
    if (station.shortages.contains(_selectedFuel)) return Colors.red.shade600;
    if (station.prices.containsKey(_selectedFuel)) return Colors.green.shade700;
    return Colors.grey;
  }

  List<Station> _getFilteredStations() {
    final center = _userLocation ?? _currentCenter;
    
    final filtered = _stations.where((station) {
      final matchesBrand = _selectedBrand == 'TOUTES' || station.name == _selectedBrand;
      final matchesFav = !_showFavoritesOnly || _favoriteIds.contains(station.id);
      
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        matchesSearch = station.name.toLowerCase().contains(query) || 
                        station.address.toLowerCase().contains(query);
      }
      return matchesBrand && matchesFav && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      final distA = Geolocator.distanceBetween(center.latitude, center.longitude, a.latitude, a.longitude);
      final distB = Geolocator.distanceBetween(center.latitude, center.longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    return filtered;
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
    final isFavorite = _favoriteIds.contains(station.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      station.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      _toggleFavorite(station.id);
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$distanceKm km',
                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                station.address,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tous les carburants disponibles :',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 10),
              if (station.prices.isEmpty && station.shortages.isEmpty)
                const Text('Aucun tarif disponible.', style: TextStyle(color: Colors.grey))
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: ['E10', 'E5', 'SP98', 'GAZOLE', 'GPLC', 'E85'].map((fuelKey) {
                      final hasPrice = station.prices.containsKey(fuelKey);
                      final isRupture = station.shortages.contains(fuelKey);
                      final priceVal = station.prices[fuelKey];
                      final isSelected = fuelKey == _selectedFuel;

                      if (!hasPrice && !isRupture) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade50.withOpacity(0.6) : Colors.transparent,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  fuelKey,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Sélectionné',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              isRupture ? 'Rupture' : (priceVal != null ? '${priceVal.toStringAsFixed(3)} €' : 'N/A'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isRupture ? Colors.red : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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
                  label: const Text('LANCER L\'ITINÉRAIRE', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStations = _getFilteredStations();

    final List<Marker> allMarkers = [];
    for (var station in filteredStations) {
      final color = _getMarkerColor(station);
      final price = station.prices[_selectedFuel];
      allMarkers.add(
        Marker(
          point: LatLng(station.latitude, station.longitude),
          width: 86,
          height: 52,
          child: GestureDetector(
            onTap: () => _showStationDetails(station),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    station.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price != null ? '${price.toStringAsFixed(2)} €' : 'RPT',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_userLocation != null) {
      allMarkers.add(
        Marker(
          point: _userLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbuStock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
            color: _showFavoritesOnly ? Colors.redAccent : Colors.white,
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
            tooltip: 'Favoris',
          ),
          IconButton(
            icon: Icon(_isListView ? Icons.map : Icons.list),
            onPressed: () => setState(() => _isListView = !_isListView),
            tooltip: _isListView ? 'Voir la carte' : 'Voir la liste',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedFuel,
              dropdownColor: Colors.blue.shade700,
              underline: const SizedBox.shrink(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: <String>['E10', 'E5', 'SP98', 'GAZOLE', 'GPLC', 'E85']
                  .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFuel = val);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une ville, une enseigne...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableBrands.length,
                    itemBuilder: (context, index) {
                      final brand = _availableBrands[index];
                      final isSelected = _selectedBrand == brand;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(brand),
                          selected: isSelected,
                          selectedColor: Colors.blue.shade600,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (selected) {
                            setState(() => _selectedBrand = brand);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isListView
                ? ListView.builder(
                    itemCount: filteredStations.length,
                    itemBuilder: (context, index) {
                      final station = filteredStations[index];
                      final center = _userLocation ?? _currentCenter;
                      final distanceKm = (Geolocator.distanceBetween(
                                center.latitude, center.longitude,
                                station.latitude, station.longitude,
                              ) / 1000)
                          .toStringAsFixed(1);
                      final price = station.prices[_selectedFuel];
                      final isRupture = station.shortages.contains(_selectedFuel);
                      final isFav = _favoriteIds.contains(station.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  station.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _toggleFavorite(station.id),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(station.address, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                '$distanceKm km',
                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isRupture ? 'Rupture' : (price != null ? '${price.toStringAsFixed(3)} €' : 'N/A'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isRupture ? Colors.red : Colors.green.shade700,
                                ),
                              ),
                              const Text('Voir détails', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          onTap: () => _showStationDetails(station),
                        ),
                      );
                    },
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentCenter,
                          initialZoom: 14.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.carbustock',
                          ),
                          MarkerLayer(markers: allMarkers),
                        ],
                      ),
                      Positioned(
                        bottom: 24,
                        left: 16,
                        child: FloatingActionButton.extended(
                          onPressed: _findCheapestNearbyStation,
                          backgroundColor: Colors.green.shade600,
                          elevation: 4,
                          icon: const Icon(Icons.bolt, color: Colors.white),
                          label: const Text('MOINS CHÈRE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_isLoadingStations || _isLoadingLocation)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white.withOpacity(0.95),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Mise à jour des stations en cours...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isListView
          ? null
          : FloatingActionButton(
              onPressed: _centerOnUser,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              elevation: 4,
              child: const Icon(Icons.my_location),
            ),
    );
  }
}
