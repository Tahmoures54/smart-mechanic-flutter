import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// ── مدل تعمیرگاه ──
// ─────────────────────────────────────────────────────────────────────────────
class Garage {
  final String placeId;
  final String name;
  final String? address;
  final String? phoneNumber;
  final double? rating;
  final int? userRatingsTotal;
  final LatLng location;
  final double? distanceMeters;
  final bool? isOpen;
  final List<String> types;
  final String? photoReference;

  const Garage({
    required this.placeId,
    required this.name,
    this.address,
    this.phoneNumber,
    this.rating,
    this.userRatingsTotal,
    required this.location,
    this.distanceMeters,
    this.isOpen,
    this.types = const [],
    this.photoReference,
  });

  factory Garage.fromPlacesJson(Map<String, dynamic> json, {LatLng? userLocation}) {
    final loc = json['geometry']['location'];
    final garageLatLng = LatLng(
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    );

    final photos = json['photos'] as List<dynamic>?;
    final photoRef = photos?.isNotEmpty == true ? photos!.first['photo_reference'] as String? : null;

    double? distance;
    if (userLocation != null) {
      distance = _calculateDistance(userLocation, garageLatLng);
    }

    return Garage(
      placeId: json['place_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['vicinity']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: (json['user_ratings_total'] as num?)?.toInt(),
      location: garageLatLng,
      distanceMeters: distance,
      isOpen: json['opening_hours']?['open_now'] as bool?,
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      photoReference: photoRef,
    );
  }

  String get distanceLabel {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) return '${distanceMeters!.toStringAsFixed(0)} متر';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} کیلومتر';
  }

  String get ratingLabel => rating == null ? 'بدون امتیاز' : '⭐ ${rating!.toStringAsFixed(1)}';
  String get openStatusLabel => isOpen == null ? '' : (isOpen! ? '✅ باز' : '❌ بسته');
  bool get hasRating => rating != null;
  bool get hasPhone => phoneNumber != null && phoneNumber!.isNotEmpty;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Garage && other.placeId == placeId);

  @override
  int get hashCode => placeId.hashCode;

  @override
  String toString() => 'Garage($name, ${distanceLabel})';
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ جزئیات کامل مکان ──
// ─────────────────────────────────────────────────────────────────────────────
class GarageDetails extends Garage {
  final String? website;
  final List<OpeningHours> weekdayHours;
  final List<String> photoReferences;

  const GarageDetails({
    required super.placeId,
    required super.name,
    super.address,
    super.phoneNumber,
    super.rating,
    super.userRatingsTotal,
    required super.location,
    super.distanceMeters,
    super.isOpen,
    super.types,
    super.photoReference,
    this.website,
    this.weekdayHours = const [],
    this.photoReferences = const [],
  });

