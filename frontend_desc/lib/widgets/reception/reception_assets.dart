import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Assets exported from Figma Desktop-31 (node 31:6256).
class RAssets {
  static const _img = 'assets/reception/v2/img';
  static const _svg = 'assets/reception/v2/svg';
  static const _sources = 'assets/reception/sources';
  static const _status = 'assets/reception/status';
  static const _profile = 'assets/reception/profile';

  static const avatar = '$_img/avatar.png';
  static const attendedIcon = '$_status/attended.png';
  static const pendingIcon = '$_status/pending.png';
  static const confirmAttendanceIcon = '$_status/confirm_attendance.png';
  static const viewProfileIcon = '$_status/view_profile.png';
  static const bookingSourceIcon = '$_status/booking_source.png';
  static const bookingDateIcon = '$_status/booking_date.png';
  static const bookingNotesIcon = '$_status/booking_notes.png';
  static const banner = '$_img/banner.png';
  static const bannerFrame = '$_img/banner_frame.png';
  static const homeBanner =
      'asset/Golden-Hour Modern Villa Boulevard.png';
  static const callCenterSidebar =
      'asset/Luxury Villas at Twilight.png';
  static const receptionSidebar =
      'asset/icon profile/Cinematic Blue Hour Luxury Villas.png';
  static const customerFilesIcon =
      'asset/icon profile/zbonprof.png';
  static const calendarStat = '$_img/calendar_stat.png';
  static const statIcon = '$_img/stat_icon.png';
  static const amad = '$_img/amad.png';
  static const logoTrans = '$_img/logo_trans.png';
  static const agreement = '$_img/agreement.png';

  static const profilePhone = '$_profile/callphone.png';
  static const profileEmail = '$_profile/email.png';
  static const profileJob = '$_profile/job_security.png';
  static const profileLocation = '$_profile/location_pin.png';
  static const avatarMale = '$_profile/avatar_male.png';
  static const avatarFemale = '$_profile/avatar_female.png';

  static const _prof = 'assets/prof';
  static const statVisits = '$_prof/visits.png';
  static const statReservations = '$_prof/hjzdar.png';
  static const statDeals = '$_prof/deals.png';
  static const statLastVisit = '$_prof/lastvisit.png';
  static const statStatus = '$_prof/stat.png';
  static const profileName = '$_prof/stat.png';
  static const profileShare = '$_prof/share.png';
  static const propertyVilla = '$_prof/Luxury Modern Villa Street.png';
  static const dealVilla = '$_prof/Modern Villa Under a Blue Sky.png';
  static const customerCardVilla = '$_prof/Modern Villa Row Under Palm Trees.png';
  static const visitsLogVilla =
      '$_prof/Modern Villa with Palm-Lined Landscaping (1).png';
  static const salesDealVilla =
      'asset/Modern Villa with Reflecting Pool and SUV.png';
  static const cardPhone = 'asset/icon profile/caalll.png';
  static const callPhoneIcon = 'asset/icon profile/Callkkk.png';
  static const cardAddress = '$_prof/hjzdar.png';
  static const cardDate = '$_prof/lastvisit.png';

  /// Decodes at device pixel ratio so 30×30 icons stay sharp on HiDPI screens.
  static Widget profileIcon(String asset, {double size = 30}) {
    return Builder(
      builder: (context) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final px = (size * dpr).round().clamp(48, 256);
        return Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          cacheWidth: px,
          cacheHeight: px,
        );
      },
    );
  }

  static Widget svg(
    String name, {
    double? w,
    double? h,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgPicture.asset(
      '$_svg/$name.svg',
      width: w,
      height: h,
      fit: fit,
      colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Booking-source icons (واتساب / فيسبوك / اتصال / تيك توك / انستغرام / اعلان خارجي).
  static Widget source(String api, {double size = 24}) {
    final file = switch (api) {
      'whatsapp' => 'whatsapp.png',
      'facebook' => 'facebook.png',
      'phone' => 'phone.png',
      'tiktok' => 'tiktok.png',
      'instagram' => 'instagram.png',
      'external_ad' => 'external_ad.png',
      _ => 'phone.png',
    };
    return Image.asset(
      '$_sources/$file',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
