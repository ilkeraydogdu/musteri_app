import 'menu_models.dart';

class CartItemModel {
  final String id;
  final MenuItemModel menuItem;
  int quantity;
  final ProductVariant? selectedVariant;
  final String? cookingDegree;
  final List<MenuOptionExtra> selectedExtras;
  final List<String> removedIngredients;
  final String? note;

  CartItemModel({
    required this.id,
    required this.menuItem,
    this.quantity = 1,
    this.selectedVariant,
    this.cookingDegree,
    this.selectedExtras = const [],
    this.removedIngredients = const [],
    this.note,
  });

  double get unitPrice {
    double total = menuItem.price + (selectedVariant?.priceModifier ?? 0.0);
    for (final extra in selectedExtras) {
      total += extra.price;
    }
    return total;
  }

  double get totalPrice => unitPrice * quantity;

  String get summaryText {
    final List<String> parts = [];
    if (selectedVariant != null && selectedVariant!.name.isNotEmpty) {
      parts.add(selectedVariant!.name);
    }
    if (cookingDegree != null && cookingDegree!.isNotEmpty) {
      parts.add(cookingDegree!);
    }
    for (final extra in selectedExtras) {
      parts.add('+${extra.name}');
    }
    for (final rem in removedIngredients) {
      parts.add('Çıkar: $rem');
    }
    if (note != null && note!.isNotEmpty) {
      parts.add('Not: $note');
    }
    return parts.join(' • ');
  }

  Map<String, dynamic> toApiPayload() {
    return {
      'menu_item_id': menuItem.id,
      'variant_id': selectedVariant?.variantId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'note': note ?? '',
      'selected_extras': selectedExtras.map((e) => {'id': e.id, 'name': e.name, 'price': e.price}).toList(),
      'removed_ingredients': removedIngredients,
      'cooking_degree': cookingDegree,
    };
  }

  CartItemModel copyWith({
    int? quantity,
    ProductVariant? selectedVariant,
    String? cookingDegree,
    List<MenuOptionExtra>? selectedExtras,
    List<String>? removedIngredients,
    String? note,
  }) {
    return CartItemModel(
      id: id,
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      cookingDegree: cookingDegree ?? this.cookingDegree,
      selectedExtras: selectedExtras ?? this.selectedExtras,
      removedIngredients: removedIngredients ?? this.removedIngredients,
      note: note ?? this.note,
    );
  }
}
