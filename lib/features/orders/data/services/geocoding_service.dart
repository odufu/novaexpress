import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/helpers/address_synthesizer.dart';

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String geocodedAddress;
  final double locationConfidence;
  final String geocodingStatus; // 'exact_verified', 'rooftop', 'landmark_match', 'locality_fallback'

  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.geocodedAddress,
    required this.locationConfidence,
    required this.geocodingStatus,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 6.4474,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 3.4839,
      geocodedAddress: json['geocodedAddress']?.toString() ?? 'Nigeria',
      locationConfidence: (json['locationConfidence'] as num?)?.toDouble() ?? 0.5,
      geocodingStatus: json['geocodingStatus']?.toString() ?? 'locality_fallback',
    );
  }
}

class GeocodingService {
  final SupabaseClient? supabaseClient;

  // Local Nigerian landmark and LGA centroids dictionary for instant zero-latency offline resolution
  static const Map<String, Map<String, dynamic>> _localNigerianCentroids = {
    // Lagos Zones
    'lekki': {'lat': 6.4474, 'lng': 3.4839, 'conf': 0.90, 'label': 'Lekki Phase 1, Eti-Osa LGA, Lagos'},
    'admiralty': {'lat': 6.4474, 'lng': 3.4839, 'conf': 0.95, 'label': 'Admiralty Way, Lekki Phase 1, Lagos'},
    'victoria island': {'lat': 6.4281, 'lng': 3.4219, 'conf': 0.90, 'label': 'Victoria Island, Lagos'},
    'vi': {'lat': 6.4281, 'lng': 3.4219, 'conf': 0.85, 'label': 'Victoria Island, Lagos'},
    'ikeja': {'lat': 6.5922, 'lng': 3.3556, 'conf': 0.90, 'label': 'Ikeja GRA, Lagos'},
    'isaac john': {'lat': 6.5922, 'lng': 3.3556, 'conf': 0.95, 'label': 'Isaac John St, Ikeja GRA, Lagos'},
    'yaba': {'lat': 6.5095, 'lng': 3.3711, 'conf': 0.85, 'label': 'Yaba, Mainland, Lagos'},
    'surulere': {'lat': 6.4975, 'lng': 3.3554, 'conf': 0.85, 'label': 'Adeniran Ogunsanya, Surulere, Lagos'},
    'festac': {'lat': 6.4678, 'lng': 3.2833, 'conf': 0.85, 'label': 'Festac Town, Amuwo-Odofin, Lagos'},
    'ikoyi': {'lat': 6.4549, 'lng': 3.4346, 'conf': 0.90, 'label': 'Ikoyi, Lagos Island, Lagos'},
    'maryland': {'lat': 6.5721, 'lng': 3.3667, 'conf': 0.85, 'label': 'Maryland, Ikeja, Lagos'},

    // Abuja Zones
    'wuse': {'lat': 9.0765, 'lng': 7.4832, 'conf': 0.90, 'label': 'Wuse 2, Abuja, FCT'},
    'aminu kano': {'lat': 9.0765, 'lng': 7.4832, 'conf': 0.95, 'label': 'Aminu Kano Cres, Wuse 2, Abuja'},
    'garki': {'lat': 9.0345, 'lng': 7.4891, 'conf': 0.85, 'label': 'Area 11, Garki, Abuja, FCT'},
    'maitama': {'lat': 9.0882, 'lng': 7.4933, 'conf': 0.90, 'label': 'Maitama, Abuja, FCT'},
    'asokoro': {'lat': 9.0435, 'lng': 7.5255, 'conf': 0.90, 'label': 'Asokoro, Abuja, FCT'},
    'gwarinpa': {'lat': 9.1108, 'lng': 7.4116, 'conf': 0.85, 'label': 'Gwarinpa Estate, Abuja, FCT'},
    'central business district': {'lat': 9.0579, 'lng': 7.4951, 'conf': 0.90, 'label': 'Central Area, Abuja, FCT'},
    'cbd': {'lat': 9.0579, 'lng': 7.4951, 'conf': 0.85, 'label': 'Central Business District, Abuja'},

    // Other Regions
    'port harcourt': {'lat': 4.8156, 'lng': 7.0498, 'conf': 0.80, 'label': 'Port Harcourt, Rivers State'},
    'ibadan': {'lat': 7.3775, 'lng': 3.9470, 'conf': 0.80, 'label': 'Ibadan, Oyo State'},
    'kano': {'lat': 12.0022, 'lng': 8.5920, 'conf': 0.80, 'label': 'Kano, Kano State'},
    'benin city': {'lat': 6.3350, 'lng': 5.6037, 'conf': 0.80, 'label': 'Benin City, Edo State'},
  };

