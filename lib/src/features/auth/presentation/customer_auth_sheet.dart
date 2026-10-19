import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../welcome/application/table_session_provider.dart';
import '../application/customer_auth_provider.dart';

class CustomerAuthSheet extends ConsumerStatefulWidget {
  final bool initialIsLogin;

  const CustomerAuthSheet({super.key, this.initialIsLogin = false});

  static Future<void> show(BuildContext context, {bool isLogin = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerAuthSheet(initialIsLogin: isLogin),
    );
  }

  @override
  ConsumerState<CustomerAuthSheet> createState() => _CustomerAuthSheetState();
}

class _CustomerAuthSheetState extends ConsumerState<CustomerAuthSheet> {
  late bool _isLogin;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  Timer? _debounceEmail;
  String? _emailStatusMessage;
  bool _isEmailValid = false;

  final List<String> _popularDomains = [
    '@gmail.com',
    '@hotmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@icloud.com',
  ];

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _debounceEmail?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final text = _emailController.text.trim();
    _debounceEmail?.cancel();

    if (!text.contains('@') || text.length < 5) {
      if (mounted) {
        setState(() {
          _emailStatusMessage = null;
          _isEmailValid = false;
        });
      }
      return;
    }

    _debounceEmail = Timer(const Duration(milliseconds: 350), () async {
      final res = await ref.read(customerAuthProvider.notifier).checkEmailDomain(text);
      if (!mounted) return;
      setState(() {
        if (res['valid'] == true) {
          _emailStatusMessage = '✓ Onaylı e-posta alanı (${res['domain'] ?? ''})';
          _isEmailValid = true;
        } else {
          _emailStatusMessage = res['error']?.toString() ?? 'Geçersiz e-posta';
          _isEmailValid = false;
        }
      });
    });
  }

  void _applyDomainChip(String domain) {
    final current = _emailController.text.trim();
    if (current.contains('@')) {
      final prefix = current.split('@').first;
      _emailController.text = '$prefix$domain';
    } else {
      _emailController.text = '$current$domain';
    }
    _emailController.selection = TextSelection.fromPosition(
      TextPosition(offset: _emailController.text.length),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(customerAuthProvider.notifier);
    final venueTable = ref.read(tableSessionProvider);

    if (_isLogin) {
      final success = await authNotifier.loginCustomer(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başarıyla giriş yapıldı. Hoş geldiniz!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      final success = await authNotifier.registerCustomer(
        name: _nameController.text,
        email: _emailController.text,
        phone: '+90${_phoneController.text.replaceAll(RegExp(r'\D'), '')}',
        password: _passwordController.text,
        tenantId: venueTable.venueId.isNotEmpty ? venueTable.venueId : null,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başarılı! 50 Hoş Geldin Sadakat Puanı tanımlandı 🎉'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: bottomInset > 0 ? bottomInset + 16 : MediaQuery.of(context).padding.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Segmented Tab: Giriş Yap / Kayıt Ol
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isLogin ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isLogin
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Kayıt Ol (Bonus +50 P)',
                            style: TextStyle(
                              color: !_isLogin ? Colors.white : AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isLogin ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isLogin
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Giriş Yap',
                            style: TextStyle(
                              color: _isLogin ? Colors.white : AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title and Subtitle
              Text(
                _isLogin ? 'Hesabınıza Giriş Yapın' : 'Özel Ayrıcalıklarla Tanışın',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? 'Siparişlerinizi takip edin, puanlarınızı kullanın.'
                    : 'Masada hızlı sipariş, size özel indirimler ve sadakat puanları kazanın.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Error banner if any
              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Name Field (Register only)
              if (!_isLogin) ...[
                const Text(
                  'Adınız Soyadınız',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Örn: İlker Aydoğdu',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.cyan, size: 20),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cyan, width: 1.5)),
                  ),
                  validator: (val) {
                    if (!_isLogin && (val == null || val.trim().length < 2)) {
                      return 'Lütfen geçerli bir ad soyad giriniz.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Email Field with instant validation
              const Text(
                'E-Posta Adresiniz',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ornek@gmail.com',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.cyan, size: 20),
                  suffixIcon: _emailStatusMessage != null
                      ? Icon(
                          _isEmailValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _isEmailValid ? AppColors.success : Colors.amber,
                          size: 20,
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cyan, width: 1.5)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'E-posta adresi zorunludur.';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Geçerli bir e-posta adresi yazınız.';
                  }
                  return null;
                },
              ),

              // Email domain chips
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _popularDomains.map((domain) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          domain,
                          style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: AppColors.surfaceElevated,
                        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        onPressed: () => _applyDomainChip(domain),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Email status message
              if (_emailStatusMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _emailStatusMessage!,
                  style: TextStyle(
                    color: _isEmailValid ? AppColors.success : Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Phone Field with +90 Turkish formatting (Register only)
              if (!_isLogin) ...[
                const Text(
                  'Telefon Numarası',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    _TurkishPhoneInputFormatter(),
                  ],
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: '(5XX) XXX XX XX',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: const EdgeInsets.only(right: 8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇹🇷', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 6),
                          Text(
                            '+90',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text('|', style: TextStyle(color: AppColors.border, fontSize: 16)),
                        ],
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cyan, width: 1.5)),
                  ),
                  validator: (val) {
                    if (!_isLogin) {
                      final digits = (val ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10) {
                        return '10 haneli telefon numaranızı girin (5XX...).';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Password Field
              const Text(
                'Şifre',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.cyan, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cyan, width: 1.5)),
                ),
                validator: (val) {
                  if (val == null || val.length < 6) {
                    return 'Şifre en az 6 karakter olmalıdır.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: authState.isLoading ? null : _handleSubmit,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isLogin ? 'Giriş Yap' : 'Kayıt Ol ve Puan Kazan (+50 P)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Guest continue without login
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Üye olmadan devam et',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurkishPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (text.startsWith('0')) {
      text = text.substring(1);
    }
    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 0) buffer.write('(');
      buffer.write(text[i]);
      if (i == 2) buffer.write(') ');
      if (i == 5) buffer.write(' ');
      if (i == 7) buffer.write(' ');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
