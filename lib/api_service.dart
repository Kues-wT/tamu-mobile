import 'dart:convert';
import 'package:http/http.dart' as http;

/// Where the FastAPI backend lives.
///
/// Chrome on the same laptop  -> http://127.0.0.1:8000
/// Real Android phone on Wi-Fi -> http://<your-laptop-IP>:8000
///   (find it with `ipconfig`, look for IPv4 Address, e.g. 192.168.0.12)
/// Android emulator            -> http://10.0.2.2:8000
const String kBaseUrl = 'http://127.0.0.1:8000';

/// One product coming from GET /products
class Product {
  final int id;
  final String name;
  final String farmerName;
  final double pricePerKg;
  final int stockKg;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.farmerName,
    required this.pricePerKg,
    required this.stockKg,
    required this.category,
  });

  /// Turns the JSON map from FastAPI into a Dart object.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      farmerName: json['farmer_name'] as String,
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
      stockKg: json['stock_kg'] as int,
      category: json['category'] as String,
    );
  }

  bool get isLowStock => stockKg > 0 && stockKg < 15;
  bool get isOutOfStock => stockKg <= 0;
}

class ApiService {
  /// GET /products
  static Future<List<Product>> fetchProducts() async {
    final response = await http
        .get(Uri.parse('$kBaseUrl/products'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Product.fromJson(item)).toList();
    }
    throw Exception('Failed to load products (${response.statusCode})');
  }

    /// POST /products
  static Future<Product> createProduct({
    required String name,
    required String farmerName,
    required double pricePerKg,
    required int stockKg,
    required String category,
  }) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/products'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'farmer_name': farmerName,
            'price_per_kg': pricePerKg,
            'stock_kg': stockKg,
            'category': category,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception(
        'Failed to add product (${response.statusCode}): ${response.body}');
  }
}