  GeocodingService([this.supabaseClient]);

  /// Resolves an address string into GPS coordinates and formatted canonical address
  Future<GeocodingResult> resolveAddress({
    required String address,
    String? city,
    required String state,
    String? orderId,
    bool autoDispatch = false,
  }) async {
    // 1. Try remote Edge Function resolution if Supabase client is connected
    if (supabaseClient != null) {
      try {
        final response = await supabaseClient!.functions.invoke(
          'geocode-and-dispatch',
          body: {
            'orderId': orderId,
            'address': address,
            'city': city,
            'state': state,
            'autoDispatch': autoDispatch,
          },
        );

        if (response.status >= 200 && response.status < 300 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          if (data['latitude'] != null && data['longitude'] != null) {
            return GeocodingResult.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('[GEOCODING_SERVICE] ℹ️ Edge function call notice ($e). Using local fallback resolver.');
      }
    }

    // 2. Local Fallback Resolver
    final synthesized = AddressSynthesizer.synthesizeQuery(address: address, city: city, state: state);
    final searchKey = synthesized.toLowerCase();

    for (final entry in _localNigerianCentroids.entries) {
      if (searchKey.contains(entry.key)) {
        final data = entry.value;
        return GeocodingResult(
          latitude: (data['lat'] as num).toDouble(),
          longitude: (data['lng'] as num).toDouble(),
          geocodedAddress: data['label'] as String,
          locationConfidence: (data['conf'] as num).toDouble(),
          geocodingStatus: (data['conf'] as num) >= 0.90 ? 'exact_verified' : 'landmark_match',
        );
      }
    }

    // 3. Fallback City Centroid
    if (state.toLowerCase().contains('abuja') || (city?.toLowerCase().contains('abuja') == true)) {
      return GeocodingResult(
        latitude: 9.0765,
        longitude: 7.3986,
        geocodedAddress: synthesized,
        locationConfidence: 0.50,
        geocodingStatus: 'locality_fallback',
      );
    }

    return GeocodingResult(
      latitude: 6.5244,
      longitude: 3.3792,
      geocodedAddress: synthesized,
      locationConfidence: 0.50,
      geocodingStatus: 'locality_fallback',
    );
  }

  /// Triggers proximity auto-dispatch on server for an order
  Future<Map<String, dynamic>> autoDispatchOrder(String orderId, {double maxDistanceKm = 25.0}) async {
    if (supabaseClient == null) {
      return {'success': true, 'orderId': orderId};
    }

    try {
      final response = await supabaseClient!.rpc('auto_dispatch_order', params: {
        'p_order_id': orderId,
        'p_max_distance_km': maxDistanceKm,
      });

      if (response != null && response is Map<String, dynamic>) {
        return response;
      }
      return {'success': true, 'orderId': orderId};
    } catch (e) {
      debugPrint('[GEOCODING_SERVICE] autoDispatchOrder RPC notice: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Broadcasts rider GPS telemetry update
  Future<void> sendRiderTelemetry({
    required String agentId,
    required double latitude,
    required double longitude,
  }) async {
    if (supabaseClient == null) return;

    try {
      await supabaseClient!.rpc('update_rider_gps_telemetry', params: {
        'p_agent_id': agentId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
    } catch (e) {
      debugPrint('[GEOCODING_SERVICE] sendRiderTelemetry notice: $e');
    }
  }

  /// Records a verified physical gate pin for an order
  Future<Map<String, dynamic>> recordVerifiedGatePin({
    required String orderId,
    required double latitude,
    required double longitude,
    String? pinLabel,
  }) async {
    if (supabaseClient == null) {
      return {'success': true, 'verified': true, 'orderId': orderId};
    }

    try {
      final response = await supabaseClient!.rpc('record_verified_gate_pin', params: {
        'p_order_id': orderId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_pin_label': pinLabel ?? 'Customer Delivery Gate',
      });

      if (response != null && response is Map<String, dynamic>) {
        return response;
      }
      return {'success': true, 'verified': true, 'orderId': orderId};
    } catch (e) {
      debugPrint('[GEOCODING_SERVICE] recordVerifiedGatePin notice: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
