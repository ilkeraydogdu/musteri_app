class PastOrderModel {
  final String orderId;
  final String orderNumber;
  final double totalAmount;
  final String status;
  final String createdAt;
  final String venueName;
  final String tableName;
  final String zoneName;
  final String itemsSummary;
  final int itemCount;

  const PastOrderModel({
    required this.orderId,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.venueName,
    required this.tableName,
    required this.zoneName,
    required this.itemsSummary,
    required this.itemCount,
  });

  bool get isActive =>
      status.toUpperCase() == 'PENDING' ||
      status.toUpperCase() == 'PREPARING' ||
      status.toUpperCase() == 'READY' ||
      status.toUpperCase() == 'DELIVERED';

  factory PastOrderModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackVenueName = 'İşletme',
  }) {
    final rawVenue = json['venue_name']?.toString().trim() ?? '';
    return PastOrderModel(
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '#SIP',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'COMPLETED',
      createdAt: json['created_at']?.toString() ?? '',
      venueName: rawVenue.isNotEmpty ? rawVenue : fallbackVenueName,
      tableName: json['table_name']?.toString() ?? 'Masa',
      zoneName: json['zone_name']?.toString() ?? '',
      itemsSummary: json['items_summary']?.toString() ?? 'Ürünler',
      itemCount: int.tryParse(json['item_count']?.toString() ?? '1') ?? 1,
    );
  }
}
