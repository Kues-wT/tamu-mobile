import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Figure 4.29 - User Management: search, role filter, and per-user
/// View / Edit / Suspend actions, plus Add user and Delete.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();
  String? _role;
  String? _status;
  List<AdminUser> _users = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await AdminApi.users(
        search: _search.text.trim(),
        role: _role,
        status: _status,
      );
      if (mounted) {
        setState(() {
          _users = list;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _reload() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      showAdminSnack(context, done);
      _load();
    } catch (e) {
      if (mounted) showAdminSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _toggleSuspend(AdminUser u) async {
    if (u.isSuspended) {
      return _run(
        () => AdminApi.reactivateUser(u.id),
        '${u.displayName} is active again.',
      );
    }
    final yes = await confirmAction(
      context,
      title: 'Suspend ${u.displayName}?',
      message:
          'They will not be able to sign in'
          '${u.role == 'farmer' ? ' and their listings will be hidden from buyers' : ''}'
          ' until you reactivate the account. Existing orders stay as they are.',
      action: 'Suspend',
      danger: true,
    );
    if (yes) {
      _run(() => AdminApi.suspendUser(u.id), '${u.displayName} is suspended.');
    }
  }

  Future<void> _delete(AdminUser u) async {
    final yes = await confirmAction(
      context,
      title: 'Delete ${u.displayName}?',
      message:
          'The account is closed and personal details are removed. '
          'Past orders stay in the records under "Deleted user". '
          'This cannot be undone.',
      action: 'Delete',
      danger: true,
    );
    if (yes) {
      _run(() => AdminApi.deleteUser(u.id), 'Account deleted.');
    }
  }

  Future<void> _openForm([AdminUser? u]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserForm(user: u),
    );
    if (saved == true) {
      if (mounted) {
        showAdminSnack(context, u == null ? 'User added.' : 'Changes saved.');
      }
      _load();
    }
  }

  void _view(AdminUser u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.displayName),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (k, v) in [
                ('Full name', u.fullName),
                if (u.role == 'admin') ('Nickname', u.nickname ?? '-'),
                ('Email', u.email),
                ('Role', u.role),
                ('Status', u.status),
                ('Phone', u.phone ?? '-'),
                if (u.role == 'farmer') ('Farm', u.farmName ?? '-'),
                ('Address', u.address ?? '-'),
                ('Joined', shortDate(u.createdAt)),
                if (u.role == 'farmer') ('Listings', '${u.listings}'),
                (
                  u.role == 'farmer' ? 'Orders received' : 'Orders placed',
                  '${u.orders}',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          k,
                          style: const TextStyle(
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Text(v)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ApiService.currentUser?.id;
    return AdminPage(
      title: 'User Management',
      subtitle: 'Farmers, buyers and admins on TAMU',
      onRefresh: _load,
      trailing: FilledButton.icon(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SearchBox(
              hint: 'Search name, email or farm',
              controller: _search,
              onSubmitted: (_) => _reload(),
            ),
            FilterChips(
              options: const {
                null: 'All',
                'farmer': 'Farmers',
                'buyer': 'Buyers',
                'admin': 'Admins',
              },
              selected: _role,
              onChanged: (v) {
                _role = v;
                _reload();
              },
            ),
            FilterChips(
              options: const {
                null: 'Any status',
                'active': 'Active',
                'suspended': 'Suspended',
              },
              selected: _status,
              onChanged: (v) {
                _status = v;
                _reload();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: LoadState(
            loading: _loading,
            error: _error,
            empty: _users.isEmpty,
            emptyText: 'No users match.',
            onRetry: _reload,
            child: AdminTable(
              columns: const ['User', 'Email', 'Role', 'Status', 'Actions'],
              widths: const [2.2, 2.4, 1, 1.1, 2.6],
              rows: [
                for (final u in _users)
                  [
                    CellText(
                      u.displayName,
                      sub: u.role == 'farmer'
                          ? (u.farmName ?? 'No farm name')
                          : u.role == 'admin'
                          ? '${u.fullName} · Joined ${shortDate(u.createdAt)}'
                          : 'Joined ${shortDate(u.createdAt)}',
                    ),
                    Text(
                      u.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      u.role[0].toUpperCase() + u.role.substring(1),
                      style: const TextStyle(fontSize: 14),
                    ),
                    StatusPill.forStatus(u.status),
                    Wrap(
                      spacing: 2,
                      children: [
                        _action('View', () => _view(u)),
                        _action('Edit', () => _openForm(u)),
                        if (u.id != me) ...[
                          _action(
                            u.isSuspended ? 'Reactivate' : 'Suspend',
                            () => _toggleSuspend(u),
                            color: u.isSuspended
                                ? TamuColors.primary
                                : TamuColors.amber,
                          ),
                          _action(
                            'Delete',
                            () => _delete(u),
                            color: TamuColors.danger,
                          ),
                        ],
                      ],
                    ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _action(String text, VoidCallback onTap, {Color? color}) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: color ?? TamuColors.info,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 36),
    ),
    onPressed: onTap,
    child: Text(text, style: const TextStyle(fontSize: 14)),
  );
}

/// Add (user == null) or edit a user.
class _UserForm extends StatefulWidget {
  final AdminUser? user;
  const _UserForm({this.user});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.fullName);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  late final _farm = TextEditingController(text: widget.user?.farmName);
  late final _address = TextEditingController(text: widget.user?.address);
  late final _nickname = TextEditingController(text: widget.user?.nickname);
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'farmer';
  bool _saving = false;
  String? _error;

  bool get _editing => widget.user != null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _farm,
      _address,
      _nickname,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await AdminApi.updateUser(
          widget.user!.id,
          email: _email.text.trim(),
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          farmName: _role == 'farmer' ? _farm.text.trim() : null,
          address: _address.text.trim(),
          nickname: _role == 'admin' ? _nickname.text.trim() : null,
        );
      } else {
        await AdminApi.createUser(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          role: _role,
          phone: _phone.text.trim(),
          farmName: _role == 'farmer' ? _farm.text.trim() : null,
          nickname: _role == 'admin' ? _nickname.text.trim() : null,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorText(e);
        });
      }
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(_editing ? 'Edit ${widget.user!.displayName}' : 'Add user'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_editing) ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'farmer', label: Text('Farmer')),
                      ButtonSegment(value: 'buyer', label: Text('Buyer')),
                      ButtonSegment(value: 'admin', label: Text('Admin')),
                    ],
                    selected: {_role},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _role = s.first),
                  ),
                  gap,
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: _required,
                ),
                gap,
                if (_role == 'admin') ...[
                  gap,
                  TextFormField(
                    controller: _nickname,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: 'Nickname',
                      helperText:
                          'Shown as "${_nickname.text.trim().isEmpty ? 'Nickname' : _nickname.text.trim()} (TAMU Admin)"',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: _required,
                  ),
                ],
                gap,
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    helperText: _role == 'admin'
                        ? 'Admins use an @tamu.my email'
                        : null,
                  ),
                  validator: (v) {
                    final email = (v ?? '').trim().toLowerCase();
                    if (!email.contains('@')) return 'Enter a valid email';
                    final tamu = email.endsWith('@tamu.my');
                    if (_role == 'admin' && !tamu) {
                      return 'Admin emails must end with @tamu.my';
                    }
                    if (_role != 'admin' && tamu) {
                      return '@tamu.my is only for admins';
                    }
                    return null;
                  },
                ),
                if (!_editing) ...[
                  gap,
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      helperText:
                          'At least 6 characters. Share it with '
                          'the user so they can change it.',
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                ],
                gap,
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                if (_role == 'farmer') ...[
                  gap,
                  TextFormField(
                    controller: _farm,
                    decoration: const InputDecoration(labelText: 'Farm name'),
                  ),
                ],
                if (_editing) ...[
                  gap,
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address / pickup point (optional)',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  gap,
                  Text(
                    _error!,
                    style: const TextStyle(color: TamuColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
