import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'login_screen.dart';

/// Profile screen (part of FR1 User Management).
/// View details, edit name and phone, change password, logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserStats> _statsFuture;
  bool _changed = false; // tells the previous screen to refresh

  @override
  void initState() {
    super.initState();
    _statsFuture = ApiService.fetchMyStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = ApiService.fetchMyStats();
    });
    await _statsFuture;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content:
            Text(msg, style: const TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }

  // ---------------------------------------------------------- edit profile

  Future<void> _editProfile() async {
    final user = ApiService.currentUser!;
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 16),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: TamuSizes.gap),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (saved != true) return;

    try {
      await ApiService.updateProfile(
        fullName: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      _changed = true;
      setState(() {});
      _snack('Profile updated', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  // --------------------------------------------------------- change password

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    helperText: 'At least 6 characters',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: (v) =>
                      (v != newCtrl.text) ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Change', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (submit != true) return;

    try {
      await ApiService.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: newCtrl.text,
      );
      if (!mounted) return;
      _snack('Password changed successfully', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  // -------------------------------------------------------------- location

  /// FR3: set the farm (or pickup) location. Coordinates are typed in,
  /// which works offline and needs no GPS permission. Tell the farmer
  /// how to read them off Google Maps.
  Future<void> _editLocation() async {
    final user = ApiService.currentUser!;
    final farmCtrl = TextEditingController(text: user.farmName ?? '');
    final addrCtrl = TextEditingController(text: user.address ?? '');
    final latCtrl =
        TextEditingController(text: user.latitude?.toString() ?? '');
    final lngCtrl =
        TextEditingController(text: user.longitude?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.isFarmer ? 'Farm Location' : 'My Location'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.isFarmer) ...[
                  TextFormField(
                    controller: farmCtrl,
                    style: const TextStyle(fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Farm Name',
                      hintText: 'e.g. Ladang Siti',
                      prefixIcon: Icon(Icons.agriculture_outlined),
                    ),
                  ),
                  const SizedBox(height: TamuSizes.gap),
                ],
                TextFormField(
                  controller: addrCtrl,
                  style: const TextStyle(fontSize: 16),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Address / Village',
                    hintText: 'e.g. Kg. Sayap, Tamparuli',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: TamuSizes.gap),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latCtrl,
                        style: const TextStyle(fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '6.1447',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim());
                          if (n == null) return 'Numbers only';
                          if (n < -90 || n > 90) return '-90 to 90';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: lngCtrl,
                        style: const TextStyle(fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '116.2757',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim());
                          if (n == null) return 'Numbers only';
                          if (n < -180 || n > 180) return '-180 to 180';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TamuColors.lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'How to find your coordinates:\n'
                    '1. Open Google Maps and find your farm\n'
                    '2. Press and hold on the exact spot\n'
                    '3. The numbers shown are latitude, longitude',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (saved != true) return;

    try {
      await ApiService.updateProfile(
        farmName: user.isFarmer ? farmCtrl.text.trim() : null,
        address: addrCtrl.text.trim(),
        latitude: double.tryParse(latCtrl.text.trim()),
        longitude: double.tryParse(lngCtrl.text.trim()),
      );
      if (!mounted) return;
      _changed = true;
      setState(() {});
      _snack('Location saved', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  // ----------------------------------------------------------------- logout

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again.',
            style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out',
                style: TextStyle(fontSize: 16, color: TamuColors.danger)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    ApiService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: TamuColors.background,
        appBar: AppBar(title: const Text('My Profile')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: user == null
                  ? const Center(child: Text('Not logged in'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.all(TamuSizes.pagePadding),
                        children: [
                          _buildHeaderCard(user),
                          const SizedBox(height: 16),
                          _buildStats(),
                          const SizedBox(height: 16),
                          _buildDetails(user),
                          const SizedBox(height: 16),
                          _buildLocationCard(user),
                          const SizedBox(height: 16),
                          _buildActions(),
                          const SizedBox(height: 24),
                          const Center(
                            child: Text('TAMU  ·  Tamparuli, Sabah',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: TamuColors.textSecondary)),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AppUser user) {
    final initials = user.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TamuColors.primary,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(user.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.isFarmer ? '🌾  FARMER' : '🛒  BUYER',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: TamuColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return FutureBuilder<UserStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) return const SizedBox.shrink();

        final s = snapshot.data!;
        final isFarmer = ApiService.currentUser?.isFarmer ?? false;

        return Row(
          children: [
            if (isFarmer) ...[
              Expanded(
                  child: _statTile('${s.listings}', 'Listings',
                      Icons.inventory_2_outlined, TamuColors.primary)),
              const SizedBox(width: TamuSizes.gap),
              Expanded(
                  child: _statTile('${s.ordersReceived}', 'Orders Received',
                      Icons.receipt_long_outlined, TamuColors.info)),
            ] else ...[
              Expanded(
                  child: _statTile('${s.ordersPlaced}', 'Orders Placed',
                      Icons.shopping_bag_outlined, TamuColors.primary)),
            ],
            const SizedBox(width: TamuSizes.gap),
            Expanded(
                child: _statTile('${s.completedOrders}', 'Completed',
                    Icons.check_circle_outline, TamuColors.primary)),
          ],
        );
      },
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: TamuColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDetails(AppUser user) {
    return Container(
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        children: [
          _row(Icons.email_outlined, 'Email', user.email),
          const Divider(height: 1),
          _row(Icons.phone_outlined, 'Phone',
              (user.phone == null || user.phone!.isEmpty) ? 'Not set' : user.phone!),
          const Divider(height: 1),
          FutureBuilder<UserStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final text = snapshot.hasData
                  ? _formatDate(snapshot.data!.memberSince)
                  : '...';
              return _row(Icons.calendar_today_outlined, 'Member since', text);
            },
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TamuColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: TamuColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AppUser user) {
    final has = user.hasLocation;
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: has ? TamuColors.surface : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(
            color: has ? TamuColors.border : TamuColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(has ? Icons.location_on : Icons.location_off,
                  size: 20,
                  color: has ? TamuColors.primary : TamuColors.warning),
              const SizedBox(width: 8),
              Text(user.isFarmer ? 'Farm Location' : 'My Location',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: _editLocation,
                child: Text(has ? 'Edit' : 'Set',
                    style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!has)
            Text(
              user.isFarmer
                  ? 'Buyers cannot see how far away your farm is until you set a location.'
                  : 'Set your location to see how far each farm is from you.',
              style: const TextStyle(
                  fontSize: 14, color: TamuColors.textSecondary),
            )
          else ...[
            if (user.farmName != null && user.farmName!.isNotEmpty)
              Text(user.farmName!,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            if (user.address != null && user.address!.isNotEmpty)
              Text(user.address!,
                  style: const TextStyle(
                      fontSize: 14, color: TamuColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '${user.latitude!.toStringAsFixed(4)}, '
              '${user.longitude!.toStringAsFixed(4)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: TamuColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _editProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Profile'),
        ),
        const SizedBox(height: TamuSizes.gap),
        OutlinedButton.icon(
          onPressed: _changePassword,
          icon: const Icon(Icons.lock_reset),
          label: const Text('Change Password'),
        ),
        const SizedBox(height: TamuSizes.gap),
        OutlinedButton.icon(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: TamuColors.danger,
            side: const BorderSide(color: TamuColors.danger),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}