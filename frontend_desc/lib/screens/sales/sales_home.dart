import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/reception/reception_search_bar.dart';
import '../shared/customer_profile_screen.dart';

class SalesHome extends StatefulWidget {
  const SalesHome({super.key});

  @override
  State<SalesHome> createState() => _SalesHomeState();
}

class _SalesHomeState extends State<SalesHome> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<String> _suggestionPool = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerController>().load().then((_) {
        if (!mounted) return;
        _refreshSuggestionPool();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _refreshSuggestionPool() {
    final items = context.read<CustomerController>().items;
    setState(() {
      _suggestionPool = ReceptionSearchBar.uniqueOf([
        for (final c in items) ...[c.name, c.phone],
      ]);
    });
  }

  void _runSearch(String query) {
    context.read<CustomerController>().load(search: query.trim()).then((_) {
      if (!mounted) return;
      // Keep a broader pool so suggestions stay useful while typing.
      if (query.trim().isEmpty) _refreshSuggestionPool();
    });
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _runSearch(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CustomerController>();
    final suggestions = ReceptionSearchBar.uniqueOf([
      ..._suggestionPool,
      for (final c in ctrl.items) ...[c.name, c.phone],
    ]);

    return AppScaffold(
      title: 'زبائني',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ReceptionSearchBar(
              controller: _search,
              suggestions: suggestions,
              hint: 'بحث بالاسم أو الهاتف',
              onQueryChanged: _onQueryChanged,
              onSearch: () => _runSearch(_search.text),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context
                    .read<CustomerController>()
                    .load(search: _search.text.trim());
                if (mounted && _search.text.trim().isEmpty) {
                  _refreshSuggestionPool();
                }
              },
              child: ctrl.loading && ctrl.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ctrl.items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            EmptyState(message: 'لا يوجد زبائن مسجلين لك'),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: ctrl.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final c = ctrl.items[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text('${c.phone}\n${c.profession ?? 'بدون مهنة'}'),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CustomerProfileScreen(
                                        customerId: c.id,
                                        canEdit: false,
                                        canAddDeal: true,
                                        canAddVisit: false,
                                        canUploadDocs: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
