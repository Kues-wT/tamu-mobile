import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_service.dart';

/// FR1 Admin - data classes and calls for the web admin panel.
/// Every call needs an admin token (the backend's /admin/* router).

/// The database stamps created_at in UTC without a zone marker, so read
/// it as UTC and show it in the admin's local time.
DateTime _serverTime(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toLocal();
}

class AdminUser {
  final int id;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final String? farmName;
  final String? address;
  final String status; // active | suspended
  final DateTime createdAt;
  final int listings;
  final int orders;

  AdminUser.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      email = j['email'] as String,
      fullName = j['full_name'] as String,
      role = j['role'] as String,
      phone = j['phone'] as String?,
      farmName = j['farm_name'] as String?,
      address = j['address'] as String?,
      status = j['status'] as String,
      createdAt = _serverTime(j['created_at'] as String),
      listings = j['listings'] as int,
      orders = j['orders'] as int;

  bool get isSuspended => status == 'suspended';
}

class AdminActivity {
  final String kind; // user | order
  final String text;
  final DateTime createdAt;

  AdminActivity.fromJson(Map<String, dynamic> j)
    : kind = j['kind'] as String,
      text = j['text'] as String,
      createdAt = _serverTime(j['created_at'] as String);
}

class AdminOverview {
  final int totalUsers;
  final int farmers;
  final int buyers;
  final int suspendedUsers;
  final int activeListings;
  final int hiddenListings;
  final int ordersThisMonth;
  final double revenueThisMonth;
  final int pendingOrders;
  final List<AdminActivity> recentActivity;

  AdminOverview.fromJson(Map<String, dynamic> j)
    : totalUsers = j['total_users'] as int,
      farmers = j['farmers'] as int,
      buyers = j['buyers'] as int,
      suspendedUsers = j['suspended_users'] as int,
      activeListings = j['active_listings'] as int,
      hiddenListings = j['hidden_listings'] as int,
      ordersThisMonth = j['orders_this_month'] as int,
      revenueThisMonth = (j['revenue_this_month'] as num).toDouble(),
      pendingOrders = j['pending_orders'] as int,
      recentActivity = (j['recent_activity'] as List)
          .map((e) => AdminActivity.fromJson(e))
          .toList();
}

class AdminProduct {
  final int id;
  final String name;
  final String category;
  final String farmerName;
  final String? farmName;
  final double pricePerUnit;
  final int stockQuantity;
  final String unit;
  final DateTime? availableUntil;
  final String? photoUrl;
  final bool adminHidden;
  final bool ownerSuspended;
  final bool expired;
  final int orders;

  AdminProduct.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      name = j['name'] as String,
      category = j['category'] as String,
      farmerName = j['farmer_name'] as String,
      farmName = j['farm_name'] as String?,
      pricePerUnit = (j['price_per_unit'] as num).toDouble(),
      stockQuantity = j['stock_quantity'] as int,
      unit = j['unit'] as String,
      availableUntil = j['available_until'] == null
          ? null
          : DateTime.parse(j['available_until'] as String),
      photoUrl = j['photo_url'] as String?,
      adminHidden = j['admin_hidden'] as bool,
      ownerSuspended = j['owner_suspended'] as bool,
      expired = j['expired'] as bool,
      orders = j['orders'] as int;

  /// What a buyer would see: the first reason it is off the market wins.
  String get status => adminHidden
      ? 'Hidden'
      : ownerSuspended
      ? 'Farmer suspended'
      : expired
      ? 'Expired'
      : 'Live';
}

class AdminOrder {
  final int id;
  final String buyerName;
  final String? productName;
  final String? farmerName;
  final String? farmName;
  final int quantity;
  final String unit;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final String fulfilmentMethod;
  final String paymentMethod;

  AdminOrder.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      buyerName = j['buyer_name'] as String,
      productName = j['product_name'] as String?,
      farmerName = j['farmer_name'] as String?,
      farmName = j['farm_name'] as String?,
      quantity = j['quantity'] as int,
      unit = (j['unit'] as String?) ?? 'kg',
      totalPrice = (j['total_price'] as num).toDouble(),
      status = j['status'] as String,
      createdAt = _serverTime(j['created_at'] as String),
      fulfilmentMethod = (j['fulfilment_method'] as String?) ?? 'pickup',
      paymentMethod = (j['payment_method'] as String?) ?? 'pay_on_handover';
}

class ReportBucket {
  final String label;
  final int orders;
  final double revenue;

  ReportBucket.fromJson(Map<String, dynamic> j)
    : label = j['label'] as String,
      orders = j['orders'] as int,
      revenue = (j['revenue'] as num).toDouble();
}

class PlatformReport {
  final String period;
  final int totalOrders;
  final int completedOrders;
  final double revenue;
  final int newFarmers;
  final int newBuyers;
  final int activeBuyers;
  final List<ReportBucket> chart;
  final List<({String farmName, int orders, double revenue})> topFarms;
  final List<({String name, int quantity, String unit, int orders})> topCrops;

