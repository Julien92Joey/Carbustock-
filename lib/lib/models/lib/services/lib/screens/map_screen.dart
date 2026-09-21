import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/station.dart';
import '../services/fuel_api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FuelApiService _apiService = FuelApiService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Station> _allStations = [];
  List<Station> _filteredStations = [];
  bool _isLoading = true;
  bool _isSearching = false;

  String? _selectedFuel = 'Gazole';
  bool _onlyAvailable = true;

  LatLng _currentCenter = const LatLng(48.8566, 2.3522);
  final List<String> _fuelTypes = ['Gazole', 'E10', 'SP98', 'SP95', 'E85', 'GPLc'];

  @override
  void initState() {
    super.initState();
    _determinePositionAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePositionAndLoad() async {
    setState(() => _isLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Le service GPS est désactivé.');
      _loadData();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permission GPS refusée.');
        _loadData();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permissions refusées de manière permanente.');
      _loadData();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentCenter, 13.0);
    } catch (e) {
      print('Erreur GPS : $e');
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stations = await _apiService.fetchNearbyStations(
      _currentCenter.latitude,
      _currentCenter.longitude,
    );
    setState(() {
      _allStations = stations;
      _applyFuelFilter();
      _isLoading = false;
    });
  }

  void _applyFuelFilter() {
    if (_selectedFuel == null) {
      _filteredStations = List.from(_allStations);
    } else {
      _filteredStations = _allStations.where((station) {
        final bool hasPrice = station.fuelPrices.containsKey(_selectedFuel);
        final bool isShort = station.shortfuels.contains(_selectedFuel);

        if (_onlyAvailable) {
          return hasPrice && !isShort;
        }
        return hasPrice || isShort;
      }).toList();
    }
  }

  void _toggleFuelFilter(String fuel) {
    setState(() {
      if (_selectedFuel == fuel) {
        _selectedFuel = null;
      } else {
        _selectedFuel = fuel;
      }
      _applyFuelFilter();
    });
  }

  Future<void> _searchCity(String query) async {
    if (query.trim().isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    final coords = await _apiService.searchCityCoordinates(query);

    setState(() => _isSearching = false);

    if (coords != null) {
      final newCenter = LatLng(coords['lat']!, coords['lon']!);
      setState(() {
        _currentCenter = newCenter;
      });
      _mapController.move(newCenter, 13.0);
      await _loadData();
    } else {
      _showSnackBar('Ville "$query" introuvable.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _getMarkerColor(Station station) {
    if (_selectedFuel != null) {
      if (station.shortfuels.contains(_selectedFuel)) {
        return Colors.red;
      }
      return Colors.green;
    }

    if (station.shortfuels.length > 2) return Colors.red;
    if (station.shortfuels.isNotEmpty) return Colors.orange;
    return Colors.green;
  }

  void _showStationDetails(Station station) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(station.address, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 15),
              const Text('Prix des carburants :', style: TextStyle(fontWeight: FontWeight.w600)),
              ...station.fuelPrices.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text(
                        '${e.value.toStringAsFixed(3)} €/L',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              if (station.shortfuels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Ruptures : ${station.shortfuels.join(", ")}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.carbustock',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentCenter,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.person_pin_circle, color: Colors.blue, size: 20),
                        ),
                      ),
                    ),
                    ..._filteredStations.map((station) {
                      final double? price = _selectedFuel != null ? station.fuelPrices[_selectedFuel] : null;

                      return Marker(
                        point: LatLng(station.latitude, station.longitude),
                        width: 70,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showStationDetails(station),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (price != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
                                  ),
                                  child: Text(
                                    '${price.toStringAsFixed(2)}€',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Icon(
                                Icons.location_on,
                                color: _getMarkerColor(station),
                                size: 30,
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
              top: 10,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _searchCity,
                              decoration: const InputDecoration(
                                hintText: 'Rechercher une ville...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_isSearching)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.my_location, color: Colors.blue),
                            onPressed: _determinePositionAndLoad,
                            tooltip: 'Ma position GPS',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            avatar: Icon(
                              _onlyAvailable ? Icons.check_circle : Icons.inventory_2_outlined,
                              size: 18,
                              color: _onlyAvailable ? Colors.white : Colors.green,
                            ),
                            label: const Text('En stock uniquement'),
                            selected: _onlyAvailable,
                            selectedColor: Colors.green[700],
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _onlyAvailable ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            elevation: 3,
                            onSelected: (val) {
                              setState(() {
                                _onlyAvailable = val;
                                _applyFuelFilter();
                              });
                            },
                          ),
                        ),
                        ..._fuelTypes.map((fuel) {
                          final isSelected = _selectedFuel == fuel;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(fuel),
                              selected: isSelected,
                              selectedColor: Colors.blue,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              elevation: 3,
                              onSelected: (_) => _toggleFuelFilter(fuel),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Recherche des carburants...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
