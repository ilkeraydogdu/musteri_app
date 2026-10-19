import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/venue_table_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/location_helper.dart';

final tableSessionProvider = StateNotifierProvider<TableSessionNotifier, VenueTableModel>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TableSessionNotifier(apiClient);
});

class TableSessionNotifier extends StateNotifier<VenueTableModel> {
  final ApiClient _apiClient;
  Timer? _venueSyncTimer;
  bool _isSyncingVenue = false;

  TableSessionNotifier(this._apiClient) : super(VenueTableModel.initial()) {
    final packaged = ApiConstants.packagedTenantId;
    if (packaged.isNotEmpty) {
      state = state.copyWith(
        lockedTenantId: packaged,
        venueId: packaged,
      );
    }
    _loadFromStorageAndFetchVenue();
    _startRealtimeVenueSync();
  }

  void _startRealtimeVenueSync() {
    _venueSyncTimer?.cancel();
    _venueSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_isSyncingVenue) {
        fetchLiveVenueInfo();
      }
    });
  }

  @override
  void dispose() {
    _venueSyncTimer?.cancel();
    super.dispose();
  }

  String _nonEmpty(dynamic value, String fallback) {
    final s = value?.toString().trim() ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  Future<void> _loadFromStorageAndFetchVenue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ApiConstants.keySavedVenueTable);
      if (raw != null) {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          var saved = VenueTableModel.fromJson(map);
          // Oturum geçerlilik kontrolü: 2 saatten eski veya bugüne ait olmayan masa oturumunu otomatik sıfırla
          final seatedTs = prefs.getInt('qordy_seated_timestamp');
          final isExpired = seatedTs == null ||
              DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(seatedTs)).inHours >= 2;
          if (isExpired && saved.isSeated) {
            saved = saved.copyWith(tableId: '', tableName: '', zoneName: '');
            await prefs.remove(ApiConstants.keyTableId);
            await prefs.remove(ApiConstants.keyTableName);
            await prefs.remove('qordy_seated_timestamp');
          }
          final packaged = ApiConstants.packagedTenantId;
          state = packaged.isEmpty
              ? saved
              : saved.copyWith(lockedTenantId: packaged, venueId: packaged);
        }
      } else {
        final lockedId = prefs.getString(ApiConstants.keyLockedTenantId);
        final lockedName = prefs.getString(ApiConstants.keyLockedVenueName);
        if (lockedId != null) {
          state = state.copyWith(lockedTenantId: lockedId, lockedVenueName: lockedName);
        }
      }
    } catch (e, st) {
      debugPrint('TableSessionProvider: Error loading from storage: $e\n$st');
    }

    // Fetch latest live venue settings from backend
    await fetchLiveVenueInfo(tenantId: state.lockedTenantId ?? state.venueId);
  }

  Future<void> fetchLiveVenueInfo({String? tenantId}) async {
    if (_isSyncingVenue) return;
    _isSyncingVenue = true;
    try {
      final query = <String, dynamic>{};
      final targetTenant = tenantId ?? state.lockedTenantId ?? state.venueId;
      if (targetTenant.isNotEmpty) {
        query['tenant_id'] = targetTenant;
      }
      if (state.tableId.isNotEmpty) {
        query['table_id'] = state.tableId;
      }

      final res = await _apiClient.get(ApiConstants.customerVenueInfo, queryParameters: query);
      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final vData = res.data['venue'] as Map<String, dynamic>?;
        if (vData != null) {
          state = state.copyWith(
            venueId: _nonEmpty(vData['tenant_id'], state.venueId),
            venueName: _nonEmpty(vData['venue_name'], state.venueName),
            address: vData['address']?.toString() ?? state.address,
            bannerUrl: vData['banner_url']?.toString() ?? state.bannerUrl,
            logoUrl: vData['logo_url']?.toString() ?? state.logoUrl,
            welcomeVideoUrl: vData['welcome_video_url']?.toString() ?? state.welcomeVideoUrl,
            promoSlides: (vData['promo_slides'] is List)
                ? (vData['promo_slides'] as List)
                    .whereType<Map>()
                    .map((e) => PromoSlide.fromJson(Map<String, dynamic>.from(e)))
                    .where((s) => s.url.isNotEmpty)
                    .toList()
                : state.promoSlides,
            welcomeTitle: _nonEmpty(vData['welcome_title'], state.welcomeTitle),
            welcomeSubtitle: _nonEmpty(vData['welcome_subtitle'], state.welcomeSubtitle),
            announcementText: vData['announcement_text']?.toString() ?? state.announcementText,
            wifiSsid: vData['wifi_ssid']?.toString() ?? state.wifiSsid,
            wifiPassword: vData['wifi_password']?.toString() ?? state.wifiPassword,
            showWifi: vData['show_wifi'] != false,
            workingHours: _nonEmpty(vData['working_hours'], state.workingHours),
            statusText: _nonEmpty(
              vData['status_text'],
              state.statusText.isNotEmpty ? state.statusText : 'Açık · Servis Aktif',
            ),
            lockedTenantId: state.lockedTenantId ?? vData['tenant_id']?.toString(),
            lockedVenueName: state.lockedVenueName ?? vData['venue_name']?.toString(),
            campaigns: (vData['campaigns'] as List?)
                    ?.map((c) => VenueCampaign.fromJson(c as Map<String, dynamic>))
                    .toList() ??
                state.campaigns,
            primaryColorHex: _nonEmpty(vData['primary_color'], state.primaryColorHex),
            accentColorHex: _nonEmpty(vData['accent_color'], state.accentColorHex),
            rating: double.tryParse(vData['rating']?.toString() ?? '') ?? state.rating,
            reviewCount: int.tryParse(vData['review_count']?.toString() ?? '') ?? state.reviewCount,
            cuisineType: _nonEmpty(vData['cuisine_type'], state.cuisineType),
            amenities: (vData['amenities'] is List && (vData['amenities'] as List).isNotEmpty)
                ? (vData['amenities'] as List).map((e) => e.toString()).toList()
                : state.amenities,
          );
          _saveToStorage(state);
        }
      }
    } catch (e, st) {
      debugPrint('TableSessionProvider: Error fetching live venue info: $e\n$st');
    } finally {
      _isSyncingVenue = false;
    }
  }

  Future<Map<String, dynamic>?> resolveTableQr(String rawCode) async {
    try {
      final res = await _apiClient.post(ApiConstants.resolveTable, data: {
        'qr_data': rawCode,
        'locked_tenant_id': state.lockedTenantId ?? '',
      });

      if (res.statusCode == 200 && res.data != null) {
        return res.data as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        return e.response!.data as Map<String, dynamic>;
      }
      debugPrint('TableSessionProvider: DioException resolving QR: $e');
    } catch (e, st) {
      debugPrint('TableSessionProvider: Unexpected error resolving QR: $e\n$st');
    }
    return null;
  }

  Future<Map<String, dynamic>> confirmTableSeating({
    required String tableId,
    required String tableName,
    String? zoneName,
    String? tenantId,
    String? venueName,
    int guestCount = 2,
    int adultCount = 2,
    int childCount = 0,
    int babyCount = 0,
    String? customerName,
    String? customerPhone,
    String? wifiSsid,
    String? wifiPassword,
    bool joining = false,
  }) async {
    final effectiveTenant = tenantId ?? state.lockedTenantId ?? state.venueId;
    final sameTable = state.isSeated && state.tableId == tableId;
    final nextAdults = (joining || sameTable) ? state.adultCount + adultCount : adultCount;
    final nextChildren = (joining || sameTable) ? state.childCount + childCount : childCount;
    final nextBabies = (joining || sameTable) ? state.babyCount + babyCount : babyCount;
    final totalGuests = (nextAdults + nextChildren + nextBabies) > 0
        ? (nextAdults + nextChildren + nextBabies)
        : guestCount;

    // Fetch real-time device GPS coordinates for geofence verification
    final coords = await LocationHelper.getCurrentCoordinates();

    final payload = {
      'table_id': tableId,
      'tenant_id': effectiveTenant,
      'adults': nextAdults,
      'children': nextChildren,
      'babies': nextBabies,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'action': (joining || sameTable) ? 'join' : 'seat',
      'notify_staff': true,
      'notify_business': true,
      'message': (joining || sameTable)
          ? '${customerName ?? 'Misafir'} $tableName masasına katıldı ($totalGuests kişi)'
          : '${customerName ?? 'Misafir'} $tableName masasına oturdu ($totalGuests kişi)',
      if (coords != null) ...{
        'latitude': coords['latitude'],
        'longitude': coords['longitude'],
        'accuracy': coords['accuracy'],
      },
    };

    // Call backend API to initiate table session and broadcast WebSocket event to waiters
    try {
      final res = await _apiClient.post(ApiConstants.seatTable, data: payload);
      
      if (res.statusCode == 200 && res.data != null && (res.data['success'] == true || res.data['status'] == 'success')) {
        if (res.data['token'] != null) {
          final token = res.data['token'].toString();
          if (token.isNotEmpty) {
            await _apiClient.persistTokens(access: token);
          }
        }

        // Only commit seating state upon verified backend acceptance
        state = state.copyWith(
          venueId: effectiveTenant,
          tableId: tableId,
          tableName: tableName,
          zoneName: zoneName ?? state.zoneName,
          guestCount: totalGuests,
          adultCount: nextAdults,
          childCount: nextChildren,
          babyCount: nextBabies,
          venueName: venueName ?? state.venueName,
          lockedTenantId: state.lockedTenantId ?? effectiveTenant,
          lockedVenueName: state.lockedVenueName ?? venueName ?? state.venueName,
          wifiSsid: wifiSsid ?? state.wifiSsid,
          wifiPassword: wifiPassword ?? state.wifiPassword,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('qordy_seated_timestamp', DateTime.now().millisecondsSinceEpoch);
        await _saveToStorage(state);

        return {'success': true, 'message': 'Masaya oturuldu.'};
      } else {
        final err = res.data?['message']?.toString() ?? res.data?['error']?.toString() ?? 'Masaya oturulamadı.';
        return {'success': false, 'message': err};
      }
    } on DioException catch (e) {
      debugPrint('TableSessionProvider: DioException in seatTable: $e');
      final respData = e.response?.data;
      String errMessage = 'Masaya oturulurken hata oluştu.';
      if (respData is Map) {
        errMessage = respData['message']?.toString() ?? respData['error']?.toString() ?? errMessage;
      }
      return {'success': false, 'message': errMessage};
    } catch (e, st) {
      debugPrint('TableSessionProvider: Error posting seatTable: $e\n$st');
      return {'success': false, 'message': 'Hata: $e'};
    }
  }

  Future<Map<String, dynamic>> leaveTable() async {
    final currentTableId = state.tableId;
    final currentTenantId = state.lockedTenantId ?? state.venueId;

    // Masadan yerel olarak anında ayrıl
    await clearSession();

    if (currentTableId.isEmpty || currentTableId == 'unseated') {
      return {'success': true, 'message': 'Masa oturumu sonlandırıldı.'};
    }

    try {
      final res = await _apiClient.post(ApiConstants.leaveTable, data: {
        'table_id': currentTableId,
        'tenant_id': currentTenantId,
      });

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        return {'success': true, 'message': res.data['message']?.toString() ?? 'Masadan ayrıldınız.'};
      }
    } catch (e) {
      debugPrint('TableSessionProvider: leaveTable exception: $e');
    }
    return {'success': true, 'message': 'Masadan ayrıldınız.'};
  }

  void setGuestBreakdown({required int adults, required int children, required int babies}) {
    final total = adults + children + babies;
    state = state.copyWith(
      guestCount: total > 0 ? total : 1,
      adultCount: adults,
      childCount: children,
      babyCount: babies,
    );
    _saveToStorage(state);
  }

  void setGuestCount(int count) {
    setGuestBreakdown(adults: count, children: 0, babies: 0);
  }

  Future<void> clearSession() async {
    state = state.copyWith(
      tableId: '',
      tableName: '',
      zoneName: '',
      guestCount: 2,
      adultCount: 2,
      childCount: 0,
      babyCount: 0,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.keySavedVenueTable);
      await prefs.remove(ApiConstants.keyTableId);
      await prefs.remove(ApiConstants.keyTableName);
      await prefs.remove(ApiConstants.keyZoneName);
      await prefs.remove(ApiConstants.keyGuestCount);
      await prefs.remove(ApiConstants.keyAdultCount);
      await prefs.remove(ApiConstants.keyChildCount);
      await prefs.remove(ApiConstants.keyBabyCount);
      await prefs.remove('qordy_seated_timestamp');
      await _saveToStorage(state);
    } catch (e, st) {
      debugPrint('TableSessionProvider: Error clearing session from prefs: $e\n$st');
    }
  }

  Future<void> _saveToStorage(VenueTableModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.keySavedVenueTable, jsonEncode(model.toJson()));
      await prefs.setString(ApiConstants.keyTableId, model.tableId);
      await prefs.setString(ApiConstants.keyTableName, model.tableName);
      await prefs.setString(ApiConstants.keyVenueName, model.venueName);
      await prefs.setInt(ApiConstants.keyGuestCount, model.guestCount);
      await prefs.setInt(ApiConstants.keyAdultCount, model.adultCount);
      await prefs.setInt(ApiConstants.keyChildCount, model.childCount);
      await prefs.setInt(ApiConstants.keyBabyCount, model.babyCount);
      if (model.lockedTenantId != null) {
        await prefs.setString(ApiConstants.keyLockedTenantId, model.lockedTenantId!);
      }
      if (model.lockedVenueName != null) {
        await prefs.setString(ApiConstants.keyLockedVenueName, model.lockedVenueName!);
      }
    } catch (e, st) {
      debugPrint('TableSessionProvider: Error saving to prefs: $e\n$st');
    }
  }
}

