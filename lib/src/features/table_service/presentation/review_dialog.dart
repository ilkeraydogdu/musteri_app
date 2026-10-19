import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../application/service_request_provider.dart';

class ReviewDialog extends ConsumerStatefulWidget {
  const ReviewDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ReviewDialog(),
    );
  }

  @override
  ConsumerState<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<ReviewDialog> {
  int _generalRating = 5;
  int _foodRating = 5;
  int _serviceRating = 5;
  int _ambianceRating = 5;
  int _priceRating = 4;
  bool _isAnonymous = false;
  bool _hasPhotoAttached = false;

  final Set<String> _selectedTags = {'Lezzetli Yemekler', 'Hızlı Servis'};
  final TextEditingController _commentController = TextEditingController();

  final List<String> _tags = [
    'Lezzetli Yemekler',
    'Hızlı Servis',
    'Güleryüzlü Personel',
    'Şık Ambiyans',
    'Temiz Masa',
    'Fiyat / Performans',
    'Geniş Porsiyon',
    'Sıcak Sunum',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Çok Kötü 😞';
      case 2:
        return 'Beklentinin Altında 😐';
      case 3:
        return 'Ortalama 🙂';
      case 4:
        return 'Çok Başarılı 😊';
      case 5:
        return 'Mükemmel Deneyim! ⭐';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deneyimi Değerlendir',
                      style: AppTypography.headingLarge.copyWith(fontSize: 20),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hizmet kalitemizi artırmak ve size daha iyi hizmet verebilmek için görüşleriniz değerlidir.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 18),

                // Overall Rating Hero Section
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'GENEL PUAN',
                          style: AppTypography.caption.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyan,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starIndex = index + 1;
                            final isSelected = starIndex <= _generalRating;
                            return GestureDetector(
                              onTap: () => setState(() => _generalRating = starIndex),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: isSelected ? AppColors.warning : AppColors.textMuted,
                                  size: 38,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getRatingText(_generalRating),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Category Breakdowns
                Text(
                  'Kategori Bazlı Puanlama',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                _buildCategoryScoreRow('Yemek Kalitesi', _foodRating, (val) => setState(() => _foodRating = val)),
                const SizedBox(height: 8),
                _buildCategoryScoreRow('Servis Hızı', _serviceRating, (val) => setState(() => _serviceRating = val)),
                const SizedBox(height: 8),
                _buildCategoryScoreRow('Ambiyans & Temizlik', _ambianceRating, (val) => setState(() => _ambianceRating = val)),
                const SizedBox(height: 8),
                _buildCategoryScoreRow('Fiyat / Performans', _priceRating, (val) => setState(() => _priceRating = val)),
                const SizedBox(height: 18),

                // Quick Feedback Tags
                Text(
                  'Öne Çıkanlar',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: AppTypography.bodySmall.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Comment input
                Text(
                  'Yorumunuz (Opsiyonel)',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Şefimize veya işletmeye iletmek istediğiniz notlar...',
                    hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                    fillColor: AppColors.surfaceElevated,
                    filled: true,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.cyan),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Attach Photo & Anonymous options row
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => _hasPhotoAttached = !_hasPhotoAttached);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _hasPhotoAttached ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasPhotoAttached ? AppColors.cyan : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasPhotoAttached ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                              size: 16,
                              color: _hasPhotoAttached ? AppColors.cyan : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hasPhotoAttached ? 'Fotoğraf Eklendi' : 'Fotoğraf Ekle',
                              style: AppTypography.caption.copyWith(
                                color: _hasPhotoAttached ? AppColors.cyan : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Anonim',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: _isAnonymous,
                          activeThumbColor: AppColors.cyan,
                          onChanged: (val) => setState(() => _isAnonymous = val),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Submit CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(serviceRequestProvider.notifier).submitReview(
                            generalRating: _generalRating,
                            foodRating: _foodRating,
                            serviceRating: _serviceRating,
                            ambianceRating: _ambianceRating,
                            priceRating: _priceRating,
                            tags: _selectedTags.toList(),
                            comment: _commentController.text,
                            isAnonymous: _isAnonymous,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Değerlendirmeniz için çok teşekkür ederiz! ⭐'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Değerlendirmeyi Gönder',
                      style: AppTypography.buttonLarge.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryScoreRow(String title, int score, ValueChanged<int> onSelect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              final star = index + 1;
              return GestureDetector(
                onTap: () => onSelect(star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    star <= score ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: star <= score ? AppColors.warning : AppColors.textMuted,
                    size: 20,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