  PlatformReport.fromJson(Map<String, dynamic> j)
    : period = j['period'] as String,
      totalOrders = j['total_orders'] as int,
      completedOrders = j['completed_orders'] as int,
      revenue = (j['revenue'] as num).toDouble(),
      newFarmers = j['new_farmers'] as int,
      newBuyers = j['new_buyers'] as int,
      activeBuyers = j['active_buyers'] as int,
      chart = (j['chart'] as List)
          .map((e) => ReportBucket.fromJson(e))
          .toList(),
      topFarms = (j['top_farms'] as List)
          .map(
            (e) => (
              farmName: e['farm_name'] as String,
              orders: e['orders'] as int,
              revenue: (e['revenue'] as num).toDouble(),
            ),
          )
          .toList(),
      topCrops = (j['top_crops'] as List)
          .map(
            (e) => (
              name: e['product_name'] as String,
              quantity: e['quantity'] as int,
              unit: (e['unit'] as String?) ?? 'kg',
              orders: e['orders'] as int,
            ),
          )
          .toList();
}

class Announcement {
  final int id;
  final String title;
  final String message;
  final String audience; // all | farmer | buyer
  final int sentCount;
  final DateTime createdAt;

  Announcement.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      title = j['title'] as String,
      message = j['message'] as String,
      audience = j['audience'] as String,
      sentCount = j['sent_count'] as int,
      createdAt = _serverTime(j['created_at'] as String);
}

class AdminApi {
  static const _timeout = Duration(seconds: 15);

  static Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final q = {
      for (final e in query.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('$kBaseUrl/admin$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  static Future<dynamic> _send(
    Future<http.Response> request, {
    int ok = 200,
  }) async {
    final r = await request.timeout(_timeout);
    if (r.statusCode == ok) {
      return r.body.isEmpty ? null : jsonDecode(r.body);
    }
    throw Exception(ApiService.errorMessage(r));
  }

  static Future<dynamic> _get(
    String path, [
    Map<String, String?> q = const {},
  ]) => _send(http.get(_uri(path, q), headers: ApiService.authHeaders));

  static Future<dynamic> _post(String path, [Object? body, int ok = 200]) =>
      _send(
        http.post(
          _uri(path),
          headers: ApiService.authHeaders,
          body: body == null ? null : jsonEncode(body),
        ),
        ok: ok,
      );

  // ---------------------------------------------------------- dashboard

  static Future<AdminOverview> overview() async =>
      AdminOverview.fromJson(await _get('/overview'));

  // ---------------------------------------------------------- users

  static Future<List<AdminUser>> users({
    String? search,
    String? role,
    String? status,
  }) async {
    final list = await _get('/users', {
      'search': search,
      'role': role,
      'status': status,
    });
    return (list as List).map((e) => AdminUser.fromJson(e)).toList();
  }

  static Future<AdminUser> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
    String? farmName,
  }) async => AdminUser.fromJson(
    await _post('/users', {
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (farmName != null && farmName.isNotEmpty) 'farm_name': farmName,
    }, 201),
  );

  static Future<AdminUser> updateUser(
    int id, {
    required String email,
    required String fullName,
    String? phone,
    String? farmName,
    String? address,
  }) async => AdminUser.fromJson(
    await _send(
      http.put(
        _uri('/users/$id'),
        headers: ApiService.authHeaders,
        body: jsonEncode({
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'farm_name': farmName,
          'address': address,
        }),
      ),
    ),
  );

  static Future<AdminUser> suspendUser(int id) async =>
      AdminUser.fromJson(await _post('/users/$id/suspend'));

  static Future<AdminUser> reactivateUser(int id) async =>
      AdminUser.fromJson(await _post('/users/$id/reactivate'));

  static Future<void> deleteUser(int id) => _send(
    http.delete(_uri('/users/$id'), headers: ApiService.authHeaders),
    ok: 204,
  );

  // ---------------------------------------------------------- marketplace

  static Future<List<AdminProduct>> products({
    String? search,
    String? status,
  }) async {
    final list = await _get('/products', {'search': search, 'status': status});
    return (list as List).map((e) => AdminProduct.fromJson(e)).toList();
  }

  static Future<AdminProduct> setProductHidden(int id, bool hidden) async =>
      AdminProduct.fromJson(
        await _post('/products/$id/${hidden ? 'hide' : 'unhide'}'),
      );

  static Future<List<AdminOrder>> orders({
    String? search,
    String? status,
  }) async {
    final list = await _get('/orders', {'search': search, 'status': status});
    return (list as List).map((e) => AdminOrder.fromJson(e)).toList();
  }

  // ---------------------------------------------------------- reports

  static Future<PlatformReport> report(String period) async =>
      PlatformReport.fromJson(await _get('/reports', {'period': period}));

  // ---------------------------------------------------------- announcements

  static Future<List<Announcement>> announcements() async {
    final list = await _get('/announcements');
    return (list as List).map((e) => Announcement.fromJson(e)).toList();
  }

  static Future<Announcement> sendAnnouncement({
    required String title,
    required String message,
    required String audience,
  }) async => Announcement.fromJson(
    await _post('/announcements', {
      'title': title,
      'message': message,
      'audience': audience,
    }, 201),
  );
}
