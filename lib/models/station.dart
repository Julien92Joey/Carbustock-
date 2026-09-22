class Station {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final Map<String, double> prices;
  final List<String> shortages;
  double? distance;

  Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.prices,
    required this.shortages,
    this.distance,
  });
}
