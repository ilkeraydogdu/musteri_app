import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/venue_table_model.dart';
import '../../welcome/application/table_session_provider.dart';

class MenuState {
  final bool isLoading;
  final List<MenuCategory> categories;
  final String selectedCategoryId;
  final List<MenuItemModel> allItems;
  final String searchQuery;
  final String? errorMessage;
  final DateTime? lastSyncedAt;
  final bool isOffline;

  const MenuState({
    this.isLoading = false,
    this.categories = const [],
    this.selectedCategoryId = 'all',
    this.allItems = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.lastSyncedAt,
    this.isOffline = false,
  });

  List<MenuItemModel> get featuredItems {
    final featured = allItems.where((item) => item.isFeatured).toList();
    if (featured.isNotEmpty) return featured;
    return allItems.take(6).toList();
  }

  List<MenuItemModel> get filteredItems {
    var items = allItems;
    if (selectedCategoryId.isNotEmpty && selectedCategoryId != 'all') {
      items = items.where((item) => item.categoryId == selectedCategoryId).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      items = items
          .where((item) =>
              item.name.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q))
          .toList();
    }
    return items;
  }

  MenuState copyWith({
    bool? isLoading,
    List<MenuCategory>? categories,
    String? selectedCategoryId,
    List<MenuItemModel>? allItems,
    String? searchQuery,
    String? errorMessage,
    DateTime? lastSyncedAt,
    bool? isOffline,
  }) {
    return MenuState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      allItems: allItems ?? this.allItems,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

final menuProvider = StateNotifierProvider<MenuNotifier, MenuState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = MenuNotifier(ref, apiClient);
  ref.listen<VenueTableModel>(tableSessionProvider, (prev, next) {
    if (prev?.venueId != next.venueId || prev?.tableId != next.tableId) {
      if (next.venueId.isNotEmpty) {
        notifier.fetchMenu(
          tenantId: next.venueId,
          tableId: next.tableId.isNotEmpty ? next.tableId : null,
          silent: true,
        );
      }
    }
  });
  return notifier;
});

class MenuNotifier extends StateNotifier<MenuState> {
  final Ref _ref;
  final ApiClient _apiClient;
  Timer? _syncTimer;
  bool _isFetching = false;

  static const _cacheKeyCategories = 'qordy_menu_categories_cache';
  static const _cacheKeyItems = 'qordy_menu_items_cache';
  static const _cacheKeyTimestamp = 'qordy_menu_cache_ts';

