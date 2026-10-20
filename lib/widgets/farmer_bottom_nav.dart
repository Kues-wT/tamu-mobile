import 'package:flutter/material.dart';
import '../theme.dart';

const _farmerTabRoutes = [
  '/farmer/home',
  '/farmer/listings',
  '/farmer/orders',
  '/farmer/profile',
];

/// Replaces the current farmer tab so there is only one main tab on the stack.
void navigateToFarmerTab(BuildContext context, int index) {
  if (index < 0 || index >= _farmerTabRoutes.length) return;
  Navigator.of(context).pushNamedAndRemoveUntil(
    _farmerTabRoutes[index],
    (route) => false,
  );
}

class FarmerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FarmerBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.home_outlined,
    Icons.eco_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ];
  static const _labels = ['Home', 'Listings', 'Orders', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: TamuColors.border)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 2,
                        decoration: BoxDecoration(
                          color: i == currentIndex
                              ? TamuColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Icon(
                        _icons[i],
                        size: 19,
                        color: i == currentIndex
                            ? TamuColors.primary
                            : TamuColors.textSecondary,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: i == currentIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == currentIndex
                              ? TamuColors.primary
                              : TamuColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
