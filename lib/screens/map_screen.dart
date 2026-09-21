import 'package:flutter/material.dart';
import '../models/station.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<Station> _stations = [];
  String? _selectedFuel = 'E10';

  Color _getMarkerColor(Station station) {
    final bool isShort = station.shortFuels.contains(_selectedFuel);
    if (isShort) return Colors.red;
    return Colors.green;
  }

  void _showStationDetails(Station station) {
    final double? prix = _selectedFuel != null
        ? station.fuelPrices[_selectedFuel]
        : null;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Adresse : ${station.address}'),
              if (prix != null) Text('Prix : $prix €/L'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des stations'),
      ),
      body: const Center(
        child: Text('Carte en cours de chargement...'),
      ),
    );
  }
}
