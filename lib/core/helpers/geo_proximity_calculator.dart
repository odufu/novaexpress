import 'dart:math' as math;

class GeoProximityCalculator {
  static const double earthRadiusKm = 6371.0;

  /// Calculates the great-circle distance between two GPS points using the Haversine formula in Kilometers.
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calculates distance in meters
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return calculateDistanceKm(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2) * 1000.0;
  }

  /// Formats distance nicely for riders and DC managers (e.g. '450 m', '2.8 km')
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
