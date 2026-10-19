import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds & Surfaces (Warm Culinary Gourmet Light)
  static const Color background = Color(0xFFF5F4F1); // Warm gourmet cream linen
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF0EFEA);

  // Vibrant Culinary Gourmet Accents (Paprika Orange & Warm Amber)
  static const Color primary = Color(0xFFF2541B); // Appetizing Paprika Orange (Trendyol/Getir/Yemeksepeti)
  static const Color primaryLight = Color(0xFFFFECE5); // Soft Peach Tint
  static const Color primaryDark = Color(0xFFD43C05);
  static const Color accent = Color(0xFFF2541B);
  static const Color coral = Color(0xFFF2541B);
  static const Color gold = Color(0xFFFFC529); // Warm Gold Amber
  static const Color goldLight = Color(0xFFFFFBEB);
  static const Color emerald = Color(0xFF12A150); // Fresh Botanical Green
  static const Color cyan = Color(0xFF0284C7);
  static const Color cyanGlow = Color(0xFF38BDF8);
  static const Color indigo = Color(0xFF6366F1);
  static const Color purpleTag = Color(0xFFF3E8FF);

  // Status & Feedback
  static const Color success = Color(0xFF12A150);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Text Colors (High Contrast Deep Charcoal Ink & Slate)
  static const Color textPrimary = Color(0xFF16171C);
  static const Color textSecondary = Color(0xFF5C606B);
  static const Color textMuted = Color(0xFF9A9EA8);

  static const Color border = Color(0xFFECEAE6);
  static const Color borderLight = Color(0xFFF3F4F6);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Gradients (Vibrant, Appetizing & Modern)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF2541B), Color(0xFFFF6E40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFFF2541B), Color(0xFFEA4812)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAF9F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFFF2541B), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient promoGradient = LinearGradient(
    colors: [Color(0xFFF2541B), Color(0xFFFF7043)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
