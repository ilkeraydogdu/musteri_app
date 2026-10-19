<p align="center">
  <a href="https://qordy.com">
    <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0F172A,50:1E293B,100:334155&height=200&section=header&text=Qordy%20Guest&fontSize=42&fontColor=ffffff&fontAlignY=38&desc=Digital%20Dining%2C%20Contactless%20Ordering%20%26%20Loyalty&descAlignY=60&descSize=16" width="100%"/>
  </a>
</p>

<p align="center">
  <a href="https://qordy.com">
    <img src="https://readme-typing-svg.demolab.com?font=Inter&weight=500&size=16&duration=3000&pause=1000&color=F59E0B&center=true&vCenter=true&width=620&lines=Next-Gen+Digital+Dining+%26+QR+Table+Service;Interactive+Video+Menus+%26+Modifier+Groups;Real-Time+Order+Tracking+Direct-to-Kitchen;Gamified+Mascot+Rewards+%26+Digital+Coupons" alt="Qordy Guest Typing SVG" />
  </a>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://riverpod.dev"><img src="https://img.shields.io/badge/State-Riverpod%202.x-5E50F9?style=flat-square" alt="Riverpod" /></a>
  <a href="https://qordy.com"><img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-10B981?style=flat-square&logo=apple&logoColor=white" alt="Platforms" /></a>
  <a href="https://qordy.com"><img src="https://img.shields.io/badge/Design-Luxury%20Dark%20Executive-F59E0B?style=flat-square" alt="Luxury Design" /></a>
  <a href="https://qordy.com"><img src="https://img.shields.io/badge/Official%20Platform-qordy.com-00B4D8?style=flat-square&logo=googlechrome&logoColor=white" alt="Qordy.com" /></a>
</p>

---

## Overview

