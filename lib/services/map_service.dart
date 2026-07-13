import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

class MapService {
  final GoogleMapController _controller;

  MapService(this._controller);

  Future<List<Garage>> findNearbyGarages(LatLng userLocation) async {
    final places = GooglePlacesFlutter(
      apiKey: 'YOUR_GOOGLE_MAPS_API_KEY',
      enableSearchAutoComplete: true,
    );

    final response = await places.nearbySearch(
      LatLng(userLocation.latitude, userLocation.longitude),
      radius: 500, // متر
      type: 'auto_repair', // نوع کسب‌وکار
    );

    return response.results.map((place) => Garage(
      name: place.name,
      address: place.vicinity,
      rating: place.rating,
      location: LatLng(place.geometry.location.lat, place.geometry.location.lng),
    ).toList();
  }
}

class Garage {
  final String name;
  final String address;
  final double rating;
  final LatLng location;

  Garage({
    required this.name,
    required this.address,
    required this.rating,
    required this.location,
  });
}
