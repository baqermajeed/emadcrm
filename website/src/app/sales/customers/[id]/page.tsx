"use client";

import { ChangeEvent, useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import {
  createDeal,
  createVisit,
  getCustomer,
  listCustomerDeals,
  listCustomerVisits,
  updateCustomer,
  uploadCustomerDocument
} from "@/lib/api";
import { useProtectedPage } from "@/lib/auth";
import type { Customer, Deal, DocumentOut, Visit } from "@/types";
import styles from "./customer.module.css";

const BACKEND_ORIGIN = process.env.NEXT_PUBLIC_BACKEND_ORIGIN ?? "https://emadcrm.compassaccuracy.com";

const STATUS_LABELS: Record<string, string> = {
  buyer: "تم الشراء",
  potential: "محتمل",
  reservation: "زيارة مجدولة",
  hesitant: "متردد",
  not_interested: "غير مهتم",
  interested: "مهتم"
};

const STATUS_OPTIONS = Object.entries(STATUS_LABELS);

const PAYMENT_TYPE_LABELS: Record<string, string> = {
  cash: "كاش",
  half_cash: "نصف كاش",
  installments: "دفعات"
};

const HOUSE_TYPE_LABELS: Record<string, string> = {
  house: "دار",
  villa: "فيلا"
};

function resolveAssetUrl(url: string): string {
  if (/^https?:\/\//i.test(url)) return url;
  if (url.startsWith("//")) return `https:${url}`;
  if (url.startsWith("/")) return `${BACKEND_ORIGIN}${url}`;
  return `${BACKEND_ORIGIN}/${url}`;
}

function formatDateTime(value: string | null | undefined): string {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleString("ar-IQ", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });
}

function formatMoney(value: number): string {
  return new Intl.NumberFormat("en-US").format(Math.round(value));
}

function isImageDocument(doc: DocumentOut): boolean {
  return doc.content_type.startsWith("image/");
}

export default function SalesCustomerProfilePage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const customerId = params?.id;
  const { token, loading } = useProtectedPage(["sales"]);

  const [customer, setCustomer] = useState<Customer | null>(null);
  const [fetching, setFetching] = useState(false);
  const [loadingDetails, setLoadingDetails] = useState(false);
  const [error, setError] = useState("");
  const [visits, setVisits] = useState<Visit[]>([]);
  const [deals, setDeals] = useState<Deal[]>([]);

  const [statusValue, setStatusValue] = useState("potential");
  const [statusSaving, setStatusSaving] = useState(false);

  const [noteText, setNoteText] = useState("");
  const [noteSaving, setNoteSaving] = useState(false);

  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadingDoc, setUploadingDoc] = useState(false);
  const [visitSaving, setVisitSaving] = useState(false);
  const [visitNote, setVisitNote] = useState("");
  const [dealSaving, setDealSaving] = useState(false);
  const [dealForm, setDealForm] = useState({
    houseType: "house",
    paymentType: "cash",
    totalPrice: "",
    downPayment: "",
    houseArea: "",
    block: "",
    houseNumber: "",
    notes: ""
  });

  const imageInputRef = useRef<HTMLInputElement | null>(null);
  const docInputRef = useRef<HTMLInputElement | null>(null);

  const images = useMemo(
    () => (customer?.documents ?? []).filter((doc) => isImageDocument(doc)).reverse(),
    [customer]
  );
  const files = useMemo(
    () => (customer?.documents ?? []).filter((doc) => !isImageDocument(doc)).reverse(),
    [customer]
  );

  async function loadCustomer() {
    if (!token || !customerId) return;
    setFetching(true);
    setError("");
    try {
      const data = await getCustomer(token, customerId);
      setCustomer(data);
      setStatusValue(data.status ?? "potential");
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل ملف الزبون");
    } finally {
      setFetching(false);
    }
  }

  async function loadDetails() {
    if (!token || !customerId) return;
    setLoadingDetails(true);
    try {
      const [visitData, dealData] = await Promise.all([
        listCustomerVisits(token, customerId),
        listCustomerDeals(token, customerId)
      ]);
      setVisits(visitData);
      setDeals(dealData);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل تفاصيل ملف الزبون");
    } finally {
      setLoadingDetails(false);
    }
  }

  useEffect(() => {
    void loadCustomer();
    void loadDetails();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, customerId]);

  async function saveStatus() {
    if (!token || !customerId || !customer) return;
    setStatusSaving(true);
    setError("");
    try {
      const updated = await updateCustomer(token, customerId, { status: statusValue });
      setCustomer(updated);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحديث الحالة");
    } finally {
      setStatusSaving(false);
    }
  }

  async function addNote() {
    if (!token || !customerId || !customer || !noteText.trim()) return;
    setNoteSaving(true);
    setError("");
    try {
      const stamped = `[${new Date().toLocaleString("ar-IQ")}] ${noteText.trim()}`;
      const merged = customer.notes ? `${customer.notes}\n${stamped}` : stamped;
      const updated = await updateCustomer(token, customerId, { notes: merged });
      setCustomer(updated);
      setNoteText("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إضافة الملاحظة");
    } finally {
      setNoteSaving(false);
    }
  }

  async function uploadFile(file: File, kind: "image" | "doc") {
    if (!token || !customerId) return;
    if (kind === "image") setUploadingImage(true);
    if (kind === "doc") setUploadingDoc(true);
    setError("");
    try {
      await uploadCustomerDocument(token, customerId, file, kind === "image" ? "صورة للزبون" : "مستند");
      await loadCustomer();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر رفع الملف");
    } finally {
      if (kind === "image") setUploadingImage(false);
      if (kind === "doc") setUploadingDoc(false);
    }
  }

  function onImagePicked(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    void uploadFile(file, "image");
  }

  function onDocPicked(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    void uploadFile(file, "doc");
  }

  async function addVisit() {
    if (!token || !customerId || !visitNote.trim()) return;
    setVisitSaving(true);
    setError("");
    try {
      await createVisit(token, {
        customer_id: customerId,
        notes: visitNote.trim()
      });
      setVisitNote("");
      await loadDetails();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إضافة الزيارة");
    } finally {
      setVisitSaving(false);
    }
  }

  async function addDeal() {
    if (!token || !customerId || !customer) return;
    const totalPrice = Number(dealForm.totalPrice);
    const downPayment = Number(dealForm.downPayment);
    const houseArea = dealForm.houseArea.trim() ? Number(dealForm.houseArea) : null;

    if (!Number.isFinite(totalPrice) || totalPrice <= 0) {
      setError("السعر الكلي غير صالح");
      return;
    }
    if (!Number.isFinite(downPayment) || downPayment < 0) {
      setError("الدفعة الأولى غير صالحة");
      return;
    }
    if (houseArea !== null && (!Number.isFinite(houseArea) || houseArea <= 0)) {
      setError("مساحة العقار غير صالحة");
      return;
    }

    setDealSaving(true);
    setError("");
    try {
      await createDeal(token, {
        customer_id: customerId,
        name: customer.name,
        profession: customer.profession,
        email: customer.email,
        phone: customer.phone,
        house_type: dealForm.houseType as "house" | "villa",
        total_price: totalPrice,
        payment_type: dealForm.paymentType as "cash" | "half_cash" | "installments",
        down_payment: downPayment,
        house_area: houseArea,
        residential_block: dealForm.block.trim() || null,
        house_number: dealForm.houseNumber.trim() || null,
        notes: dealForm.notes.trim() || null
      });
      setDealForm({
        houseType: "house",
        paymentType: "cash",
        totalPrice: "",
        downPayment: "",
        houseArea: "",
        block: "",
        houseNumber: "",
        notes: ""
      });
      await loadDetails();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إضافة صفقة البيع");
    } finally {
      setDealSaving(false);
    }
  }

  const lastVisitDate = visits[0]?.visit_date ?? null;
  const lastDealDate = deals[0]?.sale_date ?? null;
  const totalDealsValue = deals.reduce((sum, deal) => sum + (deal.total_price || 0), 0);

  function navigateBackToSales() {
    const targetPath = "/sales";
    router.push(targetPath);
    window.setTimeout(() => {
      if (window.location.pathname !== targetPath) {
        window.location.assign(targetPath);
      }
    }, 180);
  }

  if (loading || fetching) {
    return (
      <main className={styles.page}>
        <section className={styles.card}>جارِ تحميل ملف الزبون...</section>
      </main>
    );
  }

  if (!customer) {
    return (
      <main className={styles.page}>
        <section className={styles.card}>
          <p>{error || "ملف الزبون غير متاح"}</p>
          <button className={styles.primaryBtn} type="button" onClick={() => router.push("/sales")}>
            رجوع
          </button>
        </section>
      </main>
    );
  }

  return (
    <main className={styles.page}>
      <section className={styles.headerCard}>
        <button
          className={styles.backBtn}
          type="button"
          onClick={navigateBackToSales}
          onTouchEnd={navigateBackToSales}
        >
          رجوع
        </button>
        <div className={styles.profileBlock}>
          <img src="/assets/Faceless Corporate Real Estate Avatar.png" alt="صورة الزبون" />
          <div>
            <h1>{customer.name}</h1>
            <p>{customer.phone}</p>
            <small>آخر تحديث: {formatDateTime(customer.updated_at ?? customer.created_at)}</small>
          </div>
        </div>
      </section>

      {error ? <p className={styles.error}>{error}</p> : null}

      <section className={styles.statsGrid}>
        <article className={styles.statBox}>
          <small>عدد الزيارات</small>
          <strong>{visits.length}</strong>
        </article>
        <article className={styles.statBox}>
          <small>عدد الصفقات</small>
          <strong>{deals.length}</strong>
        </article>
        <article className={styles.statBox}>
          <small>آخر زيارة</small>
          <strong>{formatDateTime(lastVisitDate)}</strong>
        </article>
        <article className={styles.statBox}>
          <small>إجمالي البيع</small>
          <strong>{formatMoney(totalDealsValue)} د.ع</strong>
        </article>
      </section>

      <section className={styles.card}>
        <h3>المعلومات الأساسية</h3>
        <div className={styles.infoGrid}>
          <div>
            <small>الحالة</small>
            <p>{STATUS_LABELS[customer.status ?? ""] ?? "غير محدد"}</p>
          </div>
          <div>
            <small>المهنة</small>
            <p>{customer.profession || "-"}</p>
          </div>
          <div>
            <small>العنوان</small>
            <p>{customer.address || "-"}</p>
          </div>
          <div>
            <small>البريد</small>
            <p>{customer.email || "-"}</p>
          </div>
          <div>
            <small>البلوك/الحجز</small>
            <p>{customer.booking_id || "-"}</p>
          </div>
          <div>
            <small>موظف المبيعات</small>
            <p>{customer.sales_employee_name || "-"}</p>
          </div>
        </div>
      </section>

      <section className={styles.card}>
        <h3>تحديث حالة الزبون</h3>
        <div className={styles.row}>
          <select value={statusValue} onChange={(e) => setStatusValue(e.target.value)} className={styles.select}>
            {STATUS_OPTIONS.map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
          <button className={styles.primaryBtn} type="button" onClick={saveStatus} disabled={statusSaving}>
            {statusSaving ? "جارِ الحفظ..." : "حفظ الحالة"}
          </button>
        </div>
      </section>

      <section className={styles.card}>
        <h3>الملاحظات</h3>
        <p className={styles.currentNotes}>{customer.notes || "لا توجد ملاحظات حالية"}</p>
        <textarea
          className={styles.textarea}
          placeholder="أضف ملاحظة جديدة..."
          value={noteText}
          onChange={(e) => setNoteText(e.target.value)}
        />
        <button className={styles.primaryBtn} type="button" onClick={addNote} disabled={noteSaving}>
          {noteSaving ? "جارِ الإضافة..." : "إضافة ملاحظة"}
        </button>
      </section>

      <section className={styles.card}>
        <div className={styles.sectionHead}>
          <h3>سجل الزيارات</h3>
          {loadingDetails ? <small className={styles.muted}>جارِ التحميل...</small> : null}
        </div>
        <div className={styles.visitComposer}>
          <textarea
            className={styles.textarea}
            value={visitNote}
            onChange={(e) => setVisitNote(e.target.value)}
            placeholder="أضف ملاحظة زيارة جديدة..."
          />
          <button className={styles.secondaryBtn} type="button" onClick={addVisit} disabled={visitSaving}>
            {visitSaving ? "جارِ الإضافة..." : "إضافة زيارة جديدة"}
          </button>
        </div>
        <div className={styles.timelineList}>
          {visits.length ? (
            visits.map((visit) => (
              <article key={visit.id} className={styles.timelineItem}>
                <strong>{formatDateTime(visit.visit_date)}</strong>
                <p>{visit.notes || "بدون ملاحظة"}</p>
              </article>
            ))
          ) : (
            <p className={styles.muted}>لا توجد زيارات مسجلة</p>
          )}
        </div>
      </section>

      <section className={styles.card}>
        <div className={styles.sectionHead}>
          <h3>صفقات البيع</h3>
          {loadingDetails ? <small className={styles.muted}>جارِ التحميل...</small> : null}
        </div>
        <div className={styles.timelineList}>
          {deals.length ? (
            deals.map((deal) => (
              <article key={deal.id} className={styles.timelineItem}>
                <strong>
                  {HOUSE_TYPE_LABELS[deal.house_type] ?? deal.house_type} {deal.house_number ?? "-"} |{" "}
                  {formatMoney(deal.total_price)} د.ع
                </strong>
                <p>
                  {PAYMENT_TYPE_LABELS[deal.payment_type] ?? deal.payment_type} - {formatDateTime(deal.sale_date)}
                </p>
              </article>
            ))
          ) : (
            <p className={styles.muted}>لا توجد صفقات بيع مسجلة</p>
          )}
        </div>
      </section>

      <section className={styles.card}>
        <div className={styles.sectionHead}>
          <h3>صور الزبون</h3>
          <button
            className={styles.secondaryBtn}
            type="button"
            onClick={() => imageInputRef.current?.click()}
            disabled={uploadingImage}
          >
            {uploadingImage ? "جارِ الرفع..." : "رفع صورة"}
          </button>
          <input ref={imageInputRef} type="file" accept="image/*" hidden onChange={onImagePicked} />
        </div>
        <div className={styles.imageGrid}>
          {images.length ? (
            images.map((doc) => (
              <a key={doc.id} href={resolveAssetUrl(doc.url)} target="_blank" rel="noreferrer" className={styles.imgItem}>
                <img src={resolveAssetUrl(doc.url)} alt={doc.original_name} />
              </a>
            ))
          ) : (
            <p className={styles.muted}>لا توجد صور مرفوعة</p>
          )}
        </div>
      </section>

      <section className={styles.card}>
        <div className={styles.sectionHead}>
          <h3>المستندات</h3>
          <button
            className={styles.secondaryBtn}
            type="button"
            onClick={() => docInputRef.current?.click()}
            disabled={uploadingDoc}
          >
            {uploadingDoc ? "جارِ الرفع..." : "رفع مستند"}
          </button>
          <input ref={docInputRef} type="file" hidden onChange={onDocPicked} />
        </div>
        <div className={styles.fileList}>
          {files.length ? (
            files.map((doc) => (
              <a key={doc.id} href={resolveAssetUrl(doc.url)} target="_blank" rel="noreferrer" className={styles.fileItem}>
                <strong>{doc.original_name}</strong>
                <small>{formatDateTime(doc.uploaded_at)}</small>
              </a>
            ))
          ) : (
            <p className={styles.muted}>لا توجد مستندات مرفوعة</p>
          )}
        </div>
      </section>

      <section className={styles.card}>
        <h3>إضافة صفقة بيع</h3>
        <div className={styles.formGrid}>
          <label className={styles.field}>
            نوع العقار
            <select
              className={styles.select}
              value={dealForm.houseType}
              onChange={(e) => setDealForm((prev) => ({ ...prev, houseType: e.target.value }))}
            >
              <option value="house">دار</option>
              <option value="villa">فيلا</option>
            </select>
          </label>

          <label className={styles.field}>
            نوع الدفع
            <select
              className={styles.select}
              value={dealForm.paymentType}
              onChange={(e) => setDealForm((prev) => ({ ...prev, paymentType: e.target.value }))}
            >
              <option value="cash">كاش</option>
              <option value="half_cash">نصف كاش</option>
              <option value="installments">دفعات</option>
            </select>
          </label>

          <label className={styles.field}>
            السعر الكلي
            <input
              className={styles.select}
              inputMode="decimal"
              value={dealForm.totalPrice}
              onChange={(e) => setDealForm((prev) => ({ ...prev, totalPrice: e.target.value }))}
              placeholder="مثال: 220000000"
            />
          </label>

          <label className={styles.field}>
            الدفعة الأولى
            <input
              className={styles.select}
              inputMode="decimal"
              value={dealForm.downPayment}
              onChange={(e) => setDealForm((prev) => ({ ...prev, downPayment: e.target.value }))}
              placeholder="مثال: 60000000"
            />
          </label>

          <label className={styles.field}>
            المساحة (اختياري)
            <input
              className={styles.select}
              inputMode="decimal"
              value={dealForm.houseArea}
              onChange={(e) => setDealForm((prev) => ({ ...prev, houseArea: e.target.value }))}
              placeholder="مثال: 160"
            />
          </label>

          <label className={styles.field}>
            البلوك (اختياري)
            <input
              className={styles.select}
              value={dealForm.block}
              onChange={(e) => setDealForm((prev) => ({ ...prev, block: e.target.value }))}
              placeholder="b12"
            />
          </label>

          <label className={styles.field}>
            رقم الدار (اختياري)
            <input
              className={styles.select}
              value={dealForm.houseNumber}
              onChange={(e) => setDealForm((prev) => ({ ...prev, houseNumber: e.target.value }))}
              placeholder="32"
            />
          </label>
        </div>

        <label className={styles.field}>
          ملاحظات الصفقة (اختياري)
          <textarea
            className={styles.textarea}
            value={dealForm.notes}
            onChange={(e) => setDealForm((prev) => ({ ...prev, notes: e.target.value }))}
            placeholder="ملاحظات حول الصفقة"
          />
        </label>

        <button className={styles.primaryBtn} type="button" onClick={addDeal} disabled={dealSaving}>
          {dealSaving ? "جارِ إضافة الصفقة..." : "إضافة صفقة بيع"}
        </button>
      </section>
    </main>
  );
}
