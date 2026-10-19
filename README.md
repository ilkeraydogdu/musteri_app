# 🍽️ Qordy Müşteri (Dijital Menü, Masadan Sipariş & Sadakat)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://flutter.dev)
[![State Management](https://img.shields.io/badge/State-Riverpod%202.x-5E50F9?style=for-the-badge)](https://riverpod.dev)
[![UI/UX](https://img.shields.io/badge/Design-Luxury%20Dark%20Theme-FFB300?style=for-the-badge)](https://flutter.dev)

**Qordy Müşteri**, restoran, kafe ve bistro misafirleri için tasarlanmış yeni nesil dijital menü, masadan temassız sipariş, canlı sipariş takibi ve oyunlaştırılmış sadakat (çarkıfelek, kuponlar) mobil uygulamasıdır.

---

## 🌟 Öne Çıkan Özellikler ve Modüller

### 1. 📲 Masa QR Servisi & Masaya Oturma (`table_service`)
* **Hızlı QR Tarayıcı (`MobileScanner`)**: Masa üzerindeki dinamik karekodu okutarak anında masaya bağlanma.
* **Oturum Yönetimi (`tableSessionProvider`)**: Masa adı, alan bilgisi (Teras, Salon, Bahçe) ve misafir sayısı ile anlık oturum başlatma.
* **Garson Çağırma & Hesap İsteme**: Tek tuşla garson terminaline ve kasaya anlık bildirim gönderme.

### 2. 📖 İnteraktif & Zengin Dijital Menü (`menu`)
* **Kategori & Ürün Keşfi**: Yüksek çözünürlüklü görseller (`cached_network_image`), ürün varyasyonları, porsiyon ve malzeme seçenekleri.
* **Video Menü Entegrasyonu (`video_player`)**: Şefin önerileri ve imza lezzetler için video içerik gösterimi.
* **Arama & Filtreleme**: Alerjen uyarıları, popüler ürünler ve şefin tavsiyeleri.

### 3. 🛒 Sepet & Sipariş Yönetimi (`cart`)
* **Özelleştirilebilir Sepet**: Ürün adetleri, porsiyon seçimleri ve özel hazırlama notları.
* **Masaya Sipariş Verme**: Tek dokunuşla siparişi işletme mutfak ve POS sistemine iletme.

### 4. 📍 Canlı Sipariş Durum Takibi (`tracking`)
* **Aşama Aşama Takip**: *Sipariş Alındı ➔ Hazırlanıyor ➔ Serviste ➔ Afiyet Olsun* adımlarının anlık görsel takibi.
* **Anlık Bildirimler (`CustomerNotificationService`)**: Sipariş durumu değiştiğinde yerel ve anlık bildirimler.

### 5. 🎡 Sadakat, Ödül Çarkı & Kuponlar (`wheel`, `coupons`)
* **Kazanma Çarkı (Lucky Wheel)**: Misafirlerin sipariş verdikçe veya ziyarete göre indirim, tatlı/içecek hediyesi kazanabileceği çarkıfelek.
* **Kişiselleştirilmiş Kuponlar**: İndirim kodları, puan biriktirme ve profil cüzdanı.

### 6. 👤 Profil & Geçmiş Siparişler (`profile`, `auth`)
* **Hızlı Giriş**: Telefon / OTP / Şifreli müşteri profili.
* **Geçmiş Siparişler & Faturalar**: Önceki ziyaretlerin detaylı dökümü ve favorilere ekleme.
* **Şifreli Güvenlik (`flutter_secure_storage`)**: JWT access ve refresh token'larının güvenli hafızada saklanması, otomatik token yenileme (`ApiClient`).

---

## 🏛️ Mimari ve Proje Yapısı

Uygulama, sürdürülebilir ve modüler **Clean Architecture + Feature-First** prensipleriyle yapılandırılmıştır:

```text
lib/
├── main.dart                          # Uygulama başlangıcı, global observer ve tema yapılandırması
└── src/
    ├── core/                          # Çekirdek altyapı
    │   ├── constants/                 # API uç noktaları, renk ve metrik sabitleri
    │   ├── models/                    # Global veri modelleri
    │   ├── network/                   # Dio tabanlı ApiClient, JWT auth interceptor ve refresh döngüsü
    │   ├── routing/                   # GoRouter yönlendirme mimarisi
    │   ├── services/                  # Bildirim ve yerel depolama servisleri
    │   ├── theme/                     # Luxury Dark tema sistemi (AppColors, AppTheme)
    │   └── utils/                     # Formatlama ve yardımcı sınıflar
    └── features/                      # Özellik bazlı modüller
        ├── auth/                      # Müşteri oturum açma ve kayıt akışları
        ├── cart/                      # Sepet state yönetimi ve sipariş tamamlama
        ├── coupons/                   # Kupon ve indirim yönetimi
        ├── menu/                      # Kategori, ürün listesi ve detay ekranları
        ├── profile/                   # Kullanıcı profili, sipariş geçmişi ve ayarlar
        ├── table_service/             # QR okuma, masa oturumu, garson çağırma
        ├── tracking/                  # Gerçek zamanlı sipariş durum ekranı
        ├── welcome/                   # Hoşgeldiniz ve karşılama akışları
        └── wheel/                     # Gamification & çarkıfelek animasyonlu ödül ekranı
```

---

## 🛠️ Kurulum ve Geliştirme

### Gereksinimler
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.2` veya güncel stable)
* [Dart SDK](https://dart.dev)
* Android Studio / Xcode (iOS derlemeleri için)
* CocoaPods (`brew install cocoapods`)

### 1. Depoyu Klonlayın
```bash
git clone https://github.com/ilkeraydogdu/musteri_app.git
cd musteri_app
```

### 2. Paketleri Yükleyin
```bash
flutter pub get
```

### 3. Uygulamayı Başlatın
```bash
# Geliştirme ortamında çalıştırma
flutter run

# Özel API sunucusu tanımlayarak çalıştırma
flutter run --dart-define=QORDY_API_BASE=https://staging.qordy.com
```

---

## 📦 Derleme ve Paketleme (Build & Deploy)

Kök dizinde bulunan optimize edilmiş derleme betiklerini kullanabilirsiniz:

### Android APK Derlemesi
```bash
chmod +x build_apk.sh
./build_apk.sh
```
*Çıktı konumu: `build/app/outputs/flutter-apk/app-release.apk`*

### iOS Paketleme
```bash
chmod +x build_ios.sh

# Simulator testi için:
./build_ios.sh --simulator

# App Store / TestFlight için IPA üretimi:
./build_ios.sh --ipa

# İmzalamasız yerel release derlemesi:
./build_ios.sh
```

---

## 🔄 Git & Güncelleme İş Akışı

Yeni güncellemeler yaparken aşağıdaki adımları kullanabilirsiniz:

```bash
# 1. En güncel değişiklikleri çekin
git pull origin main

# 2. Kod analizini çalıştırın
flutter analyze

# 3. Değişiklikleri sahneleyin ve commit edin
git add .
git commit -m "feat(menu): yeni tatlı kategorisi ve alerjen ikonları eklendi"

# 4. GitHub'a gönderin
git push origin main
```

---

## 🤖 GitHub Actions CI/CD

* **`Qordy Müşteri CI`**: Tüm `push` ve `pull_request` işlemlerinde otomatik statik analiz (`flutter analyze`) ve testleri doğrular.
* **`Build Android APK`**: GitHub Actions arayüzünden manuel tetikleme ile tek tıkla (`workflow_dispatch`) APK derler ve artifact olarak sunar.

---

## 📄 Lisans
Bu projenin tüm hakları **Qordy** ve **İlker Aydoğdu**'ya aittir.
