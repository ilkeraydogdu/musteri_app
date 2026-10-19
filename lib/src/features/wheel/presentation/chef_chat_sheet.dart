import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../cart/application/cart_provider.dart';
import '../../menu/application/menu_provider.dart';
import '../../profile/application/guest_profile_provider.dart';
import '../../welcome/application/table_session_provider.dart';

class ChefChatSheet extends ConsumerStatefulWidget {
  const ChefChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChefChatSheet(),
    );
  }

  @override
  ConsumerState<ChefChatSheet> createState() => _ChefChatSheetState();
}

class _ChefChatMessage {
  final bool fromChef;
  final String text;
  final List<Map<String, dynamic>> recommendedItems;

  const _ChefChatMessage({
    required this.fromChef,
    required this.text,
    this.recommendedItems = const [],
  });
}

class _ChefChatSheetState extends ConsumerState<ChefChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChefChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _quickSuggestions = [
    'Bugün ne tavsiye edersin?',
    'Hafif ve lezzetli bir tatlı',
    'Doyurucu bir ana yemek',
    'Vejetaryen / Hafif seçenekler',
  ];

  @override
  void initState() {
    super.initState();
    final venue = ref.read(tableSessionProvider);
    final venueName = venue.venueName.isNotEmpty ? venue.venueName : 'işletmemizin';

    _messages.add(
      _ChefChatMessage(
        fromChef: true,
        text: 'Merhaba, hoş geldiniz! Ben $venueName Şef Danışmanıyım. Damak zevkinize göre canlı menümüzden en lezzetli yemekleri seçmeniz için buradayım. Ne arzu edersiniz?',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChefChatMessage(fromChef: false, text: trimmed));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final venue = ref.read(tableSessionProvider);
      final profile = ref.read(guestProfileProvider);
      final apiClient = ref.read(apiClientProvider);

      // Save user preferences locally if mentioned
      await ref.read(guestProfileProvider.notifier).learnFromMessage(trimmed);

      // Build recent history payload
      final historyPayload = _messages.map((m) {
        return {
          'role': m.fromChef ? 'assistant' : 'user',
          'content': m.text,
        };
      }).toList();

      final tenantId = (venue.lockedTenantId != null && venue.lockedTenantId!.isNotEmpty)
          ? venue.lockedTenantId!
          : (venue.venueId.isNotEmpty ? venue.venueId : 'CUST_69653cfccb839');

      final response = await apiClient.post(
        '${ApiConstants.customerApiBase}/chef-chat',
        data: {
          'tenant_id': tenantId,
          'message': trimmed,
          'table_name': venue.tableName,
          'allergies': [...profile.allergies, ...profile.dislikes],
          'history': historyPayload,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null && response.data['success'] == true) {
        final replyText = response.data['message']?.toString() ?? 'Menümüzden dilediğiniz lezzeti seçebilirsiniz.';
        final rawRecommended = response.data['recommended_items'] as List<dynamic>? ?? [];

        final recItems = rawRecommended.map((r) => Map<String, dynamic>.from(r as Map)).toList();

        setState(() {
          _messages.add(_ChefChatMessage(
            fromChef: true,
            text: replyText,
            recommendedItems: recItems,
          ));
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages.add(const _ChefChatMessage(
            fromChef: true,
            text: 'Şu an bağlantıda ufak bir gecikme oldu. Dilerseniz menümüzü doğrudan inceleyebilir veya sorunuzu tekrar iletebilirsiniz.',
          ));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(const _ChefChatMessage(
          fromChef: true,
          text: 'Şef mutfakta kısa bir mola verdi. Lütfen birkaç saniye sonra tekrar deneyin.',
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _addRecommendedToCart(Map<String, dynamic> rawItem) {
    HapticFeedback.mediumImpact();
    final itemId = rawItem['item_id']?.toString() ?? '';
    final allItems = ref.read(menuProvider).allItems;

    // Match exact item from live menu
    MenuItemModel? matchedItem;
    for (final item in allItems) {
      if (item.id == itemId || item.name.toLowerCase() == (rawItem['name']?.toString() ?? '').toLowerCase()) {
        matchedItem = item;
        break;
      }
    }

    matchedItem ??= MenuItemModel(
      id: itemId,
      categoryId: 'general',
      name: rawItem['name']?.toString() ?? 'Önerilen Ürün',
      description: rawItem['description']?.toString() ?? '',
      price: double.tryParse(rawItem['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: rawItem['image_url']?.toString(),
    );

    ref.read(cartProvider.notifier).addItem(item: matchedItem, quantity: 1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${matchedItem.name} sepete eklendi!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      height: mediaQuery.size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Şef Danışmanı',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AI Canlı Menü',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Restoranın gerçek menüsüne göre anlık gurme önerileri',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Quick Suggestion Chips (Horizontal)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _quickSuggestions[index];
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: AppColors.surfaceElevated,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.border, width: 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _sendMessage(suggestion),
                );
              },
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Typing Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Şef menüyü inceliyor ve hazırlıyor...',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ),
                ],
              ),
            ),

          // Input Row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Şefe dilediğinizi sorun (örn: hafif tatlı)...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChefChatMessage message) {
    if (!message.fromChef) {
      // User Bubble (Right Aligned, Elegant Primary Pill)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }

    // Chef Bubble (Left Aligned, White Surface Card, Clean Corporate Contrast)
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: AppColors.border, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Recommended Dishes Carousel / List
          if (message.recommendedItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        'ŞEFİN ÖNERDİĞİ LEZZETLER',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...message.recommendedItems.map((item) => _buildRecommendedItemCard(item)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendedItemCard(Map<String, dynamic> raw) {
    final name = raw['name']?.toString() ?? 'Özel Lezzet';
    final price = double.tryParse(raw['price']?.toString() ?? '0') ?? 0.0;
    final imageUrl = raw['image_url']?.toString();
    final categoryName = raw['category_name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceLight,
                        child: const Icon(Icons.restaurant_rounded, color: AppColors.textMuted, size: 20),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(Icons.restaurant_rounded, color: AppColors.textMuted, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categoryName.isNotEmpty)
                  Text(
                    categoryName.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₺${price.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => _addRecommendedToCart(raw),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Ekle',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
