import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../constants.dart';

class Garage {
  final String id;
  final String name;
  final String? address;
  final String? phoneNumber;
  final double? rating;
  final int? userRatingsTotal;
  final LatLng location;
  final double? distanceMeters;
  final bool? isOpen;
  final List<String> specialties;
  final String? photoUrl;
  final bool isFeatured;
  final bool isVerified;
  final String subscriptionTier;
  final String? subscriptionExpiresAt;
  final String? website;
  final String? description;

  String get placeId => id;

  const Garage({
    required this.id,
    required this.name,
    this.address,
    this.phoneNumber,
    this.rating,
    this.userRatingsTotal,
    required this.location,
    this.distanceMeters,
    this.isOpen,
    this.specialties = const [],
    this.photoUrl,
    this.isFeatured = false,
    this.isVerified = false,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.website,
    this.description,
  });

  factory Garage.fromApiJson(Map<String, dynamic> json, {LatLng? userLocation}) {
    final lat = (json['lat'] as num?)?.toDouble() ??
        (json['latitude'] as num?)?.toDouble() ??
        (json['location'] is Map ? (json['location']['lat'] as num?)?.toDouble() : null) ??
        0.0;
    final lng = (json['lng'] as num?)?.toDouble() ??
        (json['longitude'] as num?)?.toDouble() ??
        (json['location'] is Map ? (json['location']['lng'] as num?)?.toDouble() : null) ??
        0.0;

    final garageLatLng = LatLng(lat, lng);

    double? distance = (json['distanceMeters'] as num?)?.toDouble() ??
        (json['distance'] as num?)?.toDouble();
    if (distance == null && userLocation != null) {
      distance = _calculateDistance(userLocation, garageLatLng);
    }

    final specs = <String>[];
    if (json['specialties'] is List) {
      specs.addAll((json['specialties'] as List).map((e) => e.toString()));
    } else if (json['types'] is List) {
      specs.addAll((json['types'] as List).map((e) => e.toString()));
    }

    final rawTier = json['subscriptionTier']?.toString() ?? json['tier']?.toString() ?? 'free';
    final tier = ['free', 'silver', 'gold'].contains(rawTier) ? rawTier : 'free';

    return Garage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? json['placeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? json['vicinity']?.toString(),
      phoneNumber: json['phone']?.toString() ?? json['phoneNumber']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: (json['userRatingsTotal'] as num?)?.toInt() ??
          (json['reviewsCount'] as num?)?.toInt(),
      location: garageLatLng,
      distanceMeters: distance,
      isOpen: json['isOpen'] as bool? ?? json['openNow'] as bool?,
      specialties: specs,
      photoUrl: json['photoUrl']?.toString() ?? json['image']?.toString(),
      isFeatured: json['isFeatured'] == true || json['featured'] == true,
      isVerified: json['isVerified'] == true || json['verified'] == true,
      subscriptionTier: tier,
      subscriptionExpiresAt: json['subscriptionExpiresAt']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
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
  bool get hasPhone => phoneNumber != null && phoneNumber!.trim().isNotEmpty;

  List<String> get badges {
    final list = <String>[];
    if (subscriptionTier == 'gold') {
      list.add('طلایی');
    } else if (subscriptionTier == 'silver') {
      list.add('نقره‌ای');
    }
    if (isFeatured) list.add('ویژه');
    if (isVerified) list.add('تأییدشده');
    return list;
  }

  bool get isPremium => subscriptionTier == 'gold' || subscriptionTier == 'silver';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Garage && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Garage($name, ${distanceLabel})';
}

class GarageDetails extends Garage {
  final List<OpeningHours> weekdayHours;
  final List<String> photoUrls;

  const GarageDetails({
    required super.id,
    required super.name,
    super.address,
    super.phoneNumber,
    super.rating,
    super.userRatingsTotal,
    required super.location,
    super.distanceMeters,
    super.isOpen,
    super.specialties,
    super.photoUrl,
    super.isFeatured,
    super.isVerified,
    super.subscriptionTier,
    super.subscriptionExpiresAt,
    super.website,
    super.description,
    this.weekdayHours = const [],
    this.photoUrls = const [],
  });

  factory GarageDetails.fromApiJson(Map<String, dynamic> json, {LatLng? userLocation}) {
    final base = Garage.fromApiJson(json, userLocation: userLocation);

    final hours = <OpeningHours>[];
    if (json['openingHours'] is List) {
      for (final h in json['openingHours'] as List) {
        if (h is Map) {
          hours.add(OpeningHours(
            day: h['day']?.toString() ?? '',
            hours: h['hours']?.toString() ?? '',
          ));
        } else if (h is String) {
          hours.add(OpeningHours.fromString(h));
        }
      }
    } else if (json['weekdayText'] is List) {
      for (final h in json['weekdayText'] as List) {
        hours.add(OpeningHours.fromString(h.toString()));
      }
    }

    final photos = <String>[];
    if (json['photos'] is List) {
      photos.addAll((json['photos'] as List).map((e) => e.toString()));
    } else if (json['photoUrls'] is List) {
      photos.addAll((json['photoUrls'] as List).map((e) => e.toString()));
    }
    if (base.photoUrl != null && !photos.contains(base.photoUrl)) {
      photos.insert(0, base.photoUrl!);
    }

    return GarageDetails(
      id: base.id,
      name: base.name,
      address: base.address,
      phoneNumber: base.phoneNumber,
      rating: base.rating,
      userRatingsTotal: base.userRatingsTotal,
      location: base.location,
      distanceMeters: base.distanceMeters,
      isOpen: base.isOpen,
      specialties: base.specialties,
      photoUrl: base.photoUrl,
      isFeatured: base.isFeatured,
      isVerified: base.isVerified,
      subscriptionTier: base.subscriptionTier,
      subscriptionExpiresAt: base.subscriptionExpiresAt,
      website: base.website,
      description: base.description,
      weekdayHours: hours,
      photoUrls: photos,
    );
  }
}

class OpeningHours {
  final String day;
  final String hours;
  const OpeningHours({required this.day, required this.hours});

  factory OpeningHours.fromString(String text) {
    final parts = text.split(': ');
    return OpeningHours(
      day: parts.isNotEmpty ? parts[0] : '',
      hours: parts.length > 1 ? parts.sublist(1).join(': ') : text,
    );
  }

  @override
  String toString() => '$day: $hours';
}

class GarageException implements Exception {
  final String message;
  final GarageErrorType type;
  final int? statusCode;

  const GarageException(
    this.message, {
    this.type = GarageErrorType.unknown,
    this.statusCode,
  });

  @override
  String toString() => 'GarageException(${type.name}): $message';
}

enum GarageErrorType {
  networkError,
  apiError,
  noResults,
  invalidRequest,
  unknown;

  String get label => switch (this) {
        GarageErrorType.networkError => 'خطای شبکه',
        GarageErrorType.apiError => 'خطای سرویس',
        GarageErrorType.noResults => 'نتیجه‌ای یافت نشد',
        GarageErrorType.invalidRequest => 'درخواست نامعتبر',
        GarageErrorType.unknown => 'خطای ناشناخته',
      };
}

typedef PlacesException = GarageException;
typedef PlacesErrorType = GarageErrorType;

class GarageSearchConfig {
  final int radiusMeters;
  final int maxResults;
  final List<String> specialties;
  final String? keyword;
  final bool openNow;
  final bool featuredOnly;

  const GarageSearchConfig({
    this.radiusMeters = 3000,
    this.maxResults = 30,
    this.specialties = const [],
    this.keyword,
    this.openNow = false,
    this.featuredOnly = false,
  });

  static const nearby = GarageSearchConfig(radiusMeters: 1500);
  static const wide = GarageSearchConfig(radiusMeters: 5000);
}

class GarageService {
  final http.Client _httpClient;
  final Map<String, List<Garage>> _searchCache = {};
  final Map<String, GarageDetails> _detailsCache = {};
  static const _maxCacheSize = 20;

  GarageService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Future<List<Garage>> findNearbyGarages(
    LatLng userLocation, {
    GarageSearchConfig config = const GarageSearchConfig(),
  }) async {
    final cacheKey = _buildSearchCacheKey(userLocation, config);
    if (_searchCache.containsKey(cacheKey)) {
      debugPrint('[Garage] نتایج از cache برگشت داده شد.');
      return _searchCache[cacheKey]!;
    }

    try {
      final params = <String, String>{
        'lat': userLocation.latitude.toStringAsFixed(6),
        'lng': userLocation.longitude.toStringAsFixed(6),
        'radius': config.radiusMeters.toString(),
        'limit': config.maxResults.toString(),
        if (config.openNow) 'openNow': 'true',
        if (config.featuredOnly) 'featured': 'true',
        if (config.keyword != null && config.keyword!.isNotEmpty) 'q': config.keyword!,
        if (config.specialties.isNotEmpty) 'specialties': config.specialties.join(','),
      };

      final uri = Uri.parse(Constants.garagesNearby).replace(queryParameters: params);
      debugPrint('[Garage] درخواست: $uri');

      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(Constants.defaultTimeout);

      if (response.statusCode >= 400) {
        if (response.statusCode == 404 || response.statusCode == 501) {
          debugPrint('[Garage] اندپوینت هنوز آماده نیست — استفاده از داده نمونه.');
          final mock = _mockGarages(userLocation);
          _addToSearchCache(cacheKey, mock);
          return mock;
        }
        throw GarageException(
          'خطای سرور: ${response.statusCode}',
          type: GarageErrorType.apiError,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final List<dynamic> rawList;
      if (body is Map) {
        rawList = (body['data'] as List?) ??
            (body['garages'] as List?) ??
            (body['items'] as List?) ??
            [];
      } else if (body is List) {
        rawList = body;
      } else {
        rawList = [];
      }

      final results = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => Garage.fromApiJson(j, userLocation: userLocation))
          .toList();

      int tierRank(String t) => t == 'gold' ? 3 : t == 'silver' ? 2 : 1;
      results.sort((a, b) {
        final tr = tierRank(b.subscriptionTier).compareTo(tierRank(a.subscriptionTier));
        if (tr != 0) return tr;
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        final da = a.distanceMeters ?? double.infinity;
        final db = b.distanceMeters ?? double.infinity;
        return da.compareTo(db);
      });

      _addToSearchCache(cacheKey, results);
      debugPrint('[Garage] ${results.length} تعمیرگاه از دیتابیس خودمان یافت شد.');
      return results;
    } on TimeoutException {
      throw const GarageException(
        'زمان دریافت اطلاعات تعمیرگاه‌ها به پایان رسید.',
        type: GarageErrorType.networkError,
      );
    } on GarageException {
      rethrow;
    } catch (e) {
      debugPrint('[Garage] خطا: $e');
      if (kDebugMode) {
        debugPrint('[Garage] fallback به داده نمونه (debug).');
        final mock = _mockGarages(userLocation);
        _addToSearchCache(cacheKey, mock);
        return mock;
      }
      throw const GarageException(
        'خطا در دریافت تعمیرگاه‌های نزدیک.',
        type: GarageErrorType.networkError,
      );
    }
  }

  Future<GarageDetails> getGarageDetails(String id, {LatLng? userLocation}) async {
    if (id.isEmpty) {
      throw const GarageException('شناسه تعمیرگاه نامعتبر است.', type: GarageErrorType.invalidRequest);
    }
    if (_detailsCache.containsKey(id)) {
      return _detailsCache[id]!;
    }
    try {
      final uri = Uri.parse(Constants.garageDetails(id));
      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(Constants.defaultTimeout);

      if (response.statusCode >= 400) {
        if (response.statusCode == 404) {
          throw const GarageException('تعمیرگاه یافت نشد.', type: GarageErrorType.noResults);
        }
        throw GarageException(
          'خطای سرور: ${response.statusCode}',
          type: GarageErrorType.apiError,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> data;
      if (body is Map && body['data'] is Map) {
        data = Map<String, dynamic>.from(body['data'] as Map);
      } else if (body is Map) {
        data = Map<String, dynamic>.from(body);
      } else {
        throw const GarageException('پاسخ نامعتبر از سرور.', type: GarageErrorType.apiError);
      }

      final details = GarageDetails.fromApiJson(data, userLocation: userLocation);
      if (_detailsCache.length >= _maxCacheSize) {
        _detailsCache.remove(_detailsCache.keys.first);
      }
      _detailsCache[id] = details;
      return details;
    } on GarageException {
      rethrow;
    } catch (e) {
      debugPrint('[Garage] جزئیات: $e');
      throw const GarageException(
        'خطا در دریافت جزئیات تعمیرگاه.',
        type: GarageErrorType.networkError,
      );
    }
  }

  List<Garage> _mockGarages(LatLng user) {
    const offsets = [
      (0.004, 0.003),
      (-0.003, 0.005),
      (0.006, -0.002),
      (-0.005, -0.004),
      (0.002, 0.007),
    ];
    final names = [
      'تعمیرگاه تخصصی موتور پارس',
      'خدمات خودرو آریا',
      'گیربکس و دیفرانسیل تهران',
      'برق خودرو مدرن',
      'تعمیرگاه جلوبندی و فرمان',
    ];
    final specs = [
      ['موتور', 'تنظیم موتور'],
      ['عمومی', 'سرویس دوره‌ای'],
      ['گیربکس', 'دیفرانسیل'],
      ['برق', 'ایسیو'],
      ['جلوبندی', 'فرمان'],
    ];

    return List.generate(offsets.length, (i) {
      final lat = user.latitude + offsets[i].$1;
      final lng = user.longitude + offsets[i].$2;
      final loc = LatLng(lat, lng);
      return Garage(
        id: 'mock_${i + 1}',
        name: names[i],
        address: 'نزدیک موقعیت شما (نمونه)',
        phoneNumber: '021${80000000 + i}',
        rating: 4.0 + (i % 10) * 0.1,
        userRatingsTotal: 20 + i * 15,
        location: loc,
        distanceMeters: _calculateDistance(user, loc),
        isOpen: i % 3 != 2,
        specialties: specs[i],
        isFeatured: i == 0 || i == 2,
        isVerified: i < 3,
        subscriptionTier: i == 0 ? 'gold' : (i == 2 ? 'silver' : 'free'),
        description: 'تعمیرگاه نمونه برای تست تا آماده‌سازی دیتابیس',
      );
    });
  }

  String _buildSearchCacheKey(LatLng loc, GarageSearchConfig config) {
    final lat = (loc.latitude * 100).round() / 100;
    final lng = (loc.longitude * 100).round() / 100;
    return '$lat,$lng,${config.radiusMeters},${config.maxResults},${config.featuredOnly}';
  }

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

typedef PlacesService = GarageService;

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

  void addGarageMarkers(
    List<Garage> garages, {
    BitmapDescriptor? icon,
    BitmapDescriptor? featuredIcon,
    void Function(Garage)? onTap,
    bool clearExisting = true,
  }) {
    if (clearExisting) clearGarageMarkers();

    for (final garage in garages) {
      final isGold = garage.subscriptionTier == 'gold' || garage.isFeatured;
      final hue = isGold
          ? BitmapDescriptor.hueOrange
          : (garage.subscriptionTier == 'silver'
              ? BitmapDescriptor.hueYellow
              : (garage.isVerified ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed));

      _markers.add(
        Marker(
          markerId: MarkerId(garage.id),
          position: garage.location,
          infoWindow: InfoWindow(
            title: isGold ? '⭐ ${garage.name}' : garage.name,
            snippet: [
              ...garage.badges,
              garage.distanceLabel,
              garage.ratingLabel,
              garage.openStatusLabel,
            ].where((s) => s.isNotEmpty).join('  '),
          ),
          icon: isGold
              ? (featuredIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange))
              : (icon ?? BitmapDescriptor.defaultMarkerWithHue(hue)),
          onTap: onTap != null ? () => onTap(garage) : null,
          zIndex: isGold ? 4 : (garage.subscriptionTier == 'silver' ? 3 : (garage.isVerified ? 2 : 1)),
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
        zIndex: 5,
      ),
    );
  }

  void removeMarker(String markerId) =>
      _markers.removeWhere((m) => m.markerId.value == markerId);

  void clearGarageMarkers() =>
      _markers.removeWhere((m) => m.markerId.value != 'user_location');

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
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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

double _calculateDistance(LatLng from, LatLng to) {
  const earthRadius = 6371000.0;
  final dLat = _toRad(to.latitude - from.latitude);
  final dLng = _toRad(to.longitude - from.longitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(from.latitude)) *
          math.cos(_toRad(to.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRad(double deg) => deg * math.pi / 180;
