import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/menu_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../cart/application/cart_provider.dart';

class ProductDetailSheet extends ConsumerStatefulWidget {
  final MenuItemModel item;

  const ProductDetailSheet({
    super.key,
    required this.item,
  });

  static Future<void> show(BuildContext context, MenuItemModel item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<ProductDetailSheet> {
  int _quantity = 1;
  late String _selectedCookingDegree;
  ProductVariant? _selectedVariant;
  final Set<MenuOptionExtra> _selectedExtras = {};
  final Set<String> _removedIngredients = {};
  final TextEditingController _noteController = TextEditingController();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _selectedCookingDegree = widget.item.cookingDegrees.isNotEmpty
        ? widget.item.cookingDegrees[0]
        : '';

    if (widget.item.variants.isNotEmpty) {
      _selectedVariant = widget.item.variants.firstWhere(
        (v) => v.isDefault,
        orElse: () => widget.item.variants.first,
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _currentUnitPrice {
    double base = widget.item.price;
    if (_selectedVariant != null) {
      base += _selectedVariant!.priceModifier;
    }
    for (final extra in _selectedExtras) {
      base += extra.price;
    }
    return base;
  }

  double get _currentTotalPrice => _currentUnitPrice * _quantity;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Image with Header Actions (Figma exact)
                Stack(
                  children: [
                    SizedBox(
                      height: 270,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: AppColors.surfaceElevated),
                                errorWidget: (_, _, _) => _buildFallbackHero(),
                              )
                            : _buildFallbackHero(),
                      ),
                    ),
                    Container(
                      height: 270,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            AppColors.surface.withValues(alpha: 0.98),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(alpha: 0.5),
                              ),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(alpha: 0.5),
                              ),
                              icon: Icon(
                                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isFavorite ? Colors.redAccent : Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _isFavorite = !_isFavorite);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Title, Price & Details (Figma exact 40:2642)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTypography.headingLarge.copyWith(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₺${_currentUnitPrice.toStringAsFixed(0)}',
                            style: AppTypography.priceHero.copyWith(fontSize: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rating & Preparation Time Row
                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                item.rating.toString(),
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' (${item.reviewCount} değerlendirme)',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          const Text('·', style: TextStyle(color: AppColors.textMuted)),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '~${item.prepTimeMinutes} dk hazırlama',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 1. Varyant / Porsiyon Seçimi
                      if (item.variants.isNotEmpty) ...[
                        Text(
                          'Porsiyon / Boyut Seçimi',
                          style: AppTypography.headingSmall,
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: item.variants.map((variant) {
                            final isSelected = _selectedVariant?.variantId == variant.variantId;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedVariant = variant);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryLight
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 1.4 : 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      variant.name,
                                      style: isSelected ? AppTypography.bodyLarge : AppTypography.bodyMedium,
                                    ),
                                    const Spacer(),
                                    if (variant.priceModifier > 0)
                                      Text(
                                        '+₺${variant.priceModifier.toStringAsFixed(0)}',
                                        style: AppTypography.priceSmall,
                                      )
                                    else
                                      Text(
                                        'Standart',
                                        style: AppTypography.caption,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 2. Pişirme Derecesi (Figma Segmented Pills)
                      if (item.cookingDegrees.isNotEmpty) ...[
                        Text(
                          'Pişirme Derecesi',
                          style: AppTypography.headingSmall,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: item.cookingDegrees.map((degree) {
                            final isSelected = _selectedCookingDegree == degree;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedCookingDegree = degree);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: 0.8,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.25),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      degree,
                                      style: isSelected
                                          ? AppTypography.buttonMedium.copyWith(fontSize: 13)
                                          : AppTypography.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 3. Ekstra Tercihler (Figma Exact Checkbox Cards)
                      if (item.extras.isNotEmpty) ...[
                        Text(
                          'Ekstra Tercihler',
                          style: AppTypography.headingSmall,
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: item.extras.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final extra = item.extras[idx];
                            final isChecked = _selectedExtras.contains(extra);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isChecked) {
                                    _selectedExtras.remove(extra);
                                  } else {
                                    _selectedExtras.add(extra);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isChecked ? AppColors.primaryLight : AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isChecked ? AppColors.primary : AppColors.border,
                                    width: isChecked ? 1.2 : 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isChecked
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      color: isChecked ? AppColors.primary : AppColors.textMuted,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        extra.name,
                                        style: AppTypography.bodyLarge.copyWith(
                                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '+₺${extra.price.toStringAsFixed(0)}',
                                      style: AppTypography.priceSmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 4. Çıkarılabilir Malzemeler
                      if (item.ingredients.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Çıkarılabilir Malzemeler',
                              style: AppTypography.headingSmall,
                            ),
                            const Spacer(),
                            if (_removedIngredients.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_removedIngredients.length} çıkarıldı',
                                  style: AppTypography.caption.copyWith(color: Colors.redAccent),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.ingredients.map((ing) {
                            final isRemoved = _removedIngredients.contains(ing);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isRemoved) {
                                    _removedIngredients.remove(ing);
                                  } else {
                                    _removedIngredients.add(ing);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isRemoved
                                      ? Colors.redAccent.withValues(alpha: 0.12)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRemoved ? Colors.redAccent : AppColors.border,
                                    width: isRemoved ? 1.0 : 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isRemoved
                                          ? Icons.remove_circle_outline_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 15,
                                      color: isRemoved ? Colors.redAccent : AppColors.success,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      ing,
                                      style: TextStyle(
                                        color: isRemoved ? Colors.redAccent : AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: isRemoved ? FontWeight.bold : FontWeight.w500,
                                        decoration: isRemoved ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 5. Sipariş Notu
                      Text(
                        'Sipariş Notu',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteController,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Örn: Sosu ayrı olsun, alerjen uyarısı vb.',
                          hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar (Figma exact Stepper + Sepete Ekle CTA)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).padding.bottom + 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(top: BorderSide(color: AppColors.border, width: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Stepper (- 1 +) in warm cream pill
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, color: AppColors.textPrimary, size: 18),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (_quantity > 1) {
                              setState(() => _quantity--);
                            }
                          },
                        ),
                        Text(
                          '$_quantity',
                          style: AppTypography.headingSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 18),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _quantity++);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Add to cart CTA (Paprika gradient button)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ref.read(cartProvider.notifier).addItem(
                              item: widget.item,
                              quantity: _quantity,
                              selectedVariant: _selectedVariant,
                              cookingDegree: widget.item.cookingDegrees.isNotEmpty ? _selectedCookingDegree : null,
                              extras: _selectedExtras.toList(),
                              removedIngredients: _removedIngredients.toList(),
                              note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${widget.item.name} ($_quantity adet) sepete eklendi.',
                                        style: AppTypography.bodySmall.copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.textPrimary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Text(
                            'Sepete Ekle — ₺${_currentTotalPrice.toStringAsFixed(0)}',
                            style: AppTypography.buttonLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackHero() {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Center(
        child: Icon(Icons.restaurant_rounded, size: 60, color: AppColors.textMuted),
      ),
    );
  }
}
