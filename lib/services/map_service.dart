import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class Garage {
  final String name;
  final String? address;
  final double? rating;
  final LatLng location;

  const Garage({
    required this.name,
    this.address,
    this.rating,
    required this.location,
  });
}

class PlacesService {
  final String apiKey;
  final http.Client _httpClient;

  // دریافت کلید API گوگل و کلاینت HTTP
  PlacesService({required this.apiKey, http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  Future<List<Garage>> findNearbyGarages(LatLng userLocation) async {
    if (apiKey.isEmpty) {
      debugPrint('Error: Google Maps API Key is missing.');
      return [];
    }

    // آدرس مستقیم API گوگل برای پیدا کردن مکان‌های اطراف (تعمیرگاه‌ها)
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${userLocation.latitude},${userLocation.longitude}'
      '&radius=500'
      '&type=car_repair'
      '&key=$apiKey'
    );

    try {
      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        return results.where((place) {
          return place['name'] != null && place['geometry']?['location'] != null;
        }).map((place) {
          final location = place['geometry']['location'];
          return Garage(
            name: place['name'],
            address: place['vicinity'],
            rating: (place['rating'] as num?)?.toDouble(),
            location: LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
          );
        }).toList();
      } else {
        debugPrint('Google Places API Error: Status Code ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching nearby garages: $e');
      rethrow;
    }
  }
}

class MapService {
  final GoogleMapController? _mapController;  // nullable

  MapService(this._mapController);

  Future<void> animateToLocation(LatLng location, {double zoom = 14}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(location, zoom),
    );
  }
}
