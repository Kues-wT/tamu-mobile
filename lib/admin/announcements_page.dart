import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Announcements (Table 1.2): the admin writes one message and every
/// active farmer, buyer, or both receive it as a notification (FR8).
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _audience = 'all';
  bool _sending = false;

  List<Announcement> _items = [];
  String? _error;
  bool _loading = true;

  static const _audienceLabel = {
    'all': 'Everyone',
    'farmer': 'Farmers',
    'buyer': 'Buyers',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await AdminApi.announcements();
      if (mounted) {
        setState(() {
          _items = list;
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

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final yes = await confirmAction(
      context,
      title: 'Send announcement?',
      message:
          'Every active ${_audienceLabel[_audience]!.toLowerCase()} '
          'account gets "${_title.text.trim()}" as a notification. '
          'It cannot be taken back.',
      action: 'Send',
    );
    if (!yes) return;
    setState(() => _sending = true);
    try {
      final a = await AdminApi.sendAnnouncement(
        title: _title.text.trim(),
        message: _message.text.trim(),
        audience: _audience,
      );
      if (!mounted) return;
      _title.clear();
      _message.clear();
      showAdminSnack(context, 'Sent to ${a.sentCount} users.');
      _load();
    } catch (e) {
      if (mounted) showAdminSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compose = AdminPanel(
      title: 'New announcement',
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Send to',
              style: TextStyle(fontSize: 14, color: TamuColors.textSecondary),
            ),
            const SizedBox(height: 8),
            FilterChips(
              options: _audienceLabel,
              selected: _audience,
              onChanged: (v) => setState(() => _audience = v ?? 'all'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Tamu market this Sunday',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _message,
              maxLength: 300,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send announcement'),
            ),
          ],
        ),
      ),
    );

    final history = AdminPanel(
      title: 'Sent announcements',
      child: LoadState(
        loading: _loading,
        error: _error,
        empty: _items.isEmpty,
        emptyText: 'No announcements sent yet.',
        onRetry: _load,
        child: Column(
          children: [
            for (final a in _items)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: TamuColors.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo(a.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(a.message, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      '${_audienceLabel[a.audience] ?? a.audience} · '
                      'sent to ${a.sentCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return AdminPage(
      title: 'Announcements',
      subtitle:
          'Notify farmers and buyers about market days, '
          'outages or new features',
      onRefresh: _load,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [compose, const SizedBox(height: 20), history],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: compose),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: history),
              ],
            );
          },
        ),
      ],
    );
  }
}
