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

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String?,
      );

  bool get isFarmer => role == 'farmer';
  bool get isBuyer => role == 'buyer';
}

class Product {
  final int id;
  final String name;
  final String farmerName;
  final double pricePerKg;
  final int stockKg;
  final String category;
  final int ownerId;

  Product({
    required this.id,
    required this.name,
    required this.farmerName,
    required this.pricePerKg,
    required this.stockKg,
    required this.category,
    required this.ownerId,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        farmerName: json['farmer_name'] as String,
        pricePerKg: (json['price_per_kg'] as num).toDouble(),
        stockKg: json['stock_kg'] as int,
        category: json['category'] as String,
        ownerId: json['owner_id'] as int,
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

  // -------------------------------------------------------- products

  /// GET /products - the public marketplace, every farmer's crops.
  static Future<List<Product>> fetchProducts() async {
    final response = await http
        .get(Uri.parse('$kBaseUrl/products'), headers: _headers)
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
}
