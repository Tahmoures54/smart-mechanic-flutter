import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

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
  final GooglePlacesFlutter _placesClient;

  PlacesService(this._placesClient);

  Future<List<Garage>> findNearbyGarages(LatLng userLocation) async {
    try {
      final response = await _placesClient.nearbySearch(
        LatLng(userLocation.latitude, userLocation.longitude),
        radius: 500,
        type: 'car_repair',
      );

      return response.results
          .where((place) => place.name != null && place.name!.isNotEmpty)
          .map((place) => Garage(
                name: place.name!,
                address: place.vicinity,
                rating: place.rating,
                location: LatLng(
                  place.geometry.location.lat,
                  place.geometry.location.lng,
                ),
              ))
          .toList();
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
