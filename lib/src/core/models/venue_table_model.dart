import 'package:flutter/material.dart';

class PromoSlide {
  final String type;
  final String url;
  final String? poster;
  final String title;
  final String subtitle;

  const PromoSlide({
    required this.type,
    required this.url,
    this.poster,
    this.title = '',
    this.subtitle = '',
  });

  bool get isVideo => type == 'video';

  factory PromoSlide.fromJson(Map<String, dynamic> json) {
    return PromoSlide(
      type: json['type']?.toString() == 'video' ? 'video' : 'image',
      url: json['url']?.toString() ?? '',
      poster: json['poster']?.toString(),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        'poster': poster,
        'title': title,
        'subtitle': subtitle,
      };
}

class VenueCampaign {
  final String id;
  final String title;
  final String description;
  final String discountType;
  final double discountValue;

  const VenueCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
  });

  factory VenueCampaign.fromJson(Map<String, dynamic> json) {
    return VenueCampaign(
      id: json['campaign_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Özel İndirim',
      description: json['description']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? 'percentage',
      discountValue: double.tryParse(json['discount_value']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class VenueTableModel {
  final String venueId;
  final String venueName;
  final String address;
  final String? bannerUrl;
  final String? logoUrl;
  final String? welcomeVideoUrl;
  final List<PromoSlide> promoSlides;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final String? announcementText;
  final String tableId;
  final String tableName;
  final String zoneName;
  final int guestCount;
  final String wifiSsid;
  final String wifiPassword;
  final bool showWifi;
  final String workingHours;
  final String statusText;
  final String assignedWaiter;
  final List<VenueCampaign> campaigns;
  final int adultCount;
  final int childCount;
  final int babyCount;
  final String? lockedTenantId;
  final String? lockedVenueName;

  // White-label dynamic attributes
  final String primaryColorHex;
  final String accentColorHex;
  final double rating;
  final int reviewCount;
  final String cuisineType;
  final List<String> amenities;

  const VenueTableModel({
    required this.venueId,
    required this.venueName,
    required this.address,
    this.bannerUrl,
    this.logoUrl,
    this.welcomeVideoUrl,
    this.promoSlides = const [],
    this.welcomeTitle = 'Hoş Geldiniz!',
    this.welcomeSubtitle = 'Siparişlerinizi doğrudan mutfağımıza iletebilirsiniz.',
    this.announcementText,
    required this.tableId,
    required this.tableName,
    required this.zoneName,
    this.guestCount = 2,
    this.adultCount = 2,
    this.childCount = 0,
    this.babyCount = 0,
    this.lockedTenantId,
    this.lockedVenueName,
    required this.wifiSsid,
    required this.wifiPassword,
    this.showWifi = true,
    required this.workingHours,
    required this.statusText,
    required this.assignedWaiter,
    this.campaigns = const [],
    this.primaryColorHex = '#6366F1',
    this.accentColorHex = '#06B6D4',
    this.rating = 4.9,
    this.reviewCount = 1240,
    this.cuisineType = 'Gurme Restoran & Cafe',
    this.amenities = const ['Hızlı Wi-Fi', 'Vale & Otopark', 'Açık Teras', 'Nargile', 'Masada Ödeme'],
  });

  bool get isSeated => tableId.isNotEmpty && tableId != 'unseated';

  Color get brandPrimaryColor {
    try {
      final hex = primaryColorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  Color get brandAccentColor {
    try {
      final hex = accentColorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (_) {}
    return const Color(0xFF06B6D4);
  }

  factory VenueTableModel.initial() {
    return const VenueTableModel(
      venueId: '',
      venueName: '',
      address: '',
      bannerUrl: null,
      logoUrl: null,
      welcomeVideoUrl: null,
      promoSlides: [],
      welcomeTitle: 'Hoş Geldiniz!',
      welcomeSubtitle: '',
      announcementText: null,
      tableId: '',
      tableName: '',
      zoneName: '',
      guestCount: 2,
      adultCount: 2,
      childCount: 0,
      babyCount: 0,
      lockedTenantId: null,
      lockedVenueName: null,
      wifiSsid: '',
      wifiPassword: '',
      showWifi: false,
      workingHours: '',
      statusText: '',
      assignedWaiter: 'Masa Servis Görevlisi',
      campaigns: [],
      primaryColorHex: '#6366F1',
      accentColorHex: '#06B6D4',
      rating: 0.0,
      reviewCount: 0,
      cuisineType: '',
      amenities: [],
    );
  }

  factory VenueTableModel.fromJson(Map<String, dynamic> json) {
    var rawCamp = json['campaigns'];
    List<VenueCampaign> campList = [];
    if (rawCamp is List) {
      campList = rawCamp.map((c) => VenueCampaign.fromJson(c as Map<String, dynamic>)).toList();
    }

    final adults = int.tryParse(json['adult_count']?.toString() ?? '2') ?? 2;
    final children = int.tryParse(json['child_count']?.toString() ?? '0') ?? 0;
    final babies = int.tryParse(json['baby_count']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(json['guest_count']?.toString() ?? '${adults + children + babies}') ?? (adults + children + babies);

    List<String> parsedAmenities = const [];
    if (json['amenities'] is List) {
      parsedAmenities = (json['amenities'] as List).map((e) => e.toString()).toList();
    }

    return VenueTableModel(
      venueId: json['venue_id']?.toString() ?? json['tenant_id']?.toString() ?? '',
      venueName: json['venue_name']?.toString() ?? json['company_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      bannerUrl: json['banner_url']?.toString() ?? json['cover_image']?.toString(),
      logoUrl: json['logo_url']?.toString() ?? json['logo_path']?.toString(),
      welcomeVideoUrl: json['welcome_video_url']?.toString(),
      promoSlides: (json['promo_slides'] is List)
          ? (json['promo_slides'] as List)
              .whereType<Map>()
              .map((e) => PromoSlide.fromJson(Map<String, dynamic>.from(e)))
              .where((s) => s.url.isNotEmpty)
              .toList()
          : const [],
      welcomeTitle: json['welcome_title']?.toString() ?? 'Hoş Geldiniz!',
      welcomeSubtitle: json['welcome_subtitle']?.toString() ?? '',
      announcementText: json['announcement_text']?.toString(),
      tableId: json['table_id']?.toString() ?? '',
      tableName: json['table_name']?.toString() ?? json['name']?.toString() ?? (json['table_id'] != null && json['table_id'] != '' ? 'Masa' : 'Masa Seçilmedi'),
      zoneName: json['zone_name']?.toString() ?? '',
      guestCount: total,
      adultCount: adults,
      childCount: children,
      babyCount: babies,
      lockedTenantId: json['locked_tenant_id']?.toString(),
      lockedVenueName: json['locked_venue_name']?.toString(),
      wifiSsid: json['wifi_ssid']?.toString() ?? '',
      wifiPassword: json['wifi_password']?.toString() ?? '',
      showWifi: json['show_wifi'] != false,
      workingHours: json['working_hours']?.toString() ?? '',
      statusText: json['status_text']?.toString() ?? '',
      assignedWaiter: json['assigned_waiter']?.toString() ?? 'Masa Servis Görevlisi',
      campaigns: campList,
      primaryColorHex: json['primary_color']?.toString() ?? json['primaryColorHex']?.toString() ?? '#6366F1',
      accentColorHex: json['accent_color']?.toString() ?? json['accentColorHex']?.toString() ?? '#06B6D4',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      reviewCount: int.tryParse(json['review_count']?.toString() ?? json['reviewCount']?.toString() ?? '0') ?? 0,
      cuisineType: json['cuisine_type']?.toString() ?? json['cuisineType']?.toString() ?? '',
      amenities: parsedAmenities,
    );
  }

  Map<String, dynamic> toJson() => {
    'venue_id': venueId,
    'venue_name': venueName,
    'address': address,
    'banner_url': bannerUrl,
    'logo_url': logoUrl,
    'welcome_video_url': welcomeVideoUrl,
    'promo_slides': promoSlides.map((e) => e.toJson()).toList(),
    'welcome_title': welcomeTitle,
    'welcome_subtitle': welcomeSubtitle,
    'announcement_text': announcementText,
    'table_id': tableId,
    'table_name': tableName,
    'zone_name': zoneName,
    'guest_count': guestCount,
    'adult_count': adultCount,
    'child_count': childCount,
    'baby_count': babyCount,
    'locked_tenant_id': lockedTenantId,
    'locked_venue_name': lockedVenueName,
    'wifi_ssid': wifiSsid,
    'wifi_password': wifiPassword,
    'show_wifi': showWifi,
    'working_hours': workingHours,
    'status_text': statusText,
    'assigned_waiter': assignedWaiter,
    'primary_color': primaryColorHex,
    'accent_color': accentColorHex,
    'rating': rating,
    'review_count': reviewCount,
    'cuisine_type': cuisineType,
    'amenities': amenities,
  };
}
