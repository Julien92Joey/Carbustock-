import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/station.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<Station> _stations = [];
  String? _selectedFuel = 'E10';

  // Centre de la carte par défaut (Paris)
  final LatLng _initialCenter = const LatLng(48.8566, 2.3522);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbuStock - Carte'),
        actions: [
          DropdownButton<String>(
            value: _selectedFuel,
            underline: const SizedBox(),
            icon: const Icon(Icons.local_gas_station, color: Colors.white),
            dropdownColor: Colors.blue,
            style: const TextStyle(color: Colors.black),
            items: <String>['E10', 'E5', 'SP98', 'Gazole', 'GPLc', 'E85']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedFuel = newValue;
              });
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.carbustock.app',
          ),
        ],
      ),
    );
  }
}
