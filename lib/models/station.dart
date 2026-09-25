class Station {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final Map<String, double> prices;
  final List<String> shortages;

  Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.prices,
    required this.shortages,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    // Extraction des coordonnées géographiques
    final geom = json['geom'];
    double lat = 0.0;
    double lon = 0.0;
    if (geom != null && geom['lat'] != null && geom['lon'] != null) {
      lat = (geom['lat'] as num).toDouble();
      lon = (geom['lon'] as num).toDouble();
    }

    final String address = json['adresse']?.toString() ?? '';
    final String city = json['ville']?.toString() ?? '';

    // Extraction des prix des carburants
    final Map<String, double> prices = {};
    final fuels = ['gazole', 'e10', 'e5', 'sp98', 'e85', 'gplc'];
    for (final f in fuels) {
      final priceVal = json['${f}_prix'];
      if (priceVal != null) {
        prices[f.toUpperCase()] = (priceVal as num).toDouble();
      }
    }

    // Extraction des ruptures de stock
    final List<String> shortages = [];
    final rupturesVal = json['rupture'];
    if (rupturesVal != null && rupturesVal is String) {
      for (var r in rupturesVal.split(';')) {
        shortages.add(r.trim().toUpperCase());
      }
    }

    return Station(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'STATION',
      address: '$address $city'.trim(),
      latitude: lat,
      longitude: lon,
      prices: prices,
      shortages: shortages,
    );
  }
}
