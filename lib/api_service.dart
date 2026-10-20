import 'dart:convert';
import 'package:http/http.dart' as http;

/// Where the FastAPI backend lives.
///
/// Chrome on the same laptop   -> http://127.0.0.1:8000
/// Real Android phone on Wi-Fi -> `http://<your-laptop-IP>:8000`
///   (find it with `ipconfig`, look for IPv4 Address, e.g. 192.168.0.12)
/// Android emulator            -> http://10.0.2.2:8000
const String kBaseUrl = 'http://127.0.0.1:8000';

String? _dateOnlyIso(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _pluralUnit(String unit) => switch (unit) {
      'kg' => 'kg',
      'bunch' => 'bunches',
      'pack' => 'packs',
      'piece' => 'pieces',
      'bag' => 'bags',
      _ => unit,
    };

String formatUnitQuantity(int quantity, String unit) =>
    '$quantity ${quantity == 1 ? unit : _pluralUnit(unit)}';

// ---------------------------------------------------------------- models

class AppUser {
  final int id;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final String? farmName;
  final String? address;
  final double? latitude;
  final double? longitude;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.farmName,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String?,
        farmName: json['farm_name'] as String?,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  bool get hasLocation => latitude != null && longitude != null;

  bool get isFarmer => role == 'farmer';
  bool get isBuyer => role == 'buyer';
}

class UserStats {
  final int listings;
  final int ordersPlaced;
  final int ordersReceived;
  final int completedOrders;
  final DateTime memberSince;

  UserStats({
    required this.listings,
    required this.ordersPlaced,
    required this.ordersReceived,
    required this.completedOrders,
    required this.memberSince,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        listings: json['listings'] as int,
        ordersPlaced: json['orders_placed'] as int,
        ordersReceived: json['orders_received'] as int,
        completedOrders: json['completed_orders'] as int,
        memberSince: DateTime.parse(json['member_since'] as String),
      );
}

class Product {
  final int id;
  final String name;
  final String farmerName;
  final double pricePerUnit;
  final int stockQuantity;
  final String unit;
  final String category;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final int ownerId;
  final String? farmName;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? modelKey;     // FR4 catalogue model
  final String? modelUrl;     // FR4 resolved URL
  final String? modelFile;    // FR4 uploaded scan filename
  final String? modelSource;  // "catalogue" | "upload" | null

  Product({
    required this.id,
    required this.name,
    required this.farmerName,
    required this.pricePerUnit,
    required this.stockQuantity,
    this.unit = 'kg',
    required this.category,
    this.availableFrom,
    this.availableUntil,
    required this.ownerId,
    this.farmName,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.modelKey,
    this.modelUrl,
    this.modelFile,
    this.modelSource,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        farmerName: json['farmer_name'] as String,
        pricePerUnit:
            ((json['price_per_unit'] ?? json['price_per_kg']) as num).toDouble(),
        stockQuantity:
            (json['stock_quantity'] ?? json['stock_kg']) as int,
        unit: json['unit'] as String? ?? 'kg',
        category: json['category'] as String,
        availableFrom: json['available_from'] == null
            ? null
            : DateTime.parse(json['available_from'] as String),
        availableUntil: json['available_until'] == null
            ? null
            : DateTime.parse(json['available_until'] as String),
        ownerId: json['owner_id'] as int,
        farmName: json['farm_name'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        modelKey: json['model_key'] as String?,
        modelUrl: json['model_url'] as String?,
        modelFile: json['model_file'] as String?,
        modelSource: json['model_source'] as String?,
      );

  /// True when this listing has a 3D model that can be viewed in AR.
  bool get hasArModel => modelUrl != null && modelUrl!.isNotEmpty;

  /// True when the model is the farmer's own photogrammetry scan.
  bool get hasOwnScan => modelSource == 'upload';

  bool get isLowStock => stockQuantity > 0 && stockQuantity < 15;
  bool get isOutOfStock => stockQuantity <= 0;
}

class Order {
  final int id;
  final int productId;
  final int buyerId;
  final String buyerName;
  final int quantity;
  final String unit;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final String? productName;
  final String? farmerName;

  Order({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.buyerName,
    required this.quantity,
    this.unit = 'kg',
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.productName,
    this.farmerName,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        productId: json['product_id'] as int,
        buyerId: json['buyer_id'] as int,
        buyerName: json['buyer_name'] as String,
        quantity: (json['quantity'] ?? json['quantity_kg']) as int,
        unit: json['unit'] as String? ?? 'kg',
        totalPrice: (json['total_price'] as num).toDouble(),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        productName: json['product_name'] as String?,
        farmerName: json['farmer_name'] as String?,
      );
}

class MonthlySales {
  final String label;
  final double revenue;
  final int orders;

  MonthlySales({
    required this.label,
    required this.revenue,
    required this.orders,
  });

  factory MonthlySales.fromJson(Map<String, dynamic> json) => MonthlySales(
        label: json['label'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        orders: json['orders'] as int,
      );
}

class TopCrop {
  final String productName;
  final int quantity;
  final String unit;
  final double revenue;
  final int orders;

  TopCrop({
    required this.productName,
    required this.quantity,
    this.unit = 'kg',
    required this.revenue,
    required this.orders,
  });

  factory TopCrop.fromJson(Map<String, dynamic> json) => TopCrop(
        productName: json['product_name'] as String,
        quantity: (json['quantity'] ?? json['quantity_kg']) as int,
        unit: json['unit'] as String? ?? 'kg',
        revenue: (json['revenue'] as num).toDouble(),
        orders: json['orders'] as int,
      );
}

class SalesReport {
  final String farmerName;
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final int totalKgSold;
  final double pendingRevenue;
  final int pendingOrders;
  final double thisMonthRevenue;
  final int thisMonthOrders;
  final List<MonthlySales> monthly;
  final List<TopCrop> topCrops;

  SalesReport({
    required this.farmerName,
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalKgSold,
    required this.pendingRevenue,
    required this.pendingOrders,
    required this.thisMonthRevenue,
    required this.thisMonthOrders,
    required this.monthly,
    required this.topCrops,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) => SalesReport(
        farmerName: json['farmer_name'] as String,
        totalRevenue: (json['total_revenue'] as num).toDouble(),
        totalOrders: json['total_orders'] as int,
        averageOrderValue: (json['average_order_value'] as num).toDouble(),
        totalKgSold: json['total_kg_sold'] as int,
        pendingRevenue: (json['pending_revenue'] as num).toDouble(),
        pendingOrders: json['pending_orders'] as int,
        thisMonthRevenue: (json['this_month_revenue'] as num).toDouble(),
        thisMonthOrders: json['this_month_orders'] as int,
        monthly: (json['monthly'] as List)
            .map((m) => MonthlySales.fromJson(m))
            .toList(),
        topCrops: (json['top_crops'] as List)
            .map((c) => TopCrop.fromJson(c))
            .toList(),
      );
}

class NearbyFarm {
  final int ownerId;
  final String farmerName;
  final String? farmName;
  final String? address;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final int listings;
  final String? phone;

  NearbyFarm({
    required this.ownerId,
    required this.farmerName,
    this.farmName,
    this.address,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    required this.listings,
    this.phone,
  });

  factory NearbyFarm.fromJson(Map<String, dynamic> json) => NearbyFarm(
        ownerId: json['owner_id'] as int,
        farmerName: json['farmer_name'] as String,
        farmName: json['farm_name'] as String?,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        listings: json['listings'] as int,
        phone: json['phone'] as String?,
      );
}

class ArModel {
  final String key;
  final String label;
  final String category;
  final String url;
  final double sizeKb;

  ArModel({
    required this.key,
    required this.label,
    required this.category,
    required this.url,
    required this.sizeKb,
  });

  factory ArModel.fromJson(Map<String, dynamic> json) => ArModel(
        key: json['key'] as String,
        label: json['label'] as String,
        category: json['category'] as String,
        url: json['url'] as String,
        sizeKb: (json['size_kb'] as num).toDouble(),
      );
}

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String? refType;
  final int? refId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.refType,
    this.refId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool,
        refType: json['ref_type'] as String?,
        refId: json['ref_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CropRequest {
  final int id;
  final int buyerId;
  final String buyerName;
  final String cropName;
  final int quantityKg;
  final double? maxPricePerKg;
  final String? note;
  final String status;
  final int? acceptedById;
  final String? acceptedByName;
  final int? convertedOrderId;
  final DateTime createdAt;

  CropRequest({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.cropName,
    required this.quantityKg,
    this.maxPricePerKg,
    this.note,
    required this.status,
    this.acceptedById,
    this.acceptedByName,
    this.convertedOrderId,
    required this.createdAt,
  });

  factory CropRequest.fromJson(Map<String, dynamic> json) => CropRequest(
        id: json['id'] as int,
        buyerId: json['buyer_id'] as int,
        buyerName: json['buyer_name'] as String,
        cropName: json['crop_name'] as String,
        quantityKg: json['quantity_kg'] as int,
        maxPricePerKg: (json['max_price_per_kg'] as num?)?.toDouble(),
        note: json['note'] as String?,
        status: json['status'] as String,
        acceptedById: json['accepted_by_id'] as int?,
        acceptedByName: json['accepted_by_name'] as String?,
        convertedOrderId: json['converted_order_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isOpen => status == 'open';
}

class Badges {
  final int unreadNotifications;
  final int pendingOrders;
  final int openRequests;

  const Badges({
    this.unreadNotifications = 0,
    this.pendingOrders = 0,
    this.openRequests = 0,
  });

  factory Badges.fromJson(Map<String, dynamic> json) => Badges(
        unreadNotifications: json['unread_notifications'] as int,
        pendingOrders: json['pending_orders'] as int,
        openRequests: json['open_requests'] as int,
      );
}

class ModelUploadResult {
  final int productId;
  final String filename;
  final double sizeKb;
  final String modelUrl;
  final String? warning;

  ModelUploadResult({
    required this.productId,
    required this.filename,
    required this.sizeKb,
    required this.modelUrl,
    this.warning,
  });

  factory ModelUploadResult.fromJson(Map<String, dynamic> json) =>
      ModelUploadResult(
        productId: json['product_id'] as int,
        filename: json['filename'] as String,
        sizeKb: (json['size_kb'] as num).toDouble(),
        modelUrl: json['model_url'] as String,
        warning: json['warning'] as String?,
      );
}

/// Tamparuli town - fallback reference point when the buyer has not
/// set their own location.
const double kTamparuliLat = 6.1447;
const double kTamparuliLng = 116.2757;

// --------------------------------------------------------------- service

class ApiService {
  /// The logged-in user's token. Set by login(), cleared by logout().
  static String? _token;
  static AppUser? currentUser;

  static bool get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Pulls the human-readable message out of a FastAPI error response.
  static String _errorMessage(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg']?.toString() ?? 'Invalid input';
      }
    } catch (_) {}
    return 'Something went wrong (${r.statusCode})';
  }

  // ------------------------------------------------------------ auth

  /// POST /login  - note this endpoint wants form data, not JSON.
  static Future<AppUser> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'] as String;
      currentUser = AppUser.fromJson(data['user']);
      return currentUser!;
    }
    throw Exception(_errorMessage(response));
  }

  /// POST /register
  static Future<AppUser> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'full_name': fullName,
            'role': role,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'] as String;
      currentUser = AppUser.fromJson(data['user']);
      return currentUser!;
    }
    throw Exception(_errorMessage(response));
  }

  static void logout() {
    _token = null;
    currentUser = null;
  }

  /// PUT /me - update your own name / phone.
  static Future<AppUser> updateProfile({
    String? fullName,
    String? phone,
    String? farmName,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http
        .put(
          Uri.parse('$kBaseUrl/me'),
          headers: _headers,
          body: jsonEncode({
            'full_name': ?fullName,
            'phone': ?phone,
            'farm_name': ?farmName,
            'address': ?address,
            'latitude': ?latitude,
            'longitude': ?longitude,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      currentUser = AppUser.fromJson(jsonDecode(response.body));
      return currentUser!;
    }
    throw Exception(_errorMessage(response));
  }

  /// POST /me/password - change your own password.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/me/password'),
          headers: _headers,
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw Exception(_errorMessage(response));
  }

  /// GET /farms/nearby - FR3 proximity map data.
  static Future<List<NearbyFarm>> fetchNearbyFarms({
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final params = <String, String>{
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (radiusKm != null) 'radius_km': '$radiusKm',
    };
    final uri = Uri.parse('$kBaseUrl/farms/nearby')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((f) => NearbyFarm.fromJson(f)).toList();
    }
    throw Exception(_errorMessage(response));
  }

  /// GET /me/stats - activity summary for the profile screen.
  static Future<UserStats> fetchMyStats() async {
    final response = await http
        .get(Uri.parse('$kBaseUrl/me/stats'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return UserStats.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  // -------------------------------------------------------- products

  /// GET /products - the public marketplace, every farmer's crops.
  static Future<List<Product>> fetchProducts({
    double? lat,
    double? lng,
    double? radiusKm,
    String? sort,
  }) async {
    final params = <String, String>{
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (radiusKm != null) 'radius_km': '$radiusKm',
      'sort': ?sort,
    };
    final uri = Uri.parse('$kBaseUrl/products')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Product.fromJson(item)).toList();
    }
    throw Exception(_errorMessage(response));
  }

  /// GET /products/mine - only the logged-in farmer's own crops.
  static Future<List<Product>> fetchMyProducts() async {
    final response = await http
        .get(Uri.parse('$kBaseUrl/products/mine'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Product.fromJson(item)).toList();
    }
    throw Exception(_errorMessage(response));
  }

  /// POST /products - farmer_name and owner are set by the backend.
  static Future<Product> createProduct({
    required String name,
    required double pricePerUnit,
    required int stockQuantity,
    required String unit,
    required String category,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? modelKey,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/products'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'price_per_unit': pricePerUnit,
            'stock_quantity': stockQuantity,
            'unit': unit,
            'category': category,
            'available_from': _dateOnlyIso(availableFrom),
            'available_until': _dateOnlyIso(availableUntil),
            'model_key': ?modelKey,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  /// PUT /products/{id} - send only the fields you want to change.
  static Future<Product> updateProduct({
    required int id,
    String? name,
    double? pricePerUnit,
    int? stockQuantity,
    String? unit,
    String? category,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? modelKey,
  }) async {
    final response = await http
        .put(
          Uri.parse('$kBaseUrl/products/$id'),
          headers: _headers,
          body: jsonEncode({
            'name': ?name,
            'price_per_unit': ?pricePerUnit,
            'stock_quantity': ?stockQuantity,
            'unit': ?unit,
            'category': ?category,
            'available_from': _dateOnlyIso(availableFrom),
            'available_until': _dateOnlyIso(availableUntil),
            'model_key': ?modelKey,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  /// DELETE /products/{id}
  static Future<void> deleteProduct(int id) async {
    final response = await http
        .delete(Uri.parse('$kBaseUrl/products/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw Exception(_errorMessage(response));
  }

  // ---------------------------------------------------------- orders

  /// GET /orders - buyers see orders they placed, farmers see orders received.
  static Future<List<Order>> fetchOrders({String? status}) async {
    final uri = Uri.parse(
        '$kBaseUrl/orders${status != null ? '?status=$status' : ''}');
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Order.fromJson(item)).toList();
    }
    throw Exception(_errorMessage(response));
  }

  /// POST /orders - buyer places an order.
  static Future<Order> createOrder({
    required int productId,
    required int quantity,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/orders'),
          headers: _headers,
          body: jsonEncode({
            'product_id': productId,
            'quantity': quantity,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  /// PATCH /orders/{id}/status - confirmed | completed | cancelled
  static Future<Order> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$kBaseUrl/orders/$orderId/status'),
          headers: _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  // -------------------------------------------------------------- AR

  /// GET /ar/models - FR4, the pre-loaded 3D model gallery.
  static Future<List<ArModel>> fetchArModels() async {
    final response = await http
        .get(Uri.parse('$kBaseUrl/ar/models'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => ArModel.fromJson(m)).toList();
    }
    throw Exception(_errorMessage(response));
  }

  /// POST /products/{id}/model - upload the farmer's own .glb scan.
  /// `bytes` keeps this working on web, where there is no File path.
  static Future<ModelUploadResult> uploadProductModel({
    required int productId,
    required String filename,
    required List<int> bytes,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$kBaseUrl/products/$productId/model'),
    );
    if (_token != null) {
      req.headers['Authorization'] = 'Bearer $_token';
    }
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return ModelUploadResult.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  /// DELETE /products/{id}/model - remove the uploaded scan.
  static Future<void> deleteProductModel(int productId) async {
    final response = await http
        .delete(Uri.parse('$kBaseUrl/products/$productId/model'),
            headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw Exception(_errorMessage(response));
  }

  // ------------------------------------------- notifications (FR8)

  static Future<List<AppNotification>> fetchNotifications({
    bool unreadOnly = false,
    String? type,
  }) async {
    final params = <String, String>{
      if (unreadOnly) 'unread_only': 'true',
      'type': ?type,
    };
    final uri = Uri.parse('$kBaseUrl/notifications')
        .replace(queryParameters: params.isEmpty ? null : params);
    final r = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final List<dynamic> d = jsonDecode(r.body);
      return d.map((n) => AppNotification.fromJson(n)).toList();
    }
    throw Exception(_errorMessage(r));
  }

  /// GET /me/badges - all three header counts in one request.
  static Future<Badges> fetchBadges() async {
    final r = await http
        .get(Uri.parse('$kBaseUrl/me/badges'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return Badges.fromJson(jsonDecode(r.body));
    throw Exception(_errorMessage(r));
  }

  static Future<int> fetchUnreadCount() async {
    final r = await http
        .get(Uri.parse('$kBaseUrl/notifications/unread-count'),
            headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      return jsonDecode(r.body)['unread'] as int;
    }
    throw Exception(_errorMessage(r));
  }

  static Future<void> markNotificationRead(int id) async {
    final r = await http
        .patch(Uri.parse('$kBaseUrl/notifications/$id/read'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return;
    throw Exception(_errorMessage(r));
  }

  static Future<void> markAllNotificationsRead() async {
    final r = await http
        .post(Uri.parse('$kBaseUrl/notifications/read-all'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 204 || r.statusCode == 200) return;
    throw Exception(_errorMessage(r));
  }

  // -------------------------------------------- crop requests (FR6)

  static Future<List<CropRequest>> fetchRequests({
    String? status,
    bool mine = false,
  }) async {
    final params = <String, String>{
      'status': ?status,
      if (mine) 'mine': 'true',
    };
    final uri = Uri.parse('$kBaseUrl/requests')
        .replace(queryParameters: params.isEmpty ? null : params);
    final r = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final List<dynamic> d = jsonDecode(r.body);
      return d.map((x) => CropRequest.fromJson(x)).toList();
    }
    throw Exception(_errorMessage(r));
  }

  static Future<CropRequest> createRequest({
    required String cropName,
    required int quantityKg,
    double? maxPricePerKg,
    String? note,
  }) async {
    final r = await http
        .post(Uri.parse('$kBaseUrl/requests'),
            headers: _headers,
            body: jsonEncode({
              'crop_name': cropName,
              'quantity_kg': quantityKg,
              'max_price_per_kg': ?maxPricePerKg,
              'note': ?note,
            }))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 201 || r.statusCode == 200) {
      return CropRequest.fromJson(jsonDecode(r.body));
    }
    throw Exception(_errorMessage(r));
  }

  /// FR6: accepting a request. Pass productId to also create an order
  /// for the buyer straight away (request-to-order conversion).
  static Future<CropRequest> acceptRequest(int id, {int? productId}) async {
    final r = await http
        .post(Uri.parse('$kBaseUrl/requests/$id/accept'),
            headers: _headers,
            body: jsonEncode({'product_id': ?productId}))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return CropRequest.fromJson(jsonDecode(r.body));
    throw Exception(_errorMessage(r));
  }

  static Future<CropRequest> cancelRequest(int id) async {
    final r = await http
        .post(Uri.parse('$kBaseUrl/requests/$id/cancel'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return CropRequest.fromJson(jsonDecode(r.body));
    throw Exception(_errorMessage(r));
  }

  // --------------------------------------------------------- reports

  /// GET /reports/sales - FR7, farmer only.
  static Future<SalesReport> fetchSalesReport({int months = 6}) async {
    final response = await http
        .get(Uri.parse('$kBaseUrl/reports/sales?months=$months'),
            headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return SalesReport.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }
}
