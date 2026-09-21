class Station {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final Map<String, double> fuelPrices;
  final List<String> shortFuels;

  Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.fuelPrices,
    required this.shortFuels,
  });
}
