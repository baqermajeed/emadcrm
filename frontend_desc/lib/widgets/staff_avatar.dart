import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/reception_tokens.dart';
import '../models/user.dart';

/// Employee avatar: network photo if available, otherwise a person icon.
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({
    super.key,
    this.avatarUrl,
    this.user,
    this.radius = 22,
    this.backgroundColor = ReceptionTokens.plusBg,
    this.iconColor = ReceptionTokens.navy,
  });

  /// Relative (`/uploads/...`) or absolute URL.
  final String? avatarUrl;

  /// Convenience: uses [AppUser.avatarUrl] when set.
  final AppUser? user;

  final double radius;
  final Color backgroundColor;
  final Color iconColor;

  static String? resolveUrl(String? url) {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = AppConstants.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base$raw';
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveUrl(avatarUrl ?? user?.avatarUrl);
    final size = radius * 2;
    // Oversample for sharp display on high-DPI / Windows scaling.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr * 2).round().clamp(96, 512);

    if (url == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Icon(Icons.person_rounded, size: radius * 1.15, color: iconColor),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        memCacheWidth: cachePx,
        memCacheHeight: cachePx,
        maxWidthDiskCache: 512,
        maxHeightDiskCache: 512,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: backgroundColor,
          alignment: Alignment.center,
          child: SizedBox(
            width: radius * 0.7,
            height: radius * 0.7,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: iconColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: backgroundColor,
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded, size: radius * 1.15, color: iconColor),
        ),
      ),
    );
  }
}
