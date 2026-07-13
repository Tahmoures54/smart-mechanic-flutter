import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

/// مدل داده‌ای تعمیرگاه
class Garage {
  final String name;
  final String? address; // ممکن است از سمت گوگل null باشد
  final double? rating;   // ممکن است تعمیرگاه امتیازی نداشته باشد
  final LatLng location;

  const Garage({
    required this.name,
    this.address,
    this.rating,
    required this.location,
  });
}

/// سرویس ارتباط با Google Places API
class PlacesService {
  final GooglePlacesFlutter _placesClient;

  /// تزریق وابستگی کلاینت Places
  PlacesService(this._placesClient);

  /// یافتن تعمیرگاه‌های اطراف موقعیت کاربر
  Future<List<Garage>> findNearbyGarages(LatLng userLocation) async {
    try {
      final response = await _placesClient.nearbySearch(
        LatLng(userLocation.latitude, userLocation.longitude),
        radius: 500, // متر
        type: 'car_repair', // در API گوگل معمولا car_repair است (توصیه میشه داکیومنت گوگل چک شود)
      );

      // فیلتر کردن مکان‌های بدون نام و تبدیل به مدل Garage
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
      // در پروژه واقعی، اینجا لاگ بگیرید و خطای اختصاصی اپلیکیشن پرتاب کنید
      print('Error fetching nearby garages: $e');
      rethrow;
    }
  }
}

/// سرویس مدیریت خود نقشه (حرکت دوربین، مارکرها و...)
class MapService {
  final GoogleMapController _mapController;

  MapService(this._mapController);

  /// حرکت دادن دوربین نقشه به یک موقعیت خاص
  Future<void> animateToLocation(LatLng location, {double zoom = 14}) async {
    await _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(location, zoom),
    );
  }

  // سایر متدهای مربوط به نقشه مثل اضافه کردن مارکرها اینجا قرار می‌گیرند
}