  factory GarageDetails.fromDetailsJson(Map<String, dynamic> json, {LatLng? userLocation}) {
    final result = json['result'] as Map<String, dynamic>;
    final loc = result['geometry']['location'];
    final garageLatLng = LatLng(
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    );

    double? distance;
    if (userLocation != null) {
      distance = _calculateDistance(userLocation, garageLatLng);
    }

    final photos = (result['photos'] as List<dynamic>?)?.map((p) => p['photo_reference'].toString()).toList() ?? [];
    final rawHours = (result['opening_hours']?['weekday_text'] as List<dynamic>?)
        ?.map((h) => OpeningHours.fromString(h.toString()))
        .toList() ?? [];

    // ✅ استخراج شماره تماس فرمت شده
    final formattedPhone = result['formatted_phone_number']?.toString();

    return GarageDetails(
      placeId: result['place_id']?.toString() ?? '',
      name: result['name']?.toString() ?? '',
      address: result['formatted_address']?.toString(),
      // ✅ پاس دادن شماره تماس به کلاس پایه برای درست کار کردن متد hasPhone
      phoneNumber: formattedPhone,
      rating: (result['rating'] as num?)?.toDouble(),
      userRatingsTotal: (result['user_ratings_total'] as num?)?.toInt(),
      location: garageLatLng,
      distanceMeters: distance,
      isOpen: result['opening_hours']?['open_now'] as bool?,
      types: (result['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      website: result['website']?.toString(),
      weekdayHours: rawHours,
      photoReferences: photos,
      photoReference: photos.isNotEmpty ? photos.first : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ ساعت کاری ──
// ─────────────────────────────────────────────────────────────────────────────
class OpeningHours {
  final String day;
  final String hours;
  const OpeningHours({required this.day, required this.hours});

  factory OpeningHours.fromString(String text) {
    final parts = text.split(': ');
    return OpeningHours(day: parts.isNotEmpty ? parts[0] : '', hours: parts.length > 1 ? parts[1] : text);
  }

  @override
  String toString() => '$day: $hours';
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ خطای اختصاصی ──
// ─────────────────────────────────────────────────────────────────────────────
class PlacesException implements Exception {
  final String message;
  final PlacesErrorType type;
  final int? statusCode;
  const PlacesException(this.message, {this.type = PlacesErrorType.unknown, this.statusCode});

  @override
  String toString() => 'PlacesException(${type.name}): $message';
}

enum PlacesErrorType {
  missingApiKey, networkError, apiError, noResults, quotaExceeded, invalidRequest, unknown;
  String get label => switch (this) {
        PlacesErrorType.missingApiKey => 'کلید API تنظیم نشده',
        PlacesErrorType.networkError => 'خطای شبکه',
        PlacesErrorType.apiError => 'خطای سرویس Google',
        PlacesErrorType.noResults => 'نتیجه‌ای یافت نشد',
        PlacesErrorType.quotaExceeded => 'سقف استفاده تمام شد',
        PlacesErrorType.invalidRequest => 'درخواست نامعتبر',
        PlacesErrorType.unknown => 'خطای ناشناخته',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── تنظیمات جستجو ──
// ─────────────────────────────────────────────────────────────────────────────
class GarageSearchConfig {
  final int radiusMeters;
  final int maxResults;
  final List<String> types;
  final String? keyword;
  final bool openNow;

  const GarageSearchConfig({
    this.radiusMeters = 2000,
    this.maxResults = 20,
    this.types = const ['car_repair'],
    this.keyword,
    this.openNow = false,
  });

  static const nearby = GarageSearchConfig(radiusMeters: 1000);
  static const wide = GarageSearchConfig(radiusMeters: 5000);
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ سرویس Google Places ──
// ─────────────────────────────────────────────────────────────────────────────
class PlacesService {
  final String apiKey;
  final http.Client _httpClient;

  // ✅ محدودیت حجم کش برای جلوگیری از نشت حافظه
  static const int _maxCacheSize = 50;
  final Map<String, List<Garage>> _searchCache = {};
  final Map<String, GarageDetails> _detailsCache = {};
  
  static const _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const _timeout = Duration(seconds: 15); // ✅ تایم‌اوت شبکه

  PlacesService({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<List<Garage>> findNearbyGarages(LatLng userLocation, {GarageSearchConfig config = const GarageSearchConfig()}) async {
    _validateApiKey();

    final cacheKey = _buildSearchCacheKey(userLocation, config);
    if (_searchCache.containsKey(cacheKey)) {
      debugPrint('[Places] نتایج از cache برگشت داده شد.');
      return _searchCache[cacheKey]!;
    }

    final params = <String, String>{
      'location': '${userLocation.latitude},${userLocation.longitude}',
      'radius': config.radiusMeters.toString(),
      'type': config.types.first,
      'key': apiKey,
      // ✅ افزودن زبان فارسی برای دریافت نام و آدرس فارسی
      'language': 'fa', 
      if (config.keyword != null) 'keyword': config.keyword!,
      if (config.openNow) 'opennow': 'true',
    };

    final uri = Uri.parse('$_baseUrl/nearbysearch/json').replace(queryParameters: params);

    try {
      // ✅ استفاده از تایم‌اوت
      final response = await _httpClient.get(uri, headers: {'Accept-Language': 'fa'}).timeout(_timeout);
      final data = _parseResponse(response);
      _checkApiStatus(data['status'] as String);

      final results = (data['results'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((p) => p['name'] != null && p['geometry']?['location'] != null)
          .take(config.maxResults)
          .map((p) => Garage.fromPlacesJson(p, userLocation: userLocation))
          .toList();

      results.sort((a, b) => (a.distanceMeters ?? double.infinity).compareTo(b.distanceMeters ?? double.infinity));

      _addToSearchCache(cacheKey, results);
      debugPrint('[Places] ${results.length} تعمیرگاه یافت شد.');
      return results;
    } on PlacesException {
      rethrow;
    } on TimeoutException {
      throw const PlacesException('زمان دریافت اطلاعات نقشه به پایان رسید.', type: PlacesErrorType.networkError);
    } catch (e) {
      debugPrint('[Places] خطا: $e');
      throw const PlacesException('خطا در دریافت تعمیرگاه‌های نزدیک.', type: PlacesErrorType.networkError);
    }
  }

  Future<GarageDetails> getGarageDetails(String placeId, {LatLng? userLocation}) async {
    _validateApiKey();

    if (_detailsCache.containsKey(placeId)) return _detailsCache[placeId]!;

    final uri = Uri.parse('$_baseUrl/details/json').replace(queryParameters: {
      'place_id': placeId,
      'fields': 'name,formatted_address,formatted_phone_number,rating,user_ratings_total,opening_hours,geometry,photos,website,types',
      'key': apiKey,
      'language': 'fa',
    });

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      final data = _parseResponse(response);
      _checkApiStatus(data['status'] as String);

      final details = GarageDetails.fromDetailsJson(data, userLocation: userLocation);
      
      _detailsCache[placeId] = details;
      // نگهداری کش جزئیات محدود به 50 آیتم
      if (_detailsCache.length > _maxCacheSize) _detailsCache.remove(_detailsCache.keys.first);
      
      return details;
    } on PlacesException {
      rethrow;
    } catch (e) {
      throw const PlacesException('خطا در دریافت جزئیات تعمیرگاه.', type: PlacesErrorType.networkError);
    }
  }

  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$apiKey';
  }

  void _validateApiKey() {
    if (apiKey.isEmpty) throw const PlacesException('کلید API تنظیم نشده است.', type: PlacesErrorType.missingApiKey);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw PlacesException('خطای سرور: ${response.statusCode}', type: PlacesErrorType.apiError, statusCode: response.statusCode);
    }
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const PlacesException('خطا در پردازش پاسخ سرور.', type: PlacesErrorType.apiError);
    }
  }

  void _checkApiStatus(String status) {
    switch (status) {
      case 'OK':
      case 'ZERO_RESULTS':
        return;
      case 'OVER_QUERY_LIMIT':
        throw const PlacesException('سقف استفاده از API تمام شده.', type: PlacesErrorType.quotaExceeded);
      case 'REQUEST_DENIED':
        throw const PlacesException('درخواست توسط Google رد شد. کلید API را بررسی کنید.', type: PlacesErrorType.missingApiKey);
      case 'INVALID_REQUEST':
        throw const PlacesException('درخواست نامعتبر.', type: PlacesErrorType.invalidRequest);
      default:
        throw PlacesException('خطای Google Places: $status', type: PlacesErrorType.apiError);
    }
  }

  String _buildSearchCacheKey(LatLng loc, GarageSearchConfig config) {
    // گرد کردن مختصات برای کش بهتر
    final lat = (loc.latitude * 100).round();
    final lng = (loc.longitude * 100).round();
    return '${lat}_${lng}_${config.radiusMeters}_${config.openNow}';
  }

  // ✅ متد کمکی برای مدیریت سایز کش
  void _addToSearchCache(String key, List<Garage> value) {
    if (_searchCache.length >= _maxCacheSize) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[key] = value;
  }

  void clearCache() {
    _searchCache.clear();
    _detailsCache.clear();
  }

  void dispose() {
    _httpClient.close();
    clearCache();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── سرویس نقشه ──
// ─────────────────────────────────────────────────────────────────────────────
class MapService {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  LatLng? _currentLocation;

  final void Function(Marker)? onMarkerTap;
  final void Function(LatLng)? onMapTap;

  MapService({this.onMarkerTap, this.onMapTap});

  Set<Marker> get markers => Set.unmodifiable(_markers);
  LatLng? get currentLocation => _currentLocation;
  bool get isReady => _controller != null;

  void attachController(GoogleMapController controller) => _controller = controller;
  void detachController() => _controller = null;

  Future<void> animateToLocation(LatLng location, {double zoom = 15}) async {
    if (_controller == null) return;
    await _controller!.animateCamera(CameraUpdate.newLatLngZoom(location, zoom));
  }

  Future<void> animateToBounds(LatLngBounds bounds) async {
    if (_controller == null) return;
    await _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> zoomIn() async => await _controller?.animateCamera(CameraUpdate.zoomIn());
  Future<void> zoomOut() async => await _controller?.animateCamera(CameraUpdate.zoomOut());

  // ✅ افزودن پارامتر برای پاک کردن مارکرهای قبلی
  void addGarageMarkers(List<Garage> garages, {BitmapDescriptor? icon, void Function(Garage)? onTap, bool clearExisting = true}) {
    if (clearExisting) {
      clearGarageMarkers();
    }

    for (final garage in garages) {
      _markers.add(
        Marker(
          markerId: MarkerId(garage.placeId),
          position: garage.location,
          infoWindow: InfoWindow(
            title: garage.name,
            snippet: [garage.distanceLabel, garage.ratingLabel, garage.openStatusLabel].where((s) => s.isNotEmpty).join('  '),
          ),
          icon: icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: onTap != null ? () => onTap(garage) : null,
        ),
      );
    }
  }

  void addUserMarker(LatLng location) {
    _currentLocation = location;
    _markers.removeWhere((m) => m.markerId == const MarkerId('user_location'));
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'موقعیت شما'),
        zIndex: 2,
      ),
    );
  }

  void removeMarker(String markerId) => _markers.removeWhere((m) => m.markerId.value == markerId);
  
  void clearGarageMarkers() => _markers.removeWhere((m) => m.markerId.value != 'user_location');
  
  void clearAllMarkers() => _markers.clear();

  LatLngBounds? getBoundsForMarkers() {
    if (_markers.isEmpty) return null;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final m in _markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  Future<void> fitAllMarkers() async {
    final bounds = getBoundsForMarkers();
    if (bounds != null) await animateToBounds(bounds);
  }

  void dispose() {
    _controller = null;
    _markers.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ محاسبه فاصله (Haversine) ──
// ─────────────────────────────────────────────────────────────────────────────
double _calculateDistance(LatLng from, LatLng to) {
  const earthRadius = 6371000.0; // متر
  final dLat = _toRad(to.latitude - from.latitude);
  final dLng = _toRad(to.longitude - from.longitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(from.latitude)) * math.cos(_toRad(to.latitude)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRad(double deg) => deg * math.pi / 180;
