import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'i18n_ms.dart';

/// English / Bahasa Melayu switch for the farmer and buyer app.
///
/// Screens are written in English. When Malay is on, every piece of text is
/// looked up in [kMalay] just before it is drawn, so no screen needs its own
/// translation code. The choice is saved on the phone and restored the next
/// time the app opens. The web admin panel always stays in English.
class AppLanguage {
  AppLanguage._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'tamu_language';

  /// True while the app is shown in Malay.
  static final m.ValueNotifier<bool> malay = m.ValueNotifier(false);

  /// Reads the saved choice. Called once in main() before the app starts.
  static Future<void> load() async {
    if (kIsWeb) return;
    try {
      malay.value = await _storage.read(key: _key) == 'ms';
    } catch (_) {
      // Unreadable storage: stay in English.
    }
  }

  /// Switches language, saves the choice and redraws every screen.
  static Future<void> setMalay(bool value) async {
    if (malay.value == value) return;
    malay.value = value;
    _cache.clear();
    _redrawAll();
    try {
      await _storage.write(key: _key, value: value ? 'ms' : 'en');
    } catch (_) {
      // Not saved: the app opens in English next time.
    }
  }

  /// Rebuilds every widget, including const ones, so open screens change
  /// language straight away without losing their place.
  static void _redrawAll() {
    void visit(m.Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    m.WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}

/// Translates [text] when Malay is on; otherwise returns it unchanged.
/// Works for nullable text too: `tr(widget.hint)`.
T tr<T extends String?>(T text) {
  if (text == null || !AppLanguage.malay.value) return text;
  return _translate(text) as T;
}

/// For TextFormField: shows the validator's message in the chosen language.
m.FormFieldValidator<String>? trValidator(
        m.FormFieldValidator<String>? check) =>
    check == null ? null : (value) => tr(check(value));

final Map<String, String> _cache = {};

String _translate(String text) {
  if (text.trim().isEmpty) return text;
  final cached = _cache[text];
  if (cached != null) return cached;
  final result = _lookup(text) ?? text;
  if (_cache.length > 2000) _cache.clear();
  return _cache[text] = result;
}

/// Exact match, then the same text in capitals ("PENDING"), then patterns.
String? _lookup(String text) {
  final exact = kMalay[text];
  if (exact != null) return exact;

  final upper = _upperKeys[text];
  if (upper != null) return kMalay[upper]!.toUpperCase();

  for (final p in _patterns) {
    final match = p.regex.firstMatch(text);
    if (match == null) continue;
    return p.malay.replaceAllMapped(RegExp(r'\{(\d+)\}'), (g) {
      final part = match.group(int.parse(g.group(1)!) + 1) ?? '';
      // A part may itself be a known word, e.g. a status or "Pickup".
      return kMalay[part] ?? part;
    });
  }

  // A known word followed by a count, e.g. a filter chip "Pending 3".
  final counted = _wordAndCount.firstMatch(text);
  if (counted != null) {
    final word = kMalay[counted.group(1)!];
    if (word != null) return '$word${counted.group(2)}';
  }
  return null;
}

final RegExp _wordAndCount = RegExp(r'^(.+?)(\s+\d+)$');

/// "PENDING" -> "Pending", so text shown in capitals is found too.
final Map<String, String> _upperKeys = {
  for (final key in kMalay.keys)
    if (!key.contains('{}') && key.toUpperCase() != key) key.toUpperCase(): key,
};

class _Pattern {
  _Pattern(String english, this.malay)
      : regex = RegExp(
          '^${english.split('{}').map(RegExp.escape).join('(.+?)')}\$',
          dotAll: true,
        );
  final RegExp regex;
  final String malay;
}

/// Keys with {} become patterns. Longer, more specific keys are tried first.
final List<_Pattern> _patterns = () {
  final keys = kMalay.keys.where((k) => k.contains('{}')).toList()
    ..sort((a, b) => b.replaceAll('{}', '').length
        .compareTo(a.replaceAll('{}', '').length));
  return [for (final k in keys) _Pattern(k, kMalay[k]!)];
}();

/// Drop-in replacement for Flutter's Text that shows its text in the chosen
/// language. Screens import material.dart with `hide Text` and use this one.
class Text extends m.StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    m.InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final m.InlineSpan? textSpan;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  @override
  m.Widget build(m.BuildContext context) {
    if (data != null) {
      return m.Text(
        tr(data!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: tr(semanticsLabel),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text.rich(
      _translateSpan(textSpan!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: tr(semanticsLabel),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  static m.InlineSpan _translateSpan(m.InlineSpan span) {
    if (span is! m.TextSpan) return span;
    return m.TextSpan(
      text: tr(span.text),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: tr(span.semanticsLabel),
      locale: span.locale,
      spellOut: span.spellOut,
      children: span.children?.map(_translateSpan).toList(),
    );
  }
}

/// The on/off switch: "BM" for Bahasa Melayu. Hidden on the web admin panel.
class LanguageSwitch extends m.StatelessWidget {
  const LanguageSwitch({super.key, this.onDark = false});

  /// Light text for dark backgrounds.
  final bool onDark;

  @override
  m.Widget build(m.BuildContext context) {
    if (kIsWeb) return const m.SizedBox.shrink();
    return m.ValueListenableBuilder<bool>(
      valueListenable: AppLanguage.malay,
      builder: (context, malay, _) => m.Semantics(
        label: 'Bahasa Melayu',
        toggled: malay,
        child: m.InkWell(
          borderRadius: m.BorderRadius.circular(24),
          onTap: () => AppLanguage.setMalay(!malay),
          child: m.Padding(
            padding: const m.EdgeInsets.only(left: 10),
            child: m.Row(
              mainAxisSize: m.MainAxisSize.min,
              children: [
                m.Text(
                  'BM',
                  style: m.TextStyle(
                    fontSize: 14,
                    fontWeight: m.FontWeight.w800,
                    letterSpacing: 0.5,
                    color: onDark
                        ? m.Colors.white
                        : const m.Color(0xFF1B5E20),
                  ),
                ),
                m.Switch(
                  value: malay,
                  onChanged: AppLanguage.setMalay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
