import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/cache_service.dart';
import '../models/customer.dart';
import '../models/deal.dart';
import '../models/reservation.dart';
import '../models/visit.dart';
import '../services/customer_service.dart';
import '../services/deal_service.dart';
import '../services/reservation_service.dart';
import '../services/visit_service.dart';
import '../utils/enums.dart';

class CustomerController extends ChangeNotifier {
  CustomerController({
    required CustomerService customerService,
    required VisitService visitService,
    required DealService dealService,
    required ReservationService reservationService,
    required CacheService cache,
  })  : _customers = customerService,
        _visits = visitService,
        _deals = dealService,
        _reservations = reservationService,
        _cache = cache;

  final CustomerService _customers;
  final VisitService _visits;
  final DealService _deals;
  final ReservationService _reservations;
  final CacheService _cache;

  static const int pageSize = 30;
  static const String _cachePrefix = 'customers';

  List<Customer> items = [];
  Customer? selected;
  List<Visit> visits = [];
  List<Deal> deals = [];
  List<HouseReservation> reservations = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  int currentPage = 0;
  int? totalCount;
  String? error;
  String _activeSearch = '';
  CustomerStatus? _activeStatus;
  DateTime? _activeFromDate;
  DateTime? _activeToDate;
  String _activeSortDir = 'desc';

  Future<void> load({
    String? search,
    CustomerStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    String sortDir = 'desc',
  }) async {
    final normalizedSearch = (search ?? '').trim();
    _activeSearch = normalizedSearch;
    _activeStatus = status;
    _activeFromDate = fromDate;
    _activeToDate = toDate;
    _activeSortDir = sortDir;
    currentPage = 1;
    hasMore = true;
    totalCount = null;
    loading = true;
    error = null;
    notifyListeners();

    final cached = _readCachedPage(page: 1, search: normalizedSearch);
    if (cached != null) {
      items = cached.items;
      hasMore = cached.hasMore;
      totalCount = cached.total;
      loading = false;
      notifyListeners();
      unawaited(_refreshFirstPageInBackground(normalizedSearch));
      return;
    }

    await _fetchPage(
      page: 1,
      search: normalizedSearch,
      replace: true,
      isPrimaryLoad: true,
    );
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();

    final nextPage = currentPage + 1;
    final cached = _readCachedPage(page: nextPage, search: _activeSearch);
    if (cached != null) {
      _mergePage(nextPage, cached.items);
      currentPage = nextPage;
      hasMore = cached.hasMore;
      totalCount = cached.total;
      loadingMore = false;
      notifyListeners();
      unawaited(_refreshPageInBackground(nextPage, _activeSearch));
      return;
    }

    await _fetchPage(
      page: nextPage,
      search: _activeSearch,
      replace: false,
      isPrimaryLoad: false,
    );
  }

  Future<void> loadAllPages() async {
    if (currentPage == 0) {
      await load(search: _activeSearch.isEmpty ? null : _activeSearch);
    }
    while (hasMore) {
      await loadMore();
    }
  }

  Future<void> _refreshFirstPageInBackground(String search) async {
    try {
      final result = await _customers.listPaged(
        search: search.isEmpty ? null : search,
        status: _activeStatus?.api,
        fromDate: _activeFromDate,
        toDate: _activeToDate,
        sortDir: _activeSortDir,
        page: 1,
        pageSize: pageSize,
      );
      final same = _jsonSignature(items.take(result.items.length).toList()) ==
          _jsonSignature(result.items);
      if (!same || currentPage == 1) {
        _mergePage(1, result.items);
        hasMore = result.hasMore;
        totalCount = result.total;
        currentPage = currentPage < 1 ? 1 : currentPage;
        notifyListeners();
      }
      await _writeCachedPage(
        page: 1,
        search: search,
        entries: result.items,
        hasMoreValue: result.hasMore,
        total: result.total,
      );
    } catch (_) {
      // Silent: keep cached view on weak or offline network.
    }
  }

  Future<void> _refreshPageInBackground(int page, String search) async {
    try {
      final result = await _customers.listPaged(
        search: search.isEmpty ? null : search,
        status: _activeStatus?.api,
        fromDate: _activeFromDate,
        toDate: _activeToDate,
        sortDir: _activeSortDir,
        page: page,
        pageSize: pageSize,
      );
      _mergePage(page, result.items);
      hasMore = result.hasMore;
      totalCount = result.total;
      notifyListeners();
      await _writeCachedPage(
        page: page,
        search: search,
        entries: result.items,
        hasMoreValue: result.hasMore,
        total: result.total,
      );
    } catch (_) {
      // Silent background refresh failure.
    }
  }

  Future<void> _fetchPage({
    required int page,
    required String search,
    required bool replace,
    required bool isPrimaryLoad,
  }) async {
    try {
      final result = await _customers.listPaged(
        search: search.isEmpty ? null : search,
        status: _activeStatus?.api,
        fromDate: _activeFromDate,
        toDate: _activeToDate,
        sortDir: _activeSortDir,
        page: page,
        pageSize: pageSize,
      );
      if (replace) {
        items = result.items;
      } else {
        _mergePage(page, result.items);
      }
      currentPage = page;
      hasMore = result.hasMore;
      totalCount = result.total;
      await _writeCachedPage(
        page: page,
        search: search,
        entries: result.items,
        hasMoreValue: result.hasMore,
        total: result.total,
      );
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'فشل تحميل الزبائن';
    } finally {
      if (isPrimaryLoad) {
        loading = false;
      } else {
        loadingMore = false;
      }
      notifyListeners();
    }
  }

