enum OrderStatusStep {
  received,
  preparing,
  ready,
  delivered,
}

class TrackedOrderItem {
  final String name;
  final int quantity;
  final double price;
  final String preparationStatus;

  const TrackedOrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.preparationStatus,
  });

  factory TrackedOrderItem.fromJson(Map<String, dynamic> json) {
    return TrackedOrderItem(
      name: json['name']?.toString() ?? 'Ürün',
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      preparationStatus: json['preparation_status']?.toString() ?? 'PENDING',
    );
  }

  double get totalPrice => price * quantity;

  String get statusLabel {
    switch (preparationStatus.toUpperCase()) {
      case 'SERVED':
      case 'DELIVERED':
        return 'Masaya Servis Edildi';
      case 'READY':
        return 'Masaya Servis Edildi';
      case 'PREPARING':
      case 'IN_PROGRESS':
        return 'Hazırlanıyor';
      default:
        return 'Sırada';
    }
  }
}

class TrackingStepItem {
  final OrderStatusStep step;
  final String title;
  final String description;
  final String? time;
  final bool isCompleted;
  final bool isCurrent;

  const TrackingStepItem({
    required this.step,
    required this.title,
    required this.description,
    this.time,
    this.isCompleted = false,
    this.isCurrent = false,
  });
}

class OrderTrackingModel {
  final bool hasActiveOrder;
  final String orderId;
  final String orderNumber;
  final String tableName;
  final int estimatedRemainingMinutes;
  final OrderStatusStep currentStatus;
  final String rawStatus;
  final double totalAmount;
  final List<TrackingStepItem> timeline;
  final List<TrackedOrderItem> items;

  const OrderTrackingModel({
    this.hasActiveOrder = true,
    required this.orderId,
    this.orderNumber = '',
    required this.tableName,
    required this.estimatedRemainingMinutes,
    required this.currentStatus,
    this.rawStatus = 'OPEN',
    required this.totalAmount,
    required this.timeline,
    this.items = const [],
  });

  factory OrderTrackingModel.empty() {
    return const OrderTrackingModel(
      hasActiveOrder: false,
      orderId: '',
      orderNumber: '',
      tableName: '',
      estimatedRemainingMinutes: 0,
      currentStatus: OrderStatusStep.received,
      rawStatus: '',
      totalAmount: 0.0,
      timeline: [],
      items: [],
    );
  }

  factory OrderTrackingModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['current_status'] ?? '').toString().toLowerCase();
    OrderStatusStep step = OrderStatusStep.received;
    if (statusStr == 'delivered' || statusStr == 'completed' || statusStr == 'served') {
      step = OrderStatusStep.delivered;
    } else if (statusStr == 'ready') {
      step = OrderStatusStep.ready;
    } else if (statusStr == 'preparing') {
      step = OrderStatusStep.preparing;
    }

    final rawTimeline = json['timeline'] as List? ?? [];
    final timeline = rawTimeline.map((t) {
      final tMap = t as Map<String, dynamic>;
      final stepCode = tMap['step']?.toString();
      OrderStatusStep tStep = OrderStatusStep.received;
      if (stepCode == 'delivered' || stepCode == 'completed' || stepCode == 'served') {
        tStep = OrderStatusStep.delivered;
      } else if (stepCode == 'ready') {
        tStep = OrderStatusStep.ready;
      } else if (stepCode == 'preparing') {
        tStep = OrderStatusStep.preparing;
      }

      return TrackingStepItem(
        step: tStep,
        title: tMap['title']?.toString() ?? '',
        description: tMap['description']?.toString() ?? '',
        time: tMap['time']?.toString(),
        isCompleted: tMap['is_completed'] == true,
        isCurrent: tMap['is_current'] == true,
      );
    }).toList();

    final rawItems = json['items'] as List? ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((i) => TrackedOrderItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();

    return OrderTrackingModel(
      hasActiveOrder: json['has_active_order'] != false,
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      tableName: json['table_name']?.toString() ?? 'Masa',
      estimatedRemainingMinutes:
          (json['estimated_remaining_minutes'] as num?)?.toInt() ?? 15,
      currentStatus: step,
      rawStatus: json['raw_status']?.toString() ?? statusStr.toUpperCase(),
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      timeline: timeline,
      items: items,
    );
  }

  int get remainingMinutes => estimatedRemainingMinutes;
  List<TrackingStepItem> get steps => timeline;
  double get progressPercentage {
    switch (currentStatus) {
      case OrderStatusStep.received:
        return 0.25;
      case OrderStatusStep.preparing:
        return 0.55;
      case OrderStatusStep.ready:
        return 0.85;
      case OrderStatusStep.delivered:
        return 1.0;
    }
  }
}
