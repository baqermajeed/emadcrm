import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
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
  })  : _customers = customerService,
        _visits = visitService,
        _deals = dealService,
        _reservations = reservationService;

  final CustomerService _customers;
  final VisitService _visits;
  final DealService _deals;
  final ReservationService _reservations;

  List<Customer> items = [];
  Customer? selected;
  List<Visit> visits = [];
  List<Deal> deals = [];
  List<HouseReservation> reservations = [];
  bool loading = false;
  String? error;

  Future<void> load({String? search}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _customers.list(search: search);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'فشل تحميل الزبائن';
    }
    loading = false;
    notifyListeners();
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
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }
}
