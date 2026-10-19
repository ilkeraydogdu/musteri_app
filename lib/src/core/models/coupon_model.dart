class CouponModel {
  final String code;
  final String title;
  final String description;
  final double discountValue;
  final double minSpend;
  final String validUntil;
  final String discountType;

  const CouponModel({
    required this.code,
    required this.title,
    required this.description,
    required this.discountValue,
    this.minSpend = 0.0,
    required this.validUntil,
    this.discountType = 'percentage',
  });

  double get discountPercent => discountType == 'percentage' ? discountValue : 0.0;
  double get fixedDiscount => discountType != 'percentage' ? discountValue : 0.0;
  String get discountBadge => discountType == 'percentage'
      ? '%${discountPercent.toStringAsFixed(0)} İndirim'
      : '₺${discountValue.toStringAsFixed(0)} İndirim';

  double calculateDiscount(double subtotal) {
    if (subtotal < minSpend) return 0.0;
    if (discountType == 'percentage') {
      return subtotal * (discountValue / 100.0);
    } else {
      return subtotal > discountValue ? discountValue : subtotal;
    }
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    final discountTypeRaw = json['discount_type']?.toString() ?? 'percentage';
    final discountVal = double.tryParse(json['discount_value']?.toString() ?? json['value']?.toString() ?? '0') ?? 0.0;

    String validUntilText = 'Geçerli';
    final validUntil = json['valid_until_time']?.toString() ?? json['valid_until']?.toString();
    final validFrom = json['valid_from_time']?.toString() ?? json['valid_from']?.toString();
    if (validUntil != null && validUntil.isNotEmpty) {
      validUntilText = validUntil;
    } else if (validFrom != null && validFrom.isNotEmpty) {
      validUntilText = validFrom;
    }

    final code = (json['code']?.toString() ?? json['campaign_id']?.toString() ?? '').toUpperCase();

    return CouponModel(
      code: code,
      title: json['title']?.toString() ?? code,
      description: json['description']?.toString() ?? '',
      discountValue: discountVal,
      minSpend: double.tryParse(json['min_spend']?.toString() ?? '0') ?? 0.0,
      validUntil: validUntilText,
      discountType: discountTypeRaw,
    );
  }
}