**Qordy Guest** (`musteri_app`) is the consumer-facing mobile application designed for restaurants, bistros, lounges, and hospitality venues operating on the [Qordy Platform](https://qordy.com).

Engineered to elevate the in-venue guest experience, it unifies high-speed QR check-in, visual video menus, real-time ticket dispatch, waiter paging, and gamified loyalty mechanics into a luxury dark-mode mobile interface.

---

## System Architecture & Modules

| Module ID | Component | Capabilities | Primary Engine |
| :--- | :--- | :--- | :--- |
| `MOD-01` | **Table Service & QR** | Optical table check-in, zone binding, party session tracking, server paging | `MobileScanner`, `Riverpod` |
| `MOD-02` | **Digital Interactive Menu** | Video dishes, cached photo galleries, dietary modifiers, allergen alerts | `VideoPlayer`, `CachedNetworkImage` |
| `MOD-03` | **Cart & Kitchen Pipeline** | Real-time bill calculations, customized prep notes, direct KDS dispatch | `Riverpod`, `Dio` |
| `MOD-04` | **Order Lifecycle Tracking** | Stage-by-stage timeline (*Placed ➔ In Kitchen ➔ Serving ➔ Complete*) | `PushNotifications`, `ApiClient` |
| `MOD-05` | **Gamification & Loyalty** | Animated mascot prize wheel, reward coupons, digital perk wallet | `CustomAnimation`, `SecureStore` |

---

### Module 01: Table Check-In & Service Integration (`table_service`)
* **Hardware-Accelerated QR Scanning**: Instant table identification and validation via `mobile_scanner`.
* **Smart Session Coordinator (`tableSessionProvider`)**: Associates diners with venue zones (Terrace, Garden, Main Hall) and logs party headcount.
* **On-Demand Staff Calling**: Discrete pings for assistance, cutlery, or checkout directly to server el-terminals.
* **Guest Wi-Fi Setup**: Instant credential injection and connection wizard (`wifi_connect_sheet`).

### Module 02: Interactive Video & Digital Menu (`menu`)
* **Dynamic Dish Presentation**: Cached high-resolution assets (`cached_network_image`), ingredient tags, and sizing choices.
* **Embedded Video Previews (`video_player`)**: Chef specialty video reels displayed natively within product cards.
* **Allergen & Customization Filter**: Granular exclusions, dietary restrictions, and cooking temperature specifications.

### Module 03: Cart & Direct-to-Kitchen Ordering (`cart`)
* **Live Calculation Engine**: Real-time tax, modifier adjustments, and discounts.
* **Direct KDS Integration**: Verified orders route straight to designated kitchen preparation lines without manual staff intervention.

### Module 04: Real-Time Order Lifecycle Tracking (`tracking`)
* **Visual Status Pipeline**: Step-by-step progress tracking with real-time status updates.
* **Push Notifications**: Proactive updates delivered via `CustomerNotificationService`.

### Module 05: Gamified Rewards & Promotion Engine (`wheel`, `coupons`)
* **Animated Mascot Wheel (`chef_mascot_wheel_sheet`)**: Interactive prize wheel offering complimentary menu items, discounts, or loyalty points.
* **Personalized Coupon Vault**: Secure digital wallet for promo codes and redeemed perks.

### Module 06: Security & Identity Layer (`auth`, `profile`)
* **Multi-Method Authentication**: Fast SMS OTP, phone verification, and passkey biometric login.
* **Encrypted Token Management**: Hardware keystore-backed AES token persistence via `flutter_secure_storage`.
* **Proactive Session Refresh**: Seamless background JWT renewal ensuring zero disruption during checkout.

---

## Directory Layout

```text
lib/
├── main.dart                          # Application entry point, global observers & luxury dark theme
└── src/
    ├── core/                          # Cross-cutting foundational services
    │   ├── constants/                 # API endpoints, design tokens & system constants
    │   ├── models/                    # Shared entities, cart, menu & table models
    │   ├── network/                   # Dio HTTP client, JWT auth interceptors & auto-refresh
    │   ├── routing/                   # GoRouter navigation & stateful shell routes
    │   ├── services/                  # Push notification & location services
    │   ├── theme/                     # Dark Luxury theme (AppColors, AppTheme, AppTypography)
    │   └── utils/                     # Geolocation, formatting & calculation helpers
    └── features/                      # Domain features
        ├── auth/                      # Customer registration, OTP verification & guest mode
        ├── cart/                      # Cart state machine & checkout sheets
        ├── coupons/                   # Promotion & reward vouchers
        ├── menu/                      # Digital catalog, categories & product detail sheets
        ├── profile/                   # Guest account, past orders & preferences
        ├── table_service/             # QR scanner, seating coordinator & waiter calls
        ├── tracking/                  # Real-time order progress & status timeline
        ├── welcome/                   # Onboarding & location splash
        └── wheel/                     # Gamified wheel animation & reward dialogs
```

---

## Development & Deployment

### Prerequisites
* Flutter SDK `^3.13.2`
* Dart SDK `^3.x`
* Xcode / Android Studio
* CocoaPods (`brew install cocoapods` on macOS)

### Installation
```bash
# Clone the repository
git clone git@github.com:ilkeraydogdu/musteri_app.git
cd musteri_app

# Fetch dependencies
flutter pub get

# Launch application
flutter run --dart-define=QORDY_API_BASE=https://qordy.com
```

### Build Pipelines
```bash
# Android Release APK:
./build_apk.sh

# iOS Simulator:
./build_ios.sh --simulator

# iOS App Store / TestFlight IPA:
./build_ios.sh --ipa
```

---

## Continuous Integration

* **`Qordy Müşteri CI`**: Automated linting (`flutter analyze`) and unit test verification.
* **`Build Android APK`**: GitHub Actions workflow dispatch for generating release APK packages on demand.

---

## Corporate Inquiries

* **Platform Website**: [https://qordy.com](https://qordy.com)
* **Company**: Qordy Hospitality & Retail Technologies
* **Copyright**: © 2026 Qordy. All rights reserved.
