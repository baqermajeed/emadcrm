# Emad CRM Web (Next.js)

واجهة ويب `mobile-first` لمشروع Emad CRM باستخدام `React + Next.js` ومتصلة بنفس backend الحالي.

## التشغيل

```bash
cd website
npm install
npm run dev
```

افتح:

- `http://localhost:3000`

## ربط الـ API

انسخ الملف:

```bash
copy .env.local.example .env.local
```

وعدّل:

```env
BACKEND_BASE_URL=https://emadcrm.compassaccuracy.com/api
```

للتشغيل المحلي مع backend:

```env
BACKEND_BASE_URL=http://127.0.0.1:8000/api
```

ملاحظة: الواجهة تتصل عبر Proxy داخلي (`/api/backend/*`) لتفادي مشاكل CORS على المتصفح.

## المطبق حالياً

- تسجيل دخول عبر `POST /auth/login`
- تخزين `token` و`user` في `localStorage`
- توجيه حسب الدور:
  - reception -> `/reception/customers`
  - sales -> `/sales`
  - manager -> `/manager`
- واجهة موظف الاستقبال:
  - عرض قائمة الزبائن من `GET /customers`
  - بحث بالاسم/الهاتف
  - عرض بروفايل مختصر لكل زبون
