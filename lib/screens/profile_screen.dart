import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import '../theme.dart';
import '../api_service.dart';
import '../widgets/farmer_bottom_nav.dart';
import '../widgets/map_pin_field.dart';
import 'login_screen.dart' as login;
import 'orders_screen.dart' as orders;
import 'requests_screen.dart' as requests;
import 'notifications_screen.dart' as notifications;

/// Profile screen (part of FR1 User Management).
/// Buyers and farmers share the Figma-style account page; farmers also get
/// the public pickup point editor and the ratings card.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _changed = false; // tells the previous screen to refresh

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
    final addressCtrl = TextEditingController(text: user.address ?? '');
    final pin = MapPinController(
        latitude: user.latitude, longitude: user.longitude);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 16),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr('Full Name'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: trValidator((v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null),
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('Phone (optional)'),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (user.isBuyer) ...[
                  const SizedBox(height: TamuSizes.gap),
                  TextFormField(
                    controller: addressCtrl,
                    minLines: 1,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: tr('Delivery address / village'),
                      hintText: tr('e.g. Pekan Tamparuli, Sabah'),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: TamuSizes.gap),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Map pin (optional)',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  MapPinField(
                    controller: pin,
                    isFarmer: false,
                    emptyText: 'Pin where you are to see the nearest farms. '
                        'Without a pin, distances are measured from '
                        'Tamparuli town.',
                  ),
                ],
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

    if (saved != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
      pin.dispose();
      return;
    }

    try {
      await ApiService.updateProfile(
        fullName: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: user.isBuyer ? addressCtrl.text.trim() : null,
        latitude: user.isBuyer ? pin.latitude : null,
        longitude: user.isBuyer ? pin.longitude : null,
        clearLocation: user.isBuyer && !pin.hasPin && user.hasLocation,
      );
      if (!mounted) return;
      _changed = true;
      setState(() {});
      _snack('Profile updated', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
      pin.dispose();
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
                  decoration: InputDecoration(
                    labelText: tr('Current Password'),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: trValidator((v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null),
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('New Password'),
                    helperText: tr('At least 6 characters'),
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: trValidator((v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null),
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('Confirm New Password'),
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: trValidator((v) =>
                      (v != newCtrl.text) ? 'Passwords do not match' : null),
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

  /// FR3: set the farm's public selling/pickup point or the buyer's search
  /// location by pinning it on the real map.
  Future<void> _editLocation() async {
    final user = ApiService.currentUser!;
    final farmCtrl = TextEditingController(text: user.farmName ?? '');
    final addrCtrl = TextEditingController(text: user.address ?? '');
    final pin = MapPinController(
        latitude: user.latitude, longitude: user.longitude);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          user.isFarmer ? 'Public Selling / Pickup Point' : 'My Location',
        ),
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
                    decoration: InputDecoration(
                      labelText: tr('Farm Name'),
                      hintText: tr('e.g. Ladang Siti'),
                      prefixIcon: Icon(Icons.agriculture_outlined),
                    ),
                  ),
                  const SizedBox(height: TamuSizes.gap),
                ],
                TextFormField(
                  controller: addrCtrl,
                  style: const TextStyle(fontSize: 16),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr('Address / Village'),
                    hintText: tr(user.isFarmer
                      ? 'e.g. Tamparuli Market public stall'
                      : 'e.g. Kg. Sayap, Tamparuli'),
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: TamuSizes.gap),
                MapPinField(
                  controller: pin,
                  isFarmer: user.isFarmer,
                  emptyText: user.isFarmer
                      ? 'Pin your public selling or pickup point so buyers '
                          'can find you. Choose a market or meeting point, '
                          'not your home.'
                      : 'Pin your location to see the nearest farms.',
                ),
                if (user.isFarmer) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Buyers see this point as your public selling / pickup '
                    'location.',
                    style: TextStyle(
                        fontSize: 12, color: TamuColors.textSecondary),
                  ),
                ],
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

    if (saved != true) {
      pin.dispose();
      return;
    }

    try {
      await ApiService.updateProfile(
        farmName: user.isFarmer ? farmCtrl.text.trim() : null,
        address: addrCtrl.text.trim(),
        latitude: pin.latitude,
        longitude: pin.longitude,
        clearLocation: !pin.hasPin && user.hasLocation,
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

    await ApiService.logout(); // also forgets the saved login
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const login.LoginScreen()),
      (route) => false,
    );
  }

  // -------------------------------------------------------- delete account

  /// FR1: self-service deletion. Explains what happens, asks for the
  /// password again, then signs out. The backend refuses it while the
  /// user still has pending or confirmed orders.
  Future<void> _deleteAccount() async {
    final isFarmer = ApiService.currentUser?.isFarmer ?? false;
    final passwordCtrl = TextEditingController();
    String? error;
    var busy = false;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> confirm() async {
            if (passwordCtrl.text.isEmpty) {
              setDialog(() => error = 'Enter your password to confirm.');
              return;
            }
            setDialog(() {
              busy = true;
              error = null;
            });
            try {
              await ApiService.deleteAccount(passwordCtrl.text);
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            } catch (e) {
              setDialog(() {
                busy = false;
                error = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return AlertDialog(
            title: const Text('Delete your account?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This cannot be undone.\n\n'
                    '• Your name, phone, address and location are removed and '
                    'you can no longer sign in.\n'
                    '${isFarmer ? '• Your listings are removed from the marketplace.\n' : '• Your open crop requests are cancelled.\n'}'
                    '• Past orders stay in the other person\'s history as '
                    '"${isFarmer ? 'Deleted farmer' : 'Deleted user'}".\n\n'
                    'Finish or cancel any active orders first.',
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: tr('Current password'),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => confirm(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style: const TextStyle(
                            fontSize: 13, color: TamuColors.danger)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Keep my account'),
              ),
              TextButton(
                onPressed: busy ? null : confirm,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Delete',
                        style: TextStyle(color: TamuColors.danger)),
              ),
            ],
          );
        },
      ),
    );
    passwordCtrl.dispose();

    if (deleted != true || !mounted) return;
    // The messenger lives above the navigator, so the snackbar survives
    // the jump to the sign-in screen.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const login.LoginScreen()),
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account was deleted.')),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final isBuyer = user?.isBuyer ?? false;
    final isFarmer = user?.isFarmer ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: isFarmer ? TamuColors.warm : TamuColors.background,
        body: user == null
            ? const SafeArea(child: Center(child: Text('Not logged in')))
            : _buildAccountProfile(user),
        bottomNavigationBar: isBuyer
            ? _buildBuyerBottomNav()
            : (isFarmer
                ? FarmerBottomNav(
                    currentIndex: 3,
                    onTap: (index) {
                      if (index != 3) navigateToFarmerTab(context, index);
                    },
                  )
                : null),
      ),
    );
  }

  /// Buyer and farmer profiles share the Figma layout; farmers also get
  /// their public pickup point row and the ratings card.
  Widget _buildAccountProfile(AppUser user) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(user.isFarmer ? 'Farmer account' : 'Buyer account',
                        style: const TextStyle(
                            fontSize: 12, color: TamuColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  children: [
                    _buildBuyerIdentity(user),
                    const SizedBox(height: 22),
                    if (user.isFarmer) ...[
                      _buildFarmerSettingsCard(user),
                      const SizedBox(height: 12),
                      _buildRatingEmpty(),
                    ] else
                      _buildBuyerSettingsCard(),
                    const SizedBox(height: 12),
                    _buildRoleNote(),
                    const SizedBox(height: 12),
                    _buildBuyerSignOutButton(),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: _deleteAccount,
                        style: TextButton.styleFrom(
                          foregroundColor: TamuColors.danger,
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete account',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerIdentity(AppUser user) {
    final phone = (user.phone == null || user.phone!.trim().isEmpty)
        ? 'Phone number not added'
        : user.phone!;
    final sampleEmails = {
      'siti.tamu@gmail.com',
      'jumat.tamu@gmail.com',
      'gundoh.tamu@gmail.com',
      'aina.tamu@gmail.com',
      'linda.tamu@gmail.com',
    };
    final isSampleAccount = sampleEmails.contains(user.email.toLowerCase());

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFD9EEDC),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline,
              size: 36, color: TamuColors.primary),
        ),
        const SizedBox(height: 10),
        Text(user.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(phone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: TamuColors.textSecondary)),
        if (isSampleAccount) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: TamuColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('SAMPLE DATA',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: TamuColors.textSecondary)),
          ),
        ],
      ],
    );
  }

  Widget _buildBuyerSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        children: [
          _profileActionRow(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Name, phone and delivery address',
            onTap: _editProfile,
          ),
          const Divider(height: 1, indent: 46),
          _profileActionRow(
            icon: Icons.lock_outline,
            title: 'Change password',
            subtitle: 'Keep your account secure',
            onTap: _changePassword,
          ),
          const Divider(height: 1, indent: 46),
          _languageRow(),
          const Divider(height: 1, indent: 46),
          _profileActionRow(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Orders, requests and updates',
            onTap: _openNotifications,
          ),
        ],
      ),
    );
  }

  /// English / Bahasa Melayu switch; the choice is remembered on the phone.
  Widget _languageRow() {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLanguage.malay,
      builder: (context, malay, _) => InkWell(
        onTap: () => AppLanguage.setMalay(!malay),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                child:
                    Icon(Icons.translate, color: TamuColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bahasa Melayu',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Show the app in Malay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: TamuColors.textSecondary)),
                  ],
                ),
              ),
              Switch(value: malay, onChanged: AppLanguage.setMalay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerSettingsCard(AppUser user) {
    final pickupLabel = !user.hasLocation
        ? 'Not set yet · choose a public point, not your home'
        : [user.farmName, user.address]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TamuColors.line),
      ),
      child: Column(
        children: [
          _profileActionRow(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Name and phone',
            onTap: _editProfile,
          ),
          const Divider(height: 1, indent: 46),
          _profileActionRow(
            icon: Icons.place_outlined,
            title: 'Public pickup point',
            subtitle: pickupLabel.isEmpty ? 'Point set on map' : pickupLabel,
            onTap: _editLocation,
          ),
          const Divider(height: 1, indent: 46),
          _profileActionRow(
            icon: Icons.lock_outline,
            title: 'Change password',
            subtitle: 'Keep your account secure',
            onTap: _changePassword,
          ),
          const Divider(height: 1, indent: 46),
          _languageRow(),
          const Divider(height: 1, indent: 46),
          _profileActionRow(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Orders, requests and updates',
            onTap: _openNotifications,
          ),
        ],
      ),
    );
  }

  /// Figma ".rating-empty". Ratings (FR9) are not built yet, so this is
  /// the honest state for every farmer for now.
  Widget _buildRatingEmpty() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF0EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_border, size: 28, color: Color(0xFF828B81)),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No ratings yet',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: TamuColors.darkGreen)),
                SizedBox(height: 3),
                Text(
                  'Your average and rating count will appear after a buyer '
                  'rates a completed order.',
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: TamuColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Icon(icon, color: TamuColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: TamuColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right,
                size: 21, color: TamuColors.textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: TamuColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your role is fixed',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TamuColors.textSecondary)),
                SizedBox(height: 3),
                Text(
                  'A regular user cannot change roles or access another account.',
                  style: TextStyle(
                      fontSize: 11, color: TamuColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerSignOutButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TamuColors.border),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 19, color: TamuColors.primary),
              SizedBox(width: 8),
              Text('Sign out',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: TamuColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const notifications.NotificationsScreen()),
    );
  }

  Widget _buildBuyerBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: TamuColors.border)),
        ),
        child: Row(
          children: [
            _buyerNavItem(Icons.storefront_outlined, 'Market', false, () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }),
            _buyerNavItem(Icons.receipt_long_outlined, 'Orders', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const orders.OrdersScreen()),
              );
            }),
            _buyerNavItem(Icons.forum_outlined, 'Requests', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const requests.RequestsScreen()),
              );
            }),
            _buyerNavItem(Icons.person_outline, 'Profile', true, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buyerNavItem(
      IconData icon, String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? TamuColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 5),
            Icon(icon,
                size: 19,
                color: selected ? TamuColors.primary : TamuColors.textSecondary),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? TamuColors.primary : TamuColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}
