# پراکسی نشان برای بک‌اند

کلید `service.*` فقط از **دامنه/سرور مجاز** کار می‌کند — نه مستقیم از APK اندروید.

## نصب روی device-control.liara.run

1. فایل‌های `neshan_proxy_views.py` و `neshan_proxy_urls.py` را در اپ Django (transport) کپی کنید.
2. مسیرها را به `urlpatterns` اضافه کنید (زیر `/api/`):
   - `GET /api/transport/neshan/geocode`
   - `GET /api/transport/neshan/route`
   - `GET /api/transport/neshan/static-arc`
3. در Liara متغیر محیطی بگذارید: `NESHAN_API_KEY=service.xxx`
4. در پنل نشان → کلید سرویس → **دامنه‌های مجاز**:
   - `device-control.liara.run`
   - `ellaro.liara.run`
   - **نه** `com.example.uzita` (این نام پکیج است، نه دامنه)

## تست

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://device-control.liara.run/api/transport/neshan/geocode?address=تهران"
```

HTTP 200 = آماده. HTTP 404 = هنوز deploy نشده.
