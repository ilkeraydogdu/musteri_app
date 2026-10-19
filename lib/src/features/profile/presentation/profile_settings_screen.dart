import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/customer_auth_provider.dart';
import '../../coupons/presentation/coupons_screen.dart';
import '../../table_service/presentation/wifi_connect_sheet.dart';
import '../../tracking/application/past_orders_provider.dart';
import '../../welcome/application/table_session_provider.dart';
import '../application/guest_profile_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _allergy;
  late final TextEditingController _dislike;

  final List<String> _commonAllergies = ['Gluten', 'Laktoz', 'Fıstık', 'Soya', 'Yumurta', 'Deniz Ürünleri'];
  final List<String> _commonDislikes = ['Mantar', 'Soğan', 'Sarımsak', 'Acı Biber', 'Kereviz', 'Kişniş'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(guestProfileProvider);
    _name = TextEditingController(text: profile.name.isNotEmpty ? profile.name : 'Gurme Misafir');
    _phone = TextEditingController(text: profile.phone.isNotEmpty ? profile.phone : '0555 123 45 67');
    _allergy = TextEditingController(text: profile.allergies.join(', '));
    _dislike = TextEditingController(text: profile.dislikes.join(', '));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _allergy.dispose();
    _dislike.dispose();
    super.dispose();
  }

  List<String> _split(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _toggleAllergy(String item) {
    HapticFeedback.selectionClick();
    final current = _split(_allergy.text);
    if (current.contains(item)) {
      current.remove(item);
    } else {
      current.add(item);
    }
    setState(() {
      _allergy.text = current.join(', ');
    });
  }

  void _toggleDislike(String item) {
    HapticFeedback.selectionClick();
    final current = _split(_dislike.text);
    if (current.contains(item)) {
      current.remove(item);
    } else {
      current.add(item);
    }
    setState(() {
      _dislike.text = current.join(', ');
    });
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(guestProfileProvider.notifier);
    await notifier.saveIdentity(name: _name.text, phone: _phone.text);
    await notifier.setAllergies(_split(_allergy.text));
    await notifier.setDislikes(_split(_dislike.text));
    setState(() {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Profil ve damak tercihleriniz kaydedildi!',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthProvider);
    final session = ref.watch(tableSessionProvider);
    final ordersAsync = ref.watch(pastOrdersProvider);
    final couponsAsync = ref.watch(couponsProvider);

    final ordersCount = ordersAsync.maybeWhen(
      data: (orders) => orders.length,
      orElse: () => 0,
    );
    final couponsCount = couponsAsync.maybeWhen(
      data: (coupons) => coupons.length,
      orElse: () => session.campaigns.length,
    );
    final dynamicPoints = auth.loyaltyPoints > 0
        ? auth.loyaltyPoints
        : ordersAsync.maybeWhen(
            data: (orders) => orders.fold<int>(
              0,
              (sum, o) => sum + (o.totalAmount * 0.05).round(),
            ),
            orElse: () => 120,
          );

    final activeAllergies = _split(_allergy.text);
    final activeDislikes = _split(_dislike.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Screen Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hesabım',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'VIP GURME',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. VIP Customer Card (iOS ContinuousRectangleBorder Squircle)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(42),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 1),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.person_fill, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name.text.isNotEmpty ? _name.text : 'Misafir Gurme',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _phone.text.isNotEmpty ? _phone.text : 'Giriş Yapılmadı',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: session.isSeated
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                session.isSeated
                                    ? '● ${session.tableName} (${session.zoneName}) Aktif'
                                    : '○ ${session.venueName} · Masa Seçilmedi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: session.isSeated
                                      ? const Color(0xFF10B981)
                                      : AppColors.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),

                  // Quick Stats Row (Live Data)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/past-orders');
                        },
                        child: _buildProfileStat(
                          '$ordersCount',
                          'Sipariş',
                          CupertinoIcons.doc_text_fill,
                        ),
                      ),
                      Container(width: 1, height: 28, color: AppColors.border),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.go('/coupons');
                        },
                        child: _buildProfileStat(
                          '$dynamicPoints',
                          'Q-Puan',
                          CupertinoIcons.star_circle_fill,
                        ),
                      ),
                      Container(width: 1, height: 28, color: AppColors.border),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.go('/coupons');
                        },
                        child: _buildProfileStat(
                          '$couponsCount',
                          'Kupon',
                          CupertinoIcons.ticket_fill,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 2. Personal Information Fields
            Text(
              'Kişisel Bilgiler',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Telefon Numarası',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
              ),
            ),
            const SizedBox(height: 22),

            // 3. Dining Preferences & Allergies
            Text(
              'Damak & Alerji Tercihleri',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Şefimiz ve mutfak ekibi siparişlerinizde bu hassasiyetleri ön planda tutar.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Allergies
            Text(
              'Alerjilerim',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonAllergies.map((allergy) {
                final isSelected = activeAllergies.contains(allergy);
                return GestureDetector(
                  onTap: () => _toggleAllergy(allergy),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEF4444).withValues(alpha: 0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFEF4444) : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.warning_amber_rounded : Icons.add_rounded,
                          color: isSelected ? const Color(0xFFEF4444) : AppColors.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          allergy,
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFFEF4444) : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Dislikes
            Text(
              'Sevmediğim Malzemeler',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonDislikes.map((item) {
                final isSelected = activeDislikes.contains(item);
                return GestureDetector(
                  onTap: () => _toggleDislike(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryLight : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_rounded : Icons.add_rounded,
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item,
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tercihlerimi Kaydet',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Action Tiles Section
            Text(
              'Hızlı İşlemler',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.history_rounded,
              title: 'Geçmiş Siparişlerim',
              subtitle: 'Önceki restoran ve masa siparişleriniz',
              onTap: () => context.push('/past-orders'),
            ),
            _buildActionTile(
              icon: Icons.wifi_rounded,
              title: 'Masa Wi-Fi Şifresi',
              subtitle: 'İşletme kablosuz ağına anında bağlanın',
              onTap: () => WifiConnectSheet.show(context),
            ),
            _buildActionTile(
              icon: Icons.room_service_rounded,
              title: 'Garson & Servis Talebi',
              subtitle: 'Su, sos, peçete veya hesap isteyin',
              onTap: () => context.push('/service'),
            ),
            _buildActionTile(
              icon: Icons.info_outline_rounded,
              title: 'Qordy Müşteri Hakkında',
              subtitle: 'Sürüm 1.0.0 · Gurme Gastronomi Deneyimi',
              onTap: () {},
            ),

            if (auth.isLoggedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(customerAuthProvider.notifier).logout(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
                ),
                child: const Text('Oturumu Kapat'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
      ),
    );
  }
}
