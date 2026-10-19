class MenuCategory {
  final String id;
  final String name;
  final String? icon;
  final String? imageUrl;
  final String? description;

  const MenuCategory({
    required this.id,
    required this.name,
    this.icon,
    this.imageUrl,
    this.description,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id']?.toString() ?? json['category_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['category_name']?.toString() ?? 'Kategori',
      icon: json['icon']?.toString(),
      imageUrl: json['image_url']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class ProductVariant {
  final String variantId;
  final String name;
  final double priceModifier;
  final bool isDefault;

  const ProductVariant({
    required this.variantId,
    required this.name,
    required this.priceModifier,
    this.isDefault = false,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      variantId: json['variant_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Standart',
      priceModifier: double.tryParse(json['price_modifier']?.toString() ?? '0') ?? 0.0,
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
}

class MenuOptionExtra {
  final String id;
  final String name;
  final double price;

  const MenuOptionExtra({
    required this.id,
    required this.name,
    required this.price,
  });

  factory MenuOptionExtra.fromJson(Map<String, dynamic> json) {
    return MenuOptionExtra(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class MenuItemModel {
  final String id;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final int? calories;
  final String? tag;
  final double rating;
  final int reviewCount;
  final int prepTimeMinutes;
  final bool isFeatured;
  final bool hasVariants;
  final List<ProductVariant> variants;
  final List<String> ingredients;
  final List<String> cookingDegrees;
  final List<MenuOptionExtra> extras;
  final List<String> allergens;
  final bool isVegan;
  final bool isGlutenFree;

  const MenuItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.calories,
    this.tag,
    this.rating = 4.8,
    this.reviewCount = 120,
    this.prepTimeMinutes = 15,
    this.isFeatured = false,
    this.hasVariants = false,
    this.variants = const [],
    this.ingredients = const [],
    this.cookingDegrees = const ['Az Pişmiş', 'Orta Pişmiş', 'Çok Pişmiş'],
    this.extras = const [],
    this.allergens = const [],
    this.isVegan = false,
    this.isGlutenFree = false,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    List<MenuOptionExtra> parseExtras() {
      if (json['extras'] is List) {
        return (json['extras'] as List)
            .map((e) => MenuOptionExtra.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    List<ProductVariant> parseVariants() {
      if (json['variants'] is List) {
        return (json['variants'] as List)
            .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    List<String> parseIngredients() {
      if (json['ingredients'] is List) {
        return (json['ingredients'] as List).map((e) => e.toString()).toList();
      }
      return [];
    }

    List<String> parseAllergens() {
      if (json['allergens'] is List) {
        return (json['allergens'] as List).map((e) => e.toString()).toList();
      }
      return [];
    }

    return MenuItemModel(
      id: json['id']?.toString() ?? json['item_id']?.toString() ?? json['menu_item_id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Ürün Adı',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? json['image_path']?.toString(),
      calories: json['calories'] != null ? int.tryParse(json['calories'].toString()) : 350,
      tag: json['tag']?.toString() ?? json['badge']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '4.8') ?? 4.8,
      reviewCount: int.tryParse(json['review_count']?.toString() ?? '120') ?? 120,
      prepTimeMinutes: int.tryParse(json['prep_time_minutes']?.toString() ?? json['prep_time']?.toString() ?? '15') ?? 15,
      isFeatured: json['is_featured'] == true || json['featured'] == 1,
      hasVariants: json['has_variants'] == true || json['has_variants'] == 1 || (json['variants'] is List && (json['variants'] as List).isNotEmpty),
      variants: parseVariants(),
      ingredients: parseIngredients(),
      cookingDegrees: json['cooking_degrees'] is List
          ? List<String>.from(json['cooking_degrees'])
          : const [],
      extras: parseExtras(),
      allergens: parseAllergens(),
      isVegan: json['is_vegan'] == true || json['vegan'] == 1,
      isGlutenFree: json['is_gluten_free'] == true || json['gluten_free'] == 1,
    );
  }
}
