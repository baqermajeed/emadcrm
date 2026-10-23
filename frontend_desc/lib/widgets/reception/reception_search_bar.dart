import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../core/app_fonts.dart';

import '../../core/reception_tokens.dart';
import 'reception_assets.dart';

/// Shared reception-style search field with live suggestions.
/// When the query is cleared, [onQueryChanged] is called with `''` so filters reset.
class ReceptionSearchBar extends StatefulWidget {
  const ReceptionSearchBar({
    super.key,
    required this.controller,
    required this.suggestions,
    this.onQueryChanged,
    this.onSearch,
    this.hint = 'أبحث عن زبون , حجز , أو رقم هاتف . .',
    this.height = 58,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String>? onQueryChanged;
  final VoidCallback? onSearch;
  final String hint;
  final double height;

  /// Deduplicate non-empty suggestion labels.
  static List<String> uniqueOf(Iterable<String?> values) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final t = raw?.trim() ?? '';
      if (t.isEmpty) continue;
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out;
  }

  @override
  State<ReceptionSearchBar> createState() => _ReceptionSearchBarState();
}

class _ReceptionSearchBarState extends State<ReceptionSearchBar> {
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  List<String> _filtered = const [];
  double _barWidth = 320;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant ReceptionSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (oldWidget.suggestions != widget.suggestions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshSuggestions();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _removeOverlay();
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _refreshSuggestions();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 120), _removeOverlay);
    }
  }

  void _onText() {
    final q = widget.controller.text;
    widget.onQueryChanged?.call(q);
    _refreshSuggestions();
    setState(() {});
  }

  void _refreshSuggestions() {
    final q = widget.controller.text.trim().toLowerCase();
    if (q.isEmpty || !_focus.hasFocus) {
      _filtered = const [];
      _removeOverlay();
      return;
    }
    final seen = <String>{};
    _filtered = [];
    for (final s in widget.suggestions) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (!t.toLowerCase().contains(q)) continue;
      if (seen.add(t.toLowerCase())) _filtered.add(t);
      if (_filtered.length >= 8) break;
    }
    if (_filtered.isEmpty) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (!mounted) return;
    _overlay?.remove();
    final items = List<String>.from(_filtered);
    final query = widget.controller.text.trim();
    // Keep panel readable; hang from the right edge of the search bar (RTL).
    final width = (_barWidth * 0.72).clamp(280.0, 440.0);
    _overlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topRight,
            offset: Offset(0, widget.height + 8),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                child: _SuggestionsPanel(
                  items: items,
                  query: query,
                  onPick: (value) {
                    widget.controller.value = TextEditingValue(
                      text: value,
                      selection:
                          TextSelection.collapsed(offset: value.length),
                    );
                    widget.onQueryChanged?.call(value);
                    widget.onSearch?.call();
                    _removeOverlay();
                    _focus.unfocus();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _clear() {
    widget.controller.clear();
    widget.onQueryChanged?.call('');
    widget.onSearch?.call();
    _removeOverlay();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        _barWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 320;
        return CompositedTransformTarget(
          link: _layerLink,
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(
                      left: hasText ? 52 : 20,
                      right: 70,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: ReceptionTokens.softShadow,
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        textAlign: TextAlign.right,
                        textDirection: ui.TextDirection.rtl,
                        onSubmitted: (_) {
                          widget.onSearch?.call();
                          _removeOverlay();
                        },
                        style: TextStyle(
                          color: ReceptionTokens.navy.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          height: 1,
                        ),
                        cursorColor: ReceptionTokens.navy,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: widget.hint,
                          hintTextDirection: ui.TextDirection.rtl,
                          hintStyle: TextStyle(
                            color: ReceptionTokens.navy.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasText)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        tooltip: 'مسح',
                        onPressed: _clear,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: ReceptionTokens.navy.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        widget.onSearch?.call();
                        _refreshSuggestions();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 61,
                        height: widget.height,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: ReceptionTokens.teal,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: ReceptionTokens.cardShadow,
                        ),
                        child: Center(
                          child: RAssets.svg('dc_search', w: 24, h: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.items,
    required this.query,
    required this.onPick,
  });

  final List<String> items;
  final String query;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ReceptionTokens.teal.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: ReceptionTokens.navy.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: ReceptionTokens.teal.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    ReceptionTokens.teal.withValues(alpha: 0.12),
                    ReceptionTokens.teal.withValues(alpha: 0.03),
                    Colors.white,
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: ReceptionTokens.teal.withValues(alpha: 0.10),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ReceptionTokens.teal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: ReceptionTokens.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اقتراحات البحث',
                      textAlign: TextAlign.right,
                      style: AppFonts.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ReceptionTokens.navy,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: AppFonts.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ReceptionTokens.teal,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  return _SuggestionTile(
                    text: items[i],
                    query: query,
                    onTap: () => onPick(items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatefulWidget {
  const _SuggestionTile({
    required this.text,
    required this.query,
    required this.onTap,
  });

  final String text;
  final String query;
  final VoidCallback onTap;

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _hover = false;

  bool get _isPhone {
    final digits = widget.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7 && digits.length == widget.text.replaceAll(' ', '').length;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _isPhone ? Icons.phone_rounded : Icons.person_outline_rounded;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: _hover
            ? ReceptionTokens.teal.withValues(alpha: 0.08)
            : const Color(0xFFF7FBFD),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _hover
                        ? ReceptionTokens.teal
                        : ReceptionTokens.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: _hover ? Colors.white : ReceptionTokens.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HighlightedLabel(
                    text: widget.text,
                    query: widget.query,
                  ),
                ),
                Icon(
                  Icons.north_west_rounded,
                  size: 14,
                  color: ReceptionTokens.navy.withValues(alpha: _hover ? 0.45 : 0.22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedLabel extends StatelessWidget {
  const _HighlightedLabel({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final base = AppFonts.style(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: ReceptionTokens.navy,
      height: 1.25,
    );
    final q = query.trim();
    if (q.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    final idx = lower.indexOf(needle);
    if (idx < 0) {
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final before = text.substring(0, idx);
    final match = text.substring(idx, idx + q.length);
    final after = text.substring(idx + q.length);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before, style: base),
          TextSpan(
            text: match,
            style: base.copyWith(
              color: ReceptionTokens.teal,
              backgroundColor: ReceptionTokens.teal.withValues(alpha: 0.12),
            ),
          ),
          TextSpan(text: after, style: base),
        ],
      ),
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.rtl,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
