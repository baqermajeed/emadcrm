import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/cache_service.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../utils/enums.dart';

class BookingController extends ChangeNotifier {
  BookingController(this._service, {required CacheService cache}) : _cache = cache;

  final BookingService _service;
  final CacheService _cache;

  static const int pageSize = 30;
  static const String _cachePrefix = 'bookings';

  List<Booking> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  int currentPage = 0;
  int? totalCount;
  String? error;
  BookingStatus? _activeStatus;
  String _activeSearch = '';
  DateTime? _activeFromDate;
  DateTime? _activeToDate;
  String? _activeCallCenterId;
  String? _activeSalesEmployeeId;
  String _activeSortDir = 'desc';

  Future<void> load({
    BookingStatus? status,
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? callCenterId,
    String? salesEmployeeId,
    String sortDir = 'desc',
  }) async {
    _activeStatus = status;
    _activeSearch = (search ?? '').trim();
    _activeFromDate = fromDate;
    _activeToDate = toDate;
    _activeCallCenterId = callCenterId;
    _activeSalesEmployeeId = salesEmployeeId;
    _activeSortDir = sortDir;
    currentPage = 1;
    hasMore = true;
    totalCount = null;
    loading = true;
    error = null;
    notifyListeners();

    final cached = _readCachedPage(
      page: 1,
      status: status,
      search: _activeSearch,
    );
    if (cached != null) {
      items = cached.items;
      hasMore = cached.hasMore;
      totalCount = cached.total;
      loading = false;
      notifyListeners();
      unawaited(_refreshFirstPageInBackground(status, _activeSearch));
      return;
    }

    await _fetchPage(
      page: 1,
      status: status,
      search: _activeSearch,
      replace: true,
      primary: true,
    );
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    final nextPage = currentPage + 1;

    final cached = _readCachedPage(
      page: nextPage,
      status: _activeStatus,
      search: _activeSearch,
    );
    if (cached != null) {
      _mergePage(nextPage, cached.items);
      currentPage = nextPage;
      hasMore = cached.hasMore;
      totalCount = cached.total;
      loadingMore = false;
      notifyListeners();
      unawaited(_refreshPageInBackground(nextPage, _activeStatus, _activeSearch));
      return;
    }

    await _fetchPage(
      page: nextPage,
      status: _activeStatus,
      search: _activeSearch,
      replace: false,
      primary: false,
    );
  }

  Future<void> _refreshFirstPageInBackground(
    BookingStatus? status,
    String search,
  ) async {
    try {
      final result = await _service.listPaged(
        status: status,
        search: search.isEmpty ? null : search,
        fromDate: _activeFromDate,
        toDate: _activeToDate,
        callCenterId: _activeCallCenterId,
        salesEmployeeId: _activeSalesEmployeeId,
        sortDir: _activeSortDir,
        page: 1,
        pageSize: pageSize,
      );
      _mergePage(1, result.items);
      hasMore = result.hasMore;
      totalCount = result.total;
      notifyListeners();
      await _writeCachedPage(
        page: 1,
        status: status,
        search: search,
        entries: result.items,
        hasMoreValue: result.hasMore,
        total: result.total,
      );
    } catch (_) {
      // keep cached page
    }
  }

  Future<void> _refreshPageInBackground(
    int page,
    BookingStatus? status,
    String search,
  ) async {
    try {
      final result = await _service.listPaged(
        status: status,
        search: search.isEmpty ? null : search,
        fromDate: _activeFromDate,
        toDate: _activeToDate,
        callCenterId: _activeCallCenterId,
        salesEmployeeId: _activeSalesEmployeeId,
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
        status: status,
        search: search,
        entries: result.items,
        hasMoreValue: result.hasMore,
        total: result.total,
      );
    } catch (_) {
      // silent
    }
  }

  Future<void> _fetchPage({
    required int page,
    required BookingStatus? status,
    required String search,
    required bool replace,
    required bool primary,
  }) async {
    try {
      final result = await _service.listPaged(
        status: status,
        search: search.isEmpty ? null : search,
        fromDate: _activeFromDate,
        toDate: _activeToDate,
        callCenterId: _activeCallCenterId,
        salesEmployeeId: _activeSalesEmployeeId,
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
        status: status,
        search: search,
        entries: result.items,
        hasMoreValue: result.hasMore,
        total: result.total,
      );
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'فشل تحميل الحجوزات';
    } finally {
      if (primary) {
        loading = false;
      } else {
        loadingMore = false;
      }
      notifyListeners();
    }
  }

  void _mergePage(int page, List<Booking> pageItems) {
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

  String _cacheKey({
    required int page,
    required BookingStatus? status,
    required String search,
  }) {
    final value = status?.api ?? 'all';
    final from = _activeFromDate?.toUtc().toIso8601String() ?? '';
    final to = _activeToDate?.toUtc().toIso8601String() ?? '';
    final callCenter = _activeCallCenterId ?? '';
    final sales = _activeSalesEmployeeId ?? '';
    final safeSearch = Uri.encodeComponent(search);
    return '$_cachePrefix:status=$value:search=$safeSearch:from=$from:to=$to:cc=$callCenter:sales=$sales:sort=$_activeSortDir:page=$page:limit=$pageSize';
  }

  _CachedBookingPage? _readCachedPage({
    required int page,
    required BookingStatus? status,
    required String search,
  }) {
    final data = _cache.readMap(
      _cacheKey(page: page, status: status, search: search),
    );
    if (data == null) return null;
    final raw = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    final parsed = <Booking>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        parsed.add(Booking.fromJson(entry));
      } else if (entry is Map) {
        parsed.add(Booking.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return _CachedBookingPage(
      items: parsed,
      hasMore: data['has_more'] as bool? ?? false,
      total: (data['total'] as num?)?.toInt(),
    );
  }

  Future<void> _writeCachedPage({
    required int page,
    required BookingStatus? status,
    required String search,
    required List<Booking> entries,
    required bool hasMoreValue,
    required int? total,
  }) async {
    await _cache.writeMap(
      _cacheKey(page: page, status: status, search: search),
      {
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'has_more': hasMoreValue,
      'total': total,
      'items': entries.map((e) => e.toJson()).toList(),
      },
    );
  }

  Future<void> _invalidateCache() async {
    await _cache.removeByPrefix(_cachePrefix);
  }

  Future<bool> create({
    required String name,
    required String phone,
    required String governorate,
    required BookingSource source,
    required DateTime visitDate,
    String? notes,
  }) async {
    try {
      final created = await _service.create(
        name: name,
        phone: phone,
        governorate: governorate,
        source: source,
        visitDate: visitDate,
        notes: notes,
      );
      items.insert(0, created);
      unawaited(_invalidateCache());
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approve({
    required String bookingId,
    required String salesEmployeeId,
    VisitType? visitType,
    String? existingCustomerId,
    String? profession,
    String? address,
    HowKnewCenter? howKnew,
    String? referralBuyerName,
    String? notes,
  }) async {
    try {
      final updated = await _service.approve(
        bookingId: bookingId,
        salesEmployeeId: salesEmployeeId,
        visitType: visitType,
        existingCustomerId: existingCustomerId,
        profession: profession,
        address: address,
        howKnew: howKnew,
        referralBuyerName: referralBuyerName,
        notes: notes,
      );
      final index = items.indexWhere((b) => b.id == bookingId);
      if (index >= 0) items[index] = updated;
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

class _CachedBookingPage {
  const _CachedBookingPage({
    required this.items,
    required this.hasMore,
    required this.total,
  });

  final List<Booking> items;
  final bool hasMore;
  final int? total;
}
