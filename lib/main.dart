import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/login_screen.dart' as login;
import 'screens/farmer_home_screen.dart' as farmer_home;
import 'screens/farmer_listings_screen.dart' as farmer_listings;
import 'screens/orders_screen.dart' as orders;
import 'screens/profile_screen.dart' as profile;

void main() {
  runApp(const TamuApp());
}

class TamuApp extends StatelessWidget {
  const TamuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAMU',
      debugShowCheckedModeBanner: false,
      theme: buildTamuTheme(),
      home: const login.LoginScreen(),
      routes: {
        '/farmer/home': (_) => const farmer_home.FarmerHomeScreen(),
        '/farmer/listings': (_) => const farmer_listings.FarmerListingsScreen(),
        '/farmer/orders': (_) => const orders.OrdersScreen(),
        '/farmer/profile': (_) => const profile.ProfileScreen(),
      },
    );
  }
}
