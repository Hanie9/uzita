<div dir="rtl" align="right">

# uzita — مدیریت دستگاه و مأموریت‌ها

اپلیکیشن **Flutter** برای مدیریت دستگاه‌ها، درخواست‌های سرویس، مأموریت‌های تکنسین، گزارش‌ها، حمل‌ونقل و پنل مدیران سازمان.  
نسخه **۱.۴.۵** — پشتیبانی از **فارسی** و **انگلیسی** (راست‌به‌چپ / چپ‌به‌راست).

| پلتفرم | وضعیت |
|--------|--------|
| Android | ✅ |
| iOS | ✅ |
| Web / PWA | ✅ |
| Windows / Linux / macOS | قابل اجرا در حالت توسعه |

---

## قابلیت‌های اصلی

### تکنسین (سرویس‌کار)
- لیست **مأموریت‌های شخصی** (`/technician/tasks`)
- جزئیات مأموریت: موضوع، موقعیت، گارانتی، بررسی (قطعات، تعرفه‌ها، هزینه‌ها)
- مراحل کار: تاریخ مراجعه اول → فرم بررسی → گزارش و تأیید نهایی
- گزارش‌های انجام‌شده (`/technician-reports`)

### سرگروه تکنسین (مدیر سازمان)
- مأموریت‌های سازمانی (`/technician-organ/tasks`) — تخصیص به تکنسین
- مشاهدهٔ جزئیات فقط‌خواندنی (بدون فرم مراجعه/گزارش)
- مأموریت‌های شخصی خود سرگروه در همان صفحه

### راننده
- مأموریت‌ها، گزارش‌ها، بارهای عمومی

### سایر نقش‌ها
- درخواست و پیگیری سرویس، دستگاه‌ها، تیکت، کاربران، حمل‌ونقل و پروفایل

---

## فناوری‌ها

- **Flutter 3** (کانال stable) و **Dart 3.8+**
- **Provider** — تنظیمات و زبان
- **REST API** — آدرس پایه در `lib/api_config.dart`
- **shared_preferences** / **flutter_secure_storage** — نشست و امنیت
- **shamsi_date** — تقویم شمسی در UI فارسی
- فونت **وزیر** (`assets/fonts/`)

---

## پیش‌نیازها

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable)
- برای Android: Android SDK و JDK
- برای iOS (روی macOS): Xcode
- برای وب: `flutter config --enable-web`

بررسی محیط:

```bash
flutter doctor
```

---

## پیکربندی API

پیش‌فرض:

```text
https://device-control.liara.run/api
```

تغییر در زمان build یا run:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

فایل مرجع: `lib/api_config.dart`

---

## اجرا در حالت توسعه

```bash
cd uzita
flutter pub get
flutter run
```

اجرای وب:

```bash
flutter run -d chrome
```

لیست دستگاه‌ها:

```bash
flutter devices
```

---

## ساخت نسخهٔ انتشار

### Android (APK)

```bash
flutter build apk --release
```

خروجی معمول:

```text
build/app/outputs/flutter-apk/app-release.apk
```

#### محدودیت شبکه (ایران) — Gradle

در صورت قطع یا کندی `plugins.gradle.org` / Maven مرکزی:

- آینه‌ها و `offline-maven-repo` در `android/settings.gradle.kts` و `android/gradle.properties`
- اسکریپت گرم‌کردن کش و export:

```bash
cd android
./build-offline-maven-repo.sh --warm
```

جزئیات بیشتر در همان پوشهٔ `android/`.

### Web / PWA

```bash
flutter build web --release --base-href /pwa/
```

استقرار خودکار با **GitHub Actions** (شاخهٔ `main`): `.github/workflows/deploy-pages.yml`  
متغیر مخفی `API_BASE_URL` را در تنظیمات repository تنظیم کنید.

### iOS

```bash
flutter build ios --release
```

سپس Archive از Xcode.

---

## ساختار پروژه (خلاصه)

```text
lib/
├── main.dart                 # مسیرها، تم، زبان، مدیریت نشست
├── api_config.dart           # آدرس API
├── app_localizations.dart    # ترجمهٔ fa / en
├── services.dart             # رنگ‌ها، سطوح کاربر
├── screens/                  # صفحات اپ
│   ├── technician_tasks_screen.dart
│   ├── technician_task_detail_screen.dart
│   ├── technician_organ_tasks_screen.dart
│   ├── technician_reports_screen.dart
│   ├── driver_* / service_* / home_screen.dart ...
├── utils/
│   ├── technician_task_utils.dart   # نرمال‌سازی JSON مأموریت
│   ├── shared_bottom_nav.dart
│   ├── shared_drawer.dart
│   └── http_with_session.dart
└── services/
    └── session_manager.dart

android/          # Gradle، آینهٔ Maven، NDK
web/              # PWA، manifest، آیکن
assets/           # فونت و آیکن SVG
```

---

## زبان و جهت UI

- زبان‌ها: **فارسی (`fa`)** و **انگلیسی (`en`)**
- در `main.dart` جهت متن از روی locale تنظیم می‌شود (RTL برای فارسی)
- انتخاب زبان از تنظیمات اپ (`SettingsProvider`)

---

## نکات توسعه

1. **سطح کاربر:** از `getLogicalUserLevel(level)` در `lib/services.dart` استفاده کنید (۱ مدیر، ۲ سرویس‌کار/تکنسین، ۳ راننده).
2. **شبکه:** قبل از درخواست HTTP، `SessionManager().onNetworkRequest()` را فراخوانی کنید.
3. **ناوبری:** `SharedBottomNavigation` و `SharedAppDrawer` برای یکنواختی بین صفحات.
4. **مأموریت سازمانی:** با `from_organ_assign_list: true` صفحهٔ جزئیات فقط‌خواندنی می‌شود.
5. **بررسی مأموریت:** کارت جزئیات قطعات/تعرفه فقط **بعد از ارسال فرم** (یا دادهٔ از پیش‌آمده از API) نمایش داده می‌شود، نه هنگام انتخاب در فرم.

---

## تست

```bash
flutter test
```

---

## منابع

- [مستندات Flutter](https://docs.flutter.dev/)
- [راهنمای استقرار وب Flutter](https://docs.flutter.dev/deployment/web)
- [Liara — بک‌اند نمونهٔ پروژه](https://device-control.liara.run/)

---

## مجوز و مخزن

پروژهٔ خصوصی (`publish_to: 'none'` در `pubspec.yaml`).  
برای مشارکت، از شاخهٔ feature و Pull Request استفاده کنید.

</div>
