## uzita – سرویس مدیریت دستگاه و مأموریت‌ها

این پروژه یک اپلیکیشن Flutter است که برای مدیریت دستگاه‌ها، مأموریت‌های سرویس‌کاران، راننده‌ها، درخواست‌های سرویس و پنل مدیران سازمان طراحی شده است.  
اپ هم به‌صورت موبایل (Android / iOS) و هم به‌صورت **PWA** (نسخه تحت وب نصب‌پذیر) قابل استفاده است.

---

## معماری و تکنولوژی‌ها

- **Flutter 3 (channel stable)** برای UI چندسکویی
- **Dart 3**
- **REST API** با آدرس پایه `apiBaseUrl` که در `lib/api_config.dart` تنظیم می‌شود
- پشتیبانی از:
  - **تکنسین / سرویس‌کار**
  - **مدیر سازمان سرویس‌کار**
  - **راننده**
  - مدیر و کاربران عادی

---

## اجرای پروژه در حالت توسعه

### پیش‌نیازها

- نصب Flutter 3 (کانال stable)
- Android SDK / Xcode (در صورت نیاز به موبایل)

### اجرای موبایل / دسکتاپ

```bash
flutter pub get
flutter run
```

### اجرای وب (dev)

```bash
flutter run -d chrome
```

در صورت نیاز می‌توانید `API_BASE_URL` را برای محیط توسعه نیز با `--dart-define` تنظیم کنید.

---

## ساخت نسخه‌های مختلف

### Android (APK)

```bash
flutter build apk --release
```

### iOS (archive)

```bash
flutter build ios --release
```

### Web / PWA

همان‌طور که بالاتر گفته شد:

```bash
flutter build web --release --base-href /pwa/
```

و سپس فایل `uzita-pwa-build.zip` را روی سرور قرار دهید.

---

## ساختار کلی ماژول‌ها (خلاصه)

- `lib/screens/`:
  - `home_screen.dart` – داشبورد اصلی بر اساس نقش کاربر
  - `technician_tasks_screen.dart`, `technician_task_detail_screen.dart` – مأموریت‌های تکنسین
  - `technician_reports_screen.dart` – گزارشات تکنسین / مدیر سازمان سرویس‌کار
  - `driver_missions_screen.dart`, `driver_reports_screen.dart`, `driver_public_loads_screen.dart` – بخش راننده
  - `service_list_screen.dart`, `send_service_screen.dart` – لیست و درخواست‌های سرویس
  - `transport_new_request_screen.dart` – درخواست جدید کالا
  - سایر صفحات پروفایل، تیکت‌ها، کاربران و ...
- `lib/utils/`:
  - `shared_bottom_nav.dart` – نوار ناوبری پایین مشترک با منطق نقش‌ها
  - `shared_drawer.dart` – منوی کناری مشترک
- `lib/services.dart`:
  - تعریف رنگ‌ها، ثابت‌ها و تابع `getLogicalUserLevel` برای نگاشت سطح‌های بک‌اند به سه سطح منطقی (مدیر، کاربر/سرویس‌کار، راننده).

---

## نکات توسعه

- برای نقش‌ها، همیشه از `getLogicalUserLevel(rawLevel)` استفاده کنید تا منطق سه‌سطحی (۱: مدیر، ۲: کاربر/سرویس‌کار، ۳: راننده) ثابت بماند.
- در ناوبری پایین و منوی سایدبار از کامپوننت‌های مشترک (`SharedBottomNavigation` و `SharedAppDrawer`) استفاده شده تا رفتار بین صفحات هماهنگ باشد.
- برای درخواست‌های شبکه همیشه قبل از call از `SessionManager().onNetworkRequest()` استفاده می‌شود تا مدیریت سشن و خطاها یکنواخت باشد.

---

## راهنما

- داکیومنت اصلی Flutter: <https://docs.flutter.dev/>
- برای تغییر آدرس API: `lib/api_config.dart`
- برای تغییر تنظیمات PWA (آیکن‌ها، manifest و ...) به پوشه `web/` مراجعه کنید. 
