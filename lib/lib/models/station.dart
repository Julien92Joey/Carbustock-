class Station {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final Map<String, double> fuelPrices;
  final List<String> shortfuels;

  Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.fuelPrices,
    required this.shortfuels,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] ?? {};
    
    final List<dynamic>? geom = fields['geom'];
    final double lat = geom != null ? (geom[0] as num).toDouble() : 0.0;
    final double lon = geom != null ? (geom[1] as num).toDouble() : 0.0;

    Map<String, double> prices = {};
    if (fields['gazole_prix'] != null) prices['Gazole'] = (fields['gazole_prix'] as num).toDouble();
    if (fields['e10_prix'] != null) prices['E10'] = (fields['e10_prix'] as num).toDouble();
    if (fields['sp98_prix'] != null) prices['SP98'] = (fields['sp98_prix'] as num).toDouble();
    if (fields['sp95_prix'] != null) prices['SP95'] = (fields['sp95_prix'] as num).toDouble();
    if (fields['e85_prix'] != null) prices['E85'] = (fields['e85_prix'] as num).toDouble();
    if (fields['gplc_prix'] != null) prices['GPLc'] = (fields['gplc_prix'] as num).toDouble();

    List<String> ruptures = [];
    if (fields['rupture_gazole'] != null) ruptures.add('Gazole');
    if (fields['rupture_e10'] != null) ruptures.add('E10');
    if (fields['rupture_sp98'] != null) ruptures.add('SP98');
    if (fields['rupture_sp95'] != null) ruptures.add('SP95');
    if (fields['rupture_e85'] != null) ruptures.add('E85');
    if (fields['rupture_gplc'] != null) ruptures.add('GPLc');

    return Station(
      id: fields['id']?.toString() ?? '',
      name: fields['pop'] ?? 'Station Carburant',
      address: fields['adresse'] ?? 'Adresse non renseignée',
      latitude: lat,
      longitude: lon,
      fuelPrices: prices,
      shortfuels: ruptures,
    );
  }
}