  void _mergePage(int page, List<Customer> pageItems) {
    final start = (page - 1) * pageSize;
    if (start >= items.length) {
      items.addAll(pageItems);
      return;
    }
    final end = (start + pageItems.length).clamp(start, items.length);
    items.replaceRange(start, end, pageItems);
    if (end < start + pageItems.length) {
      items.addAll(pageItems.sublist(end - start));
    }
  }

  String _cacheKey({required int page, required String search}) {
    final safeSearch = Uri.encodeComponent(search);
    final status = _activeStatus?.api ?? 'all';
    final from = _activeFromDate?.toUtc().toIso8601String() ?? '';
    final to = _activeToDate?.toUtc().toIso8601String() ?? '';
    return '$_cachePrefix:search=$safeSearch:status=$status:from=$from:to=$to:sort=$_activeSortDir:page=$page:limit=$pageSize';
  }

  _CachedPage<Customer>? _readCachedPage({
    required int page,
    required String search,
  }) {
    final data = _cache.readMap(_cacheKey(page: page, search: search));
    if (data == null) return null;
    final raw = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    final parsed = <Customer>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        parsed.add(Customer.fromJson(entry));
      } else if (entry is Map) {
        parsed.add(Customer.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return _CachedPage<Customer>(
      items: parsed,
      hasMore: data['has_more'] as bool? ?? false,
      total: (data['total'] as num?)?.toInt(),
    );
  }

  Future<void> _writeCachedPage({
    required int page,
    required String search,
    required List<Customer> entries,
    required bool hasMoreValue,
    required int? total,
  }) async {
    await _cache.writeMap(_cacheKey(page: page, search: search), {
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'has_more': hasMoreValue,
      'total': total,
      'items': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _invalidateCache() async {
    await _cache.removeByPrefix(_cachePrefix);
  }

  String _jsonSignature(List<Customer> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  Future<void> openProfile(String id) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      selected = await _customers.get(id);
      visits = await _visits.byCustomer(id);
      deals = await _deals.list(customerId: id);
      reservations = await _reservations.list(customerId: id);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'فشل تحميل الملف';
    }
    loading = false;
    notifyListeners();
  }

  Future<Customer?> create(Map<String, dynamic> fields) async {
    try {
      final customer = await _customers.create(
        name: fields['name'] as String,
        phone: fields['phone'] as String,
        email: fields['email'] as String?,
        gender: fields['gender'] as CustomerGender?,
        profession: fields['profession'] as String?,
        address: fields['address'] as String?,
        howKnew: fields['howKnew'] as HowKnewCenter?,
        referralBuyerName: fields['referralBuyerName'] as String?,
        salesEmployeeId: fields['salesEmployeeId'] as String?,
        notes: fields['notes'] as String?,
        status: fields['status'] as CustomerStatus?,
      );
      items.insert(0, customer);
      unawaited(_invalidateCache());
      notifyListeners();
      return customer;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateSelected(Map<String, dynamic> fields) async {
    if (selected == null) return false;
    try {
      selected = await _customers.update(
        selected!.id,
        name: fields['name'] as String?,
        profession: fields['profession'] as String?,
        address: fields['address'] as String?,
        phone: fields['phone'] as String?,
        email: fields['email'] as String?,
        gender: fields['gender'] as CustomerGender?,
        howKnew: fields['howKnew'],
        referralBuyerName: fields['referralBuyerName'] as String?,
        salesEmployeeId: fields['salesEmployeeId'] as String?,
        notes: fields['notes'] as String?,
        status: fields['status'] as CustomerStatus?,
      );
      final i = items.indexWhere((c) => c.id == selected!.id);
      if (i >= 0) items[i] = selected!;
      unawaited(_invalidateCache());
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addVisit({String? notes}) async {
    if (selected == null) return false;
    try {
      final visit = await _visits.create(customerId: selected!.id, notes: notes);
      visits.insert(0, visit);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateVisit({required String visitId, String? notes}) async {
    try {
      final visit = await _visits.update(visitId: visitId, notes: notes);
      final i = visits.indexWhere((v) => v.id == visitId);
      if (i >= 0) {
        visits[i] = visit;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addDeal(Map<String, dynamic> body) async {
    try {
      final deal = await _deals.create(body);
      deals.insert(0, deal);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDeal(String dealId, Map<String, dynamic> body) async {
    try {
      final updated = await _deals.update(dealId, body);
      final idx = deals.indexWhere((d) => d.id == dealId);
      if (idx >= 0) {
        deals[idx] = updated;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addReservation({
    required String name,
    required double houseArea,
    required String residentialBlock,
    required String houseNumber,
    required double totalPrice,
    required dynamic paymentType,
    required double downPayment,
    required DateTime completionDeadline,
    String? notes,
    String? salesEmployeeId,
  }) async {
    if (selected == null) return false;
    try {
      final reservation = await _reservations.create(
        customerId: selected!.id,
        name: name,
        houseArea: houseArea,
        residentialBlock: residentialBlock,
        houseNumber: houseNumber,
        totalPrice: totalPrice,
        paymentType: paymentType,
        downPayment: downPayment,
        completionDeadline: completionDeadline,
        notes: notes,
        salesEmployeeId: salesEmployeeId,
      );
      reservations.insert(0, reservation);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadDocument(String path, String filename, {String? notes}) async {
    if (selected == null) return false;
    try {
      await _customers.uploadDocument(selected!.id, path, filename, notes: notes);
      selected = await _customers.get(selected!.id);
      unawaited(_invalidateCache());
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }
}

class _CachedPage<T> {
  const _CachedPage({
    required this.items,
    required this.hasMore,
    required this.total,
  });

  final List<T> items;
  final bool hasMore;
  final int? total;
}