  MenuNotifier(this._ref, this._apiClient) : super(const MenuState()) {
    _loadFromCacheThenFetch();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchMenu(silent: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCacheThenFetch() async {
    await _loadCache();
    await fetchMenu(silent: state.allItems.isEmpty);
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catsRaw = prefs.getString(_cacheKeyCategories);
      final itemsRaw = prefs.getString(_cacheKeyItems);
      if (catsRaw != null && itemsRaw != null) {
        final catsList = jsonDecode(catsRaw) as List;
        final itemsList = jsonDecode(itemsRaw) as List;
        final categories = catsList
            .map((c) => MenuCategory.fromJson(c as Map<String, dynamic>))
            .toList();
        final items = itemsList
            .map((i) => MenuItemModel.fromJson(i as Map<String, dynamic>))
            .toList();
        if (items.isNotEmpty) {
          final normalized = _normalizeCategories(categories, items);
          state = state.copyWith(
            categories: normalized,
            allItems: items,
            isOffline: true,
            lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(
              prefs.getInt(_cacheKeyTimestamp) ?? DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('MenuNotifier: cache load error: $e');
    }
  }

  Future<void> _saveCache(List<MenuCategory> categories, List<MenuItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Serialize using toJson-like maps; models don't have toJson so we rebuild minimal maps
      final catsJson = categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'icon': c.icon,
                'image_url': c.imageUrl,
                'description': c.description,
              })
          .toList();
      final itemsJson = items
          .map((i) => {
                'id': i.id,
                'category_id': i.categoryId,
                'name': i.name,
                'description': i.description,
                'price': i.price,
                'image_url': i.imageUrl,
                'calories': i.calories,
                'tag': i.tag,
                'rating': i.rating,
                'review_count': i.reviewCount,
                'prep_time_minutes': i.prepTimeMinutes,
                'is_featured': i.isFeatured,
                'has_variants': i.hasVariants,
                'variants': i.variants
                    .map((v) => {
                          'variant_id': v.variantId,
                          'name': v.name,
                          'price_modifier': v.priceModifier,
                          'is_default': v.isDefault,
                        })
                    .toList(),
                'ingredients': i.ingredients,
                'cooking_degrees': i.cookingDegrees,
                'extras': i.extras
                    .map((e) => {'id': e.id, 'name': e.name, 'price': e.price})
                    .toList(),
                'allergens': i.allergens,
                'is_vegan': i.isVegan,
                'is_gluten_free': i.isGlutenFree,
              })
          .toList();
      await prefs.setString(_cacheKeyCategories, jsonEncode(catsJson));
      await prefs.setString(_cacheKeyItems, jsonEncode(itemsJson));
      await prefs.setInt(_cacheKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('MenuNotifier: cache save error: $e');
    }
  }

  void selectCategory(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  static String _inferCategoryIcon(String id, String name) {
    final text = '$id $name'.toLowerCase();
    if (text.contains('all') || text.contains('tümü')) return '✨';
    if (text.contains('nargile') || text.contains('shisha') || text.contains('hookah')) return '💨';
    if (text.contains('espresso') || text.contains('kahve') || text.contains('coffee') || text.contains('latte')) return '☕';
    if (text.contains('çay') || text.contains('cay') || text.contains('bitki') || text.contains('tea')) return '🫖';
    if (text.contains('milkshake') || text.contains('frozen') || text.contains('frappe') || text.contains('smoothie') || text.contains('kokteyl')) return '🍹';
    if (text.contains('soğuk') || text.contains('soguk') || text.contains('meşrubat') || text.contains('mesrubat') || text.contains('icecek') || text.contains('içecek')) return '🥤';
    if (text.contains('tatlı') || text.contains('tatli') || text.contains('waffle') || text.contains('pasta') || text.contains('cheesecake')) return '🍰';
    if (text.contains('burger')) return '🍔';
    if (text.contains('pizza')) return '🍕';
    if (text.contains('kahvalt') || text.contains('tost') || text.contains('sandvi') || text.contains('kruvasan')) return '🥐';
    if (text.contains('salata') || text.contains('bowl')) return '🥗';
    if (text.contains('makarna') || text.contains('noodle')) return '🍝';
    if (text.contains('et') || text.contains('steak') || text.contains('ızgara') || text.contains('izgara') || text.contains('kebap') || text.contains('ana yemek')) return '🥩';
    if (text.contains('atistirmalik') || text.contains('atıştırmalık') || text.contains('cerez') || text.contains('çerez') || text.contains('aperatif')) return '🍟';
    if (text.contains('dondurma')) return '🍨';
    return '🍽️';
  }

  static String _humanizeCategorySlug(String slug) {
    switch (slug.toLowerCase()) {
      case 'icecek':
      case 'icecekler':
        return 'İçecekler';
      case 'sut-kahvaltilik':
      case 'kahvalti':
        return 'Kahvaltı & Tost';
      case 'atistirmalik':
        return 'Atıştırmalık & Tatlı';
      case 'ana-yemek':
        return 'Ana Yemekler';
      case 'tatli':
        return 'Tatlılar';
      default:
        return slug
            .split(RegExp(r'[-_]'))
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  List<MenuCategory> _normalizeCategories(
    List<MenuCategory> apiCategories,
    List<MenuItemModel> items,
  ) {
    final Map<String, MenuCategory> catMap = {};

    for (final c in apiCategories) {
      if (c.id.isEmpty) continue;
      final firstItemWithImg = items.cast<MenuItemModel?>().firstWhere(
            (it) => it != null && it.categoryId == c.id && (it.imageUrl?.isNotEmpty ?? false),
            orElse: () => null,
          );
      catMap[c.id] = MenuCategory(
        id: c.id,
        name: c.name,
        icon: (c.icon != null && c.icon!.trim().isNotEmpty)
            ? c.icon
            : _inferCategoryIcon(c.id, c.name),
        imageUrl: (c.imageUrl != null && c.imageUrl!.trim().isNotEmpty)
            ? c.imageUrl
            : firstItemWithImg?.imageUrl,
        description: c.description,
      );
    }

    for (final item in items) {
      final cid = item.categoryId.trim();
      if (cid.isEmpty || catMap.containsKey(cid)) continue;
      final humanName = _humanizeCategorySlug(cid);
      final firstItemWithImg = items.cast<MenuItemModel?>().firstWhere(
            (it) => it != null && it.categoryId == cid && (it.imageUrl?.isNotEmpty ?? false),
            orElse: () => null,
          );
      catMap[cid] = MenuCategory(
        id: cid,
        name: humanName,
        icon: _inferCategoryIcon(cid, humanName),
        imageUrl: firstItemWithImg?.imageUrl,
      );
    }

    final nonEmptyCats = items.isEmpty
        ? catMap.values.toList()
        : catMap.values
            .where((c) => items.any((it) => it.categoryId == c.id))
            .toList();

    return [
      const MenuCategory(
        id: 'all',
        name: 'Tümü',
        icon: '✨',
      ),
      ...nonEmptyCats,
    ];
  }

  Future<void> fetchMenu({
    String? tenantId,
    String? tableId,
    bool silent = false,
  }) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final session = _ref.read(tableSessionProvider);
      final query = <String, dynamic>{};
      final tId = tenantId ??
          session.lockedTenantId ??
          (session.venueId.isNotEmpty ? session.venueId : null);
      if (tId != null && tId.isNotEmpty) {
        query['tenant_id'] = tId;
      }
      final tblId =
          tableId ?? (session.tableId.isNotEmpty ? session.tableId : null);
      if (tblId != null && tblId.isNotEmpty) {
        query['table_id'] = tblId;
      }

      final response = await _apiClient.get(
        ApiConstants.customerMenu,
        queryParameters: query,
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true) {
          final rawCats = data['categories'] as List? ?? [];
          final rawItems = data['items'] as List? ?? [];

          final apiCategories = rawCats
              .map((c) => MenuCategory.fromJson(c as Map<String, dynamic>))
              .toList();

          final items = rawItems
              .map((i) => MenuItemModel.fromJson(i as Map<String, dynamic>))
              .toList();

          if (items.isNotEmpty || apiCategories.isNotEmpty) {
            final normalizedCategories =
                _normalizeCategories(apiCategories, items);
            final currentSelected = state.selectedCategoryId;
            final hasCurrentSelected = normalizedCategories
                .any((c) => c.id == currentSelected);
            final nextSelected = hasCurrentSelected
                ? currentSelected
                : normalizedCategories.first.id;

            state = state.copyWith(
              isLoading: false,
              categories: normalizedCategories,
              selectedCategoryId: nextSelected,
              allItems: items,
              errorMessage: null,
              lastSyncedAt: DateTime.now(),
              isOffline: false,
            );
            await _saveCache(normalizedCategories, items);
            return;
          }
        }
      }

      // If API returned empty but we have cache, keep cache and mark offline
      if (state.allItems.isNotEmpty) {
        state = state.copyWith(isLoading: false, isOffline: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          selectedCategoryId: state.selectedCategoryId.isNotEmpty
              ? state.selectedCategoryId
              : 'all',
        );
      }
    } catch (e) {
      // On network error, keep cached items if available
      if (state.allItems.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          isOffline: true,
          errorMessage: 'Çevrimdışı mod: son kaydedilen menü gösteriliyor.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          selectedCategoryId: state.selectedCategoryId.isNotEmpty
              ? state.selectedCategoryId
              : 'all',
          allItems: state.allItems,
          errorMessage: 'Menü yüklenirken hata oluştu: $e',
        );
      }
    } finally {
      _isFetching = false;
    }
  }
}
