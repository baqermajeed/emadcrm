enum UserRole { callCenter, reception, sales, manager }

enum BookingSource { whatsapp, instagram, facebook, tiktok, phone, externalAd }

enum BookingStatus { pending, approved, cancelled, noShow }

enum VisitType { first, followUp }

enum HowKnewCenter { externalAds, socialMedia, buyerReferral, passingBy }

enum CustomerGender { male, female }

enum CustomerStatus { buyer, potential, reservation, hesitant, notInterested, interested }

enum PaymentType { cash, halfCash, installments }

enum HouseType { house, villa }

enum DealStatus { completed }

enum ReservationStatus { active, completed, cancelled, expired }

extension UserRoleX on UserRole {
  String get api => switch (this) {
        UserRole.callCenter => 'call_center',
        UserRole.reception => 'reception',
        UserRole.sales => 'sales',
        UserRole.manager => 'manager',
      };

  String get label => switch (this) {
        UserRole.callCenter => 'كول سنتر',
        UserRole.reception => 'استقبال',
        UserRole.sales => 'مبيعات',
        UserRole.manager => 'مدير',
      };

  static UserRole fromApi(String value) => switch (value) {
        'call_center' => UserRole.callCenter,
        'reception' => UserRole.reception,
        'sales' => UserRole.sales,
        'manager' => UserRole.manager,
        _ => UserRole.callCenter,
      };
}

extension BookingSourceX on BookingSource {
  String get api => switch (this) {
        BookingSource.whatsapp => 'whatsapp',
        BookingSource.instagram => 'instagram',
        BookingSource.facebook => 'facebook',
        BookingSource.tiktok => 'tiktok',
        BookingSource.phone => 'phone',
        BookingSource.externalAd => 'external_ad',
      };

  String get label => switch (this) {
        BookingSource.whatsapp => 'واتساب',
        BookingSource.instagram => 'انستغرام',
        BookingSource.facebook => 'فيسبوك',
        BookingSource.tiktok => 'تيك توك',
        BookingSource.phone => 'اتصال هاتف',
        BookingSource.externalAd => 'اعلان خارجي',
      };

  static BookingSource fromApi(String value) => switch (value) {
        'whatsapp' => BookingSource.whatsapp,
        'instagram' => BookingSource.instagram,
        'facebook' => BookingSource.facebook,
        'tiktok' => BookingSource.tiktok,
        'external_ad' => BookingSource.externalAd,
        _ => BookingSource.phone,
      };
}

extension BookingStatusX on BookingStatus {
  String get api => switch (this) {
        BookingStatus.pending => 'pending',
        BookingStatus.approved => 'approved',
        BookingStatus.cancelled => 'cancelled',
        BookingStatus.noShow => 'no_show',
      };

  String get label => switch (this) {
        BookingStatus.pending => 'لم يحضر بعد',
        BookingStatus.approved => 'حضر',
        BookingStatus.cancelled => 'ملغي',
        BookingStatus.noShow => 'لم يحضر',
      };

  static BookingStatus fromApi(String value) => switch (value) {
        'approved' => BookingStatus.approved,
        'cancelled' => BookingStatus.cancelled,
        'no_show' => BookingStatus.noShow,
        _ => BookingStatus.pending,
      };
}

extension VisitTypeX on VisitType {
  String get api => switch (this) {
        VisitType.first => 'first',
        VisitType.followUp => 'follow_up',
      };

  String get label => switch (this) {
        VisitType.first => 'زيارة أولى',
        VisitType.followUp => 'زيارة متابعة',
      };

  static VisitType? fromApi(String? value) {
    if (value == null) return null;
    return switch (value) {
      'first' => VisitType.first,
      'follow_up' => VisitType.followUp,
      _ => null,
    };
  }
}

extension HowKnewX on HowKnewCenter {
  String get api => switch (this) {
        HowKnewCenter.externalAds => 'external_ads',
        HowKnewCenter.socialMedia => 'social_media',
        HowKnewCenter.buyerReferral => 'buyer_referral',
        HowKnewCenter.passingBy => 'passing_by',
      };

  String get label => switch (this) {
        HowKnewCenter.externalAds => 'إعلانات خارجية',
        HowKnewCenter.socialMedia => 'مواقع التواصل',
        HowKnewCenter.buyerReferral => 'عن طريق مشتري',
        HowKnewCenter.passingBy => 'المرور قرب الشركة',
      };

  static HowKnewCenter? fromApi(String? value) {
    if (value == null) return null;
    return switch (value) {
      'external_ads' => HowKnewCenter.externalAds,
      'social_media' => HowKnewCenter.socialMedia,
      'buyer_referral' => HowKnewCenter.buyerReferral,
      'passing_by' => HowKnewCenter.passingBy,
      _ => null,
    };
  }
}

extension CustomerGenderX on CustomerGender {
  String get api => switch (this) {
        CustomerGender.male => 'male',
        CustomerGender.female => 'female',
      };

  String get label => switch (this) {
        CustomerGender.male => 'ذكر',
        CustomerGender.female => 'أنثى',
      };

  static CustomerGender fromApi(String? value) => switch (value) {
        'female' => CustomerGender.female,
        _ => CustomerGender.male,
      };
}

extension CustomerStatusX on CustomerStatus {
  String get api => switch (this) {
        CustomerStatus.buyer => 'buyer',
        CustomerStatus.potential => 'potential',
        CustomerStatus.reservation => 'reservation',
        CustomerStatus.hesitant => 'hesitant',
        CustomerStatus.notInterested => 'not_interested',
        CustomerStatus.interested => 'interested',
      };

  String get label => switch (this) {
        CustomerStatus.buyer => 'مشتري',
        CustomerStatus.potential => 'محتمل',
        CustomerStatus.reservation => 'حجز',
        CustomerStatus.hesitant => 'متردد',
        CustomerStatus.notInterested => 'غير مهتم',
        CustomerStatus.interested => 'مهتم',
      };

  static CustomerStatus fromApi(String? value) => switch (value) {
        'buyer' => CustomerStatus.buyer,
        'reservation' => CustomerStatus.reservation,
        'hesitant' => CustomerStatus.hesitant,
        'not_interested' => CustomerStatus.notInterested,
        'interested' => CustomerStatus.interested,
        'potential' => CustomerStatus.potential,
        _ => CustomerStatus.potential,
      };
}

extension PaymentTypeX on PaymentType {
  String get api => switch (this) {
        PaymentType.cash => 'cash',
        PaymentType.halfCash => 'half_cash',
        PaymentType.installments => 'installments',
      };

  String get label => switch (this) {
        PaymentType.cash => 'كاش',
        PaymentType.halfCash => 'نصف كاش',
        PaymentType.installments => 'دفعات',
      };

  static PaymentType fromApi(String value) => switch (value) {
        'half_cash' => PaymentType.halfCash,
        'installments' => PaymentType.installments,
        _ => PaymentType.cash,
      };
}

extension HouseTypeX on HouseType {
  String get api => switch (this) {
        HouseType.house => 'house',
        HouseType.villa => 'villa',
      };

  String get label => switch (this) {
        HouseType.house => 'دار',
        HouseType.villa => 'فيلا',
      };

  static HouseType fromApi(String? value) => switch (value) {
        'villa' => HouseType.villa,
        _ => HouseType.house,
      };
}

extension DealStatusX on DealStatus {
  String get api => 'completed';

  String get label => 'مكتملة';

  static DealStatus fromApi(String? value) => DealStatus.completed;
}

extension ReservationStatusX on ReservationStatus {
  String get api => name;
  String get label => switch (this) {
        ReservationStatus.active => 'فعّال',
        ReservationStatus.completed => 'مكتمل',
        ReservationStatus.cancelled => 'ملغي',
        ReservationStatus.expired => 'منتهي',
      };

  static ReservationStatus fromApi(String value) => switch (value) {
        'completed' => ReservationStatus.completed,
        'cancelled' => ReservationStatus.cancelled,
        'expired' => ReservationStatus.expired,
        _ => ReservationStatus.active,
      };
}
