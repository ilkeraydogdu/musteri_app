import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/past_order_model.dart';
import '../../../core/network/api_client.dart';
import '../../auth/application/customer_auth_provider.dart';
import '../../welcome/application/table_session_provider.dart';

final pastOrdersProvider = FutureProvider.autoDispose<List<PastOrderModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final session = ref.watch(tableSessionProvider);
  final authUser = ref.watch(customerAuthProvider);

  try {
    final query = <String, dynamic>{
      'limit': 30,
      'offset': 0,
    };

    final tenantId = session.lockedTenantId ?? session.venueId;
    if (tenantId.isNotEmpty) {
      query['tenant_id'] = tenantId;
    }

    if (authUser.isLoggedIn && authUser.phone != null && authUser.phone!.isNotEmpty) {
      query['phone'] = authUser.phone;
    }

    final res = await apiClient.get(ApiConstants.orderHistory, queryParameters: query);

    if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
      final rawOrders = res.data['orders'] as List<dynamic>? ?? [];
      final fallbackVenue = session.venueName.isNotEmpty ? session.venueName : 'İşletme';
      return rawOrders
          .whereType<Map>()
          .map((json) => PastOrderModel.fromJson(
                Map<String, dynamic>.from(json),
                fallbackVenueName: fallbackVenue,
              ))
          .toList();
    }
  } catch (e) {
    debugPrint('pastOrdersProvider: error fetching order history: $e');
  }

  return const [];
});