extension VenueTableModelCopyWith on VenueTableModel {
  VenueTableModel copyWith({
    String? venueId,
    String? venueName,
    String? address,
    String? bannerUrl,
    String? logoUrl,
    String? welcomeVideoUrl,
    List<PromoSlide>? promoSlides,
    String? welcomeTitle,
    String? welcomeSubtitle,
    String? announcementText,
    String? tableId,
    String? tableName,
    String? zoneName,
    int? guestCount,
    int? adultCount,
    int? childCount,
    int? babyCount,
    String? lockedTenantId,
    String? lockedVenueName,
    String? wifiSsid,
    String? wifiPassword,
    bool? showWifi,
    String? workingHours,
    String? statusText,
    String? assignedWaiter,
    List<VenueCampaign>? campaigns,
    String? primaryColorHex,
    String? accentColorHex,
    double? rating,
    int? reviewCount,
    String? cuisineType,
    List<String>? amenities,
  }) {
    return VenueTableModel(
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      address: address ?? this.address,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      welcomeVideoUrl: welcomeVideoUrl ?? this.welcomeVideoUrl,
      promoSlides: promoSlides ?? this.promoSlides,
      welcomeTitle: welcomeTitle ?? this.welcomeTitle,
      welcomeSubtitle: welcomeSubtitle ?? this.welcomeSubtitle,
      announcementText: announcementText ?? this.announcementText,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      zoneName: zoneName ?? this.zoneName,
      guestCount: guestCount ?? this.guestCount,
      adultCount: adultCount ?? this.adultCount,
      childCount: childCount ?? this.childCount,
      babyCount: babyCount ?? this.babyCount,
      lockedTenantId: lockedTenantId ?? this.lockedTenantId,
      lockedVenueName: lockedVenueName ?? this.lockedVenueName,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      showWifi: showWifi ?? this.showWifi,
      workingHours: workingHours ?? this.workingHours,
      statusText: statusText ?? this.statusText,
      assignedWaiter: assignedWaiter ?? this.assignedWaiter,
      campaigns: campaigns ?? this.campaigns,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      cuisineType: cuisineType ?? this.cuisineType,
      amenities: amenities ?? this.amenities,
    );
  }
}
