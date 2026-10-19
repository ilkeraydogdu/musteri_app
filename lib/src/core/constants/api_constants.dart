class ApiConstants {
  ApiConstants._();

  // Build-time injectable via --dart-define=API_BASE_URL=...
  // Falls back to production URL when not provided (local dev / CI).
  /// Bu APK'nın indirildiği işletme. Build: --dart-define=LOCKED_TENANT_ID=CUST_...
  static const String packagedTenantId = String.fromEnvironment('LOCKED_TENANT_ID', defaultValue: '');

  static const String _defaultBase = 'https://qordy.com/api';
  static const String _buildInjected = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBase);
  static String get baseUrl => _buildInjected;

  static String get customerApiBase => '$baseUrl/mobile/customer';

  // Customer Endpoints (Public Mobile API)
  static const String customerMenu = '/mobile/customer/menu';
  static const String customerVenueInfo = '/mobile/customer/venue-info';
  static const String resolveTable = '/mobile/customer/resolve-table';
  static const String checkEmail = '/mobile/customer/check-email';
  static const String registerCustomer = '/mobile/customer/register';
  static const String loginCustomer = '/mobile/customer/login';
  static const String placeOrder = '/mobile/customer/place-order';
  static const String seatTable = '/mobile/customer/seat-table';
  static const String leaveTable = '/mobile/customer/leave-table';
  static const String wheelRecommendation = '/mobile/customer/wheel-recommendation';
  static const String validateCoupon = '/mobile/customer/validate-coupon';
  static const String getCoupons = '/mobile/customer/coupons';
  static const String callWaiter = '/mobile/customer/call-waiter';
  static const String requestBill = '/mobile/customer/request-bill';
  static const String orderStatus = '/mobile/customer/order-status';
  static const String orderHistory = '/mobile/customer/order-history';

  // Shared preferences keys
  static const String keyVenueId = 'qordy_venue_id';
  static const String keyVenueName = 'qordy_venue_name';
  static const String keyLockedTenantId = 'qordy_locked_tenant_id';
  static const String keyLockedVenueName = 'qordy_locked_venue_name';
  static const String keyTableId = 'qordy_table_id';
  static const String keyTableName = 'qordy_table_name';
  static const String keyZoneName = 'qordy_zone_name';
  static const String keyGuestCount = 'qordy_guest_count';
  static const String keyAdultCount = 'qordy_adult_count';
  static const String keyChildCount = 'qordy_child_count';
  static const String keyBabyCount = 'qordy_baby_count';
  static const String keyWifiSsid = 'qordy_wifi_ssid';
  static const String keyWifiPass = 'qordy_wifi_pass';
  static const String keyActiveOrderId = 'qordy_active_order_id';
  static const String keyCustomerToken = 'qordy_customer_token';
  static const String keyCustomerUser = 'qordy_customer_user';
  static const String keySavedVenueTable = 'qordy_customer_venue_table';
}
