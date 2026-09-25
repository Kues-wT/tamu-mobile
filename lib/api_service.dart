import 'dart:convert';
import 'package:http/http.dart' as http;

/// Where the FastAPI backend lives.
///
/// Chrome on the same laptop   -> http://127.0.0.1:8000
/// Real Android phone on Wi-Fi -> `http://<your-laptop-IP>:8000`
///   (find it with `ipconfig`, look for IPv4 Address, e.g. 192.168.0.12)
/// Android emulator            -> http://10.0.2.2:8000
const String kBaseUrl = 'http://127.0.0.1:8000';

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
  final double pricePerKg;
  final int stockKg;
  final String category;
  final int ownerId;
  final String? farmName;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  Product({
    required this.id,
    required this.name,
    required this.farmerName,
    required this.pricePerKg,
    required this.stockKg,
    required this.category,
    required this.ownerId,
    this.farmName,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        farmerName: json['farmer_name'] as String,
        pricePerKg: (json['price_per_kg'] as num).toDouble(),
        stockKg: json['stock_kg'] as int,
        category: json['category'] as String,
        ownerId: json['owner_id'] as int,
        farmName: json['farm_name'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );

  bool get isLowStock => stockKg > 0 && stockKg < 15;
  bool get isOutOfStock => stockKg <= 0;
}

class Order {
  final int id;
  final int productId;
  final int buyerId;
  final String buyerName;
  final int quantityKg;
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
    required this.quantityKg,
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
        quantityKg: json['quantity_kg'] as int,
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
  final int quantityKg;
  final double revenue;
  final int orders;

  TopCrop({
    required this.productName,
    required this.quantityKg,
    required this.revenue,
    required this.orders,
  });

  factory TopCrop.fromJson(Map<String, dynamic> json) => TopCrop(
        productName: json['product_name'] as String,
        quantityKg: json['quantity_kg'] as int,
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

  /// PUT /me - update your own name / phone / location.
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
      if (sort != null) 'sort': ?sort,
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
    required double pricePerKg,
    required int stockKg,
    required String category,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/products'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'price_per_kg': pricePerKg,
            'stock_kg': stockKg,
            'category': category,
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
    double? pricePerKg,
    int? stockKg,
    String? category,
  }) async {
    final response = await http
        .put(
          Uri.parse('$kBaseUrl/products/$id'),
          headers: _headers,
          // '?value' means "only include this entry if it is not null".
          body: jsonEncode({
            'name': ?name,
            'price_per_kg': ?pricePerKg,
            'stock_kg': ?stockKg,
            'category': ?category,
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
    required int quantityKg,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/orders'),
          headers: _headers,
          body: jsonEncode({
            'product_id': productId,
            'quantity_kg': quantityKg,
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