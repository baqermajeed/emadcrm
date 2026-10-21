from enum import StrEnum


class UserRole(StrEnum):
    CALL_CENTER = "call_center"
    RECEPTION = "reception"
    SALES = "sales"
    MANAGER = "manager"


class BookingSource(StrEnum):
    WHATSAPP = "whatsapp"
    INSTAGRAM = "instagram"
    FACEBOOK = "facebook"
    TIKTOK = "tiktok"
    PHONE = "phone"
    EXTERNAL_AD = "external_ad"


class BookingStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    CANCELLED = "cancelled"
    NO_SHOW = "no_show"


class VisitType(StrEnum):
    FIRST = "first"
    FOLLOW_UP = "follow_up"


class HowKnewCenter(StrEnum):
    EXTERNAL_ADS = "external_ads"
    SOCIAL_MEDIA = "social_media"
    BUYER_REFERRAL = "buyer_referral"
    PASSING_BY = "passing_by"


class CustomerGender(StrEnum):
    MALE = "male"
    FEMALE = "female"


class CustomerStatus(StrEnum):
    BUYER = "buyer"
    POTENTIAL = "potential"
    RESERVATION = "reservation"
    HESITANT = "hesitant"
    NOT_INTERESTED = "not_interested"
    INTERESTED = "interested"


class PaymentType(StrEnum):
    CASH = "cash"
    HALF_CASH = "half_cash"
    INSTALLMENTS = "installments"


class HouseType(StrEnum):
    HOUSE = "house"
    VILLA = "villa"


class DealStatus(StrEnum):
    COMPLETED = "completed"


class ReservationStatus(StrEnum):
    ACTIVE = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
