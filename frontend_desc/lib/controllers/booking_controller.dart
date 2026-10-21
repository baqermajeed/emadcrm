import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../utils/enums.dart';

class BookingController extends ChangeNotifier {
  BookingController(this._service);

  final BookingService _service;

  List<Booking> items = [];
  bool loading = false;
  String? error;

  Future<void> load({BookingStatus? status}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _service.list(status: status);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'فشل تحميل الحجوزات';
    }
    loading = false;
    notifyListeners();
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
        profession: profession,
        address: address,
        howKnew: howKnew,
        referralBuyerName: referralBuyerName,
        notes: notes,
      );
      final index = items.indexWhere((b) => b.id == bookingId);
      if (index >= 0) items[index] = updated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }
}
