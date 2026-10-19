# Qordy Guest (Müşteri App)

> **Next-Generation Digital Dining, Contactless Table Ordering & Loyalty Platform**  
> Powered by [Qordy.com](https://qordy.com)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://qordy.com)
[![State Management](https://img.shields.io/badge/State-Riverpod%202.x-5E50F9?style=for-the-badge)](https://riverpod.dev)
[![UI/UX](https://img.shields.io/badge/Design-Luxury%20Dark%20Executive-FFB300?style=for-the-badge)](https://qordy.com)
[![Website](https://img.shields.io/badge/Official%20Website-qordy.com-00B4D8?style=for-the-badge)](https://qordy.com)

---

## 📌 Overview

**Qordy Guest** (`musteri_app`) is the consumer-facing mobile experience designed for premium restaurants, bistros, lounges, and cafes connected to the [Qordy Hospitality Cloud](https://qordy.com).

It empowers diners with seamless QR table check-in, an interactive visual menu with video showcases, instant table ordering directly into the kitchen, waiter service calling, real-time ticket tracking, and gamified loyalty rewards.

---

## 🌟 Key Features & Modules

### 📲 1. Table QR Check-In & Service (`table_service`)
* **Hardware-Accelerated Scanner**: Instant table QR recognition via `mobile_scanner`.
* **Smart Session Coordinator (`tableSessionProvider`)**: Binds diners to specific floor zones (Terrace, Salon, Garden) and manages party size.
* **One-Tap Service Calls**: Ping servers for water, assistance, or bill requests directly to waiter el-terminals.
* **Instant Wi-Fi Access**: On-tap guest Wi-Fi connection wizard (`wifi_connect_sheet`).

### 📖 2. Visual & Interactive Digital Menu (`menu`)
* **Rich Product Showcases**: Smooth image caching (`cached_network_image`), dietary badges, and portion options.
* **Video Menu Preview (`video_player`)**: High-impact chef specialty videos embedded within product cards.
* **Allergen & Customization Engine**: Ingredient exclusions, cooking preferences, and preparation notes.

### 🛒 3. Cart & Kitchen Order Dispatch (`cart`)
* **Flexible Cart Management**: Real-time pricing calculations, quantity updates, and bundle selections.
* **Direct Order Pipeline**: Orders stream instantly to kitchen display screens (KDS) upon customer confirmation.

### 📍 4. Real-Time Order Tracking (`tracking`)
* **Live Status Pipeline**: Real-time visual progress (*Received ➔ Cooking ➔ Serving ➔ Complete*).
* **Push Notifications**: Proactive updates delivered via `CustomerNotificationService`.

### 🎡 5. Gamified Loyalty & Rewards (`wheel`, `coupons`)
* **Mascot Fortune Wheel (`chef_mascot_wheel_sheet`)**: Interactive animated prize wheel granting dining discounts, complimentary treats, or loyalty points.
* **Digital Coupon Wallet**: Saved promotional vouchers and membership perks.

### 👤 6. Guest Profile & Enterprise Security (`profile`, `auth`)
* **Frictionless Auth**: Phone / OTP / Password-based quick sign-in with biometric passkey support.
* **Hardware Keystore Security**: AES-encrypted token persistence via `flutter_secure_storage`.
* **Automatic Session Renewal**: Proactive JWT token refresh interceptor in `ApiClient`.

---

## 🏛️ Architecture & Directory Layout

Engineered using **Clean Architecture + Feature-First** methodology:

```text
lib/
├── main.dart                          # App lifecycle, observers & luxury dark theme bootstrap
└── src/
    ├── core/                          # Cross-cutting foundational services
    │   ├── constants/                 # API endpoints, design tokens & system constants
    │   ├── models/                    # Shared entities, cart, menu & table models
    │   ├── network/                   # Dio client, JWT auth interceptors & auto-refresh
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

## 🛠️ Quick Start

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.2` or latest stable)
* [Dart SDK](https://dart.dev)
* Android Studio / Xcode
* CocoaPods (`brew install cocoapods`)

### 1. Clone the Repository
```bash
git clone git@github.com:ilkeraydogdu/musteri_app.git
cd musteri_app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
# Production environment (https://qordy.com)
flutter run

# Staging or custom server
flutter run --dart-define=QORDY_API_BASE=https://staging.qordy.com
```

---

## 📦 Build & Deployment

```bash
# Android Release APK:
./build_apk.sh

# iOS Simulator:
./build_ios.sh --simulator

# iOS App Store / TestFlight IPA:
./build_ios.sh --ipa
```

---

## 🤖 Continuous Integration

* **`Qordy Müşteri CI`**: Automated linting (`flutter analyze`) and unit test verification.
* **`Build Android APK`**: GitHub Actions workflow dispatch for generating release APK packages on demand.

---

## 🌐 Enterprise & Inquiries

* **Official Website**: [https://qordy.com](https://qordy.com)
* **Company**: Qordy Hospitality & Retail Technologies
* **Copyright**: © 2026 Qordy. All rights reserved.
