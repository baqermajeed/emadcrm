# Emad CRM — نظام إدارة مركز مبيعات مجمع سكني

Flutter + FastAPI + MongoDB

## الأدوار

| المستخدم | اسم الدخول | الصلاحيات |
|---|---|---|
| كول سنتر | `callcenter` | إدخال الحجوزات |
| استقبال | `reception` | تأكيد الحضور، ملفات الزبائن، زيارات، صفقات، حجوزات دور، مستمسكات |
| مبيعات | `sales1` / `sales2` | زبائنه فقط + إضافة صفقة |
| مدير | `manager` | تقارير كلية + لكل موظف |

كلمة المرور لجميع الحسابات التجريبية: `123456`

## تشغيل الـ Backend

1. شغّل MongoDB على `localhost:27017`
2. يُفضّل Python 3.11 أو 3.12 (متوافق أيضاً مع 3.14 بإصدارات الحزم الحالية)
3. من مجلد `backend`:

```bash
py -3.12 -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python seed.py
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Docs: http://127.0.0.1:8000/docs
- Health: http://127.0.0.1:8000/health

## تشغيل الـ Flutter

```bash
cd frontend_desc
flutter pub get
flutter run
```

عنوان الـ API الافتراضي في `lib/core/constants.dart`:

- Windows / Chrome / Desktop: `http://127.0.0.1:8000`
- Android Emulator: غيّره إلى `http://10.0.2.2:8000`
- جهاز حقيقي: ضع IP جهازك على الشبكة

أو عند التشغيل:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## الهيكلة

### backend
`models` · `schemas` · `services` · `routers` · `utils`

### frontend_desc
`controllers` · `core` · `models` · `services` · `utils` · `widgets` · `screens`

## تدفق العمل

1. الكول سنتر يضيف حجز (اسم، هاتف، محافظة، المصدر، تاريخ الحضور)
2. الاستقبال يرى الحجوزات المعلقة ويؤكد الحضور مع تعيين موظف مبيعات → يُنشأ بروفايل زبون + أول زيارة
3. الاستقبال يحدّث البيانات، يضيف زيارات، صفقات، حجز دار، ويرفع عقود/مستمسكات
4. المبيعات يرى زبائنه ويضيف صفقات بيع
5. المدير يرى لوحة إحصائيات عامة وتقارير لكل موظف
