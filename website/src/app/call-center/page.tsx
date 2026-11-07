"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import {
  Booking,
  BookingSource,
  BookingStatus,
  Customer,
  LiveSummary
} from "@/types";
import {
  createBooking,
  getLiveSummary,
  listBookings,
  listCustomers,
  updateBooking
} from "@/lib/api";
import { useProtectedPage } from "@/lib/auth";
import { storage } from "@/lib/storage";
import { useRouter } from "next/navigation";
import styles from "./call-center.module.css";

const BACKEND_ORIGIN = (
  process.env.NEXT_PUBLIC_BACKEND_ORIGIN ?? "https://emadcrm.compassaccuracy.com"
).replace(/\/+$/, "");

const STATUS_LABELS: Record<BookingStatus, string> = {
  pending: "لم يحضر بعد",
  approved: "حضر",
  cancelled: "ملغي",
  no_show: "لم يحضر"
};

const SOURCE_LABELS: Record<BookingSource, string> = {
  whatsapp: "واتساب",
  instagram: "انستغرام",
  facebook: "فيسبوك",
  tiktok: "تيك توك",
  phone: "اتصال",
  external_ad: "اعلان خارجي"
};

const GOVERNORATES = [
  "بغداد",
  "البصرة",
  "نينوى",
  "أربيل",
  "النجف",
  "كربلاء",
  "بابل",
  "الأنبار",
  "ديالى",
  "كركوك",
  "صلاح الدين",
  "واسط",
  "ميسان",
  "ذي قار",
  "المثنى",
  "القادسية",
  "دهوك",
  "السليمانية"
];

function resolveAvatarUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  const normalized = value.trim();
  if (!normalized) return null;
  if (/^https?:\/\//i.test(normalized)) return normalized;
  if (normalized.startsWith("/")) return `${BACKEND_ORIGIN}${normalized}`;
  return `${BACKEND_ORIGIN}/${normalized}`;
}

type TabKey = "bookings" | "contacts";

interface BookingFormState {
  id: string | null;
  name: string;
  phone: string;
  governorate: string;
  source: BookingSource;
  visitDate: string;
  visitTime: string;
  notes: string;
}

function normalizeWhatsappPhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  if (digits.startsWith("964")) return digits;
  if (digits.startsWith("0")) return `964${digits.slice(1)}`;
  return digits;
}

function computeEffectiveStatus(booking: Booking): BookingStatus {
  if (booking.status !== "pending") return booking.status;
  const date = new Date(booking.visit_date);
  if (Number.isNaN(date.getTime())) return booking.status;
  date.setHours(date.getHours() + 24);
  return Date.now() > date.getTime() ? "no_show" : "pending";
}

function toDateInput(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

function toTimeInput(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "10:00";
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function formatCardDate(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleDateString("ar-IQ", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  });
}

function formatCardTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleTimeString("ar-IQ", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: true
  });
}

function toBookingForm(booking?: Booking | null): BookingFormState {
  if (!booking) {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    return {
      id: null,
      name: "",
      phone: "",
      governorate: "بغداد",
      source: "whatsapp",
      visitDate: toDateInput(tomorrow.toISOString()),
      visitTime: "10:00",
      notes: ""
    };
  }
  return {
    id: booking.id,
    name: booking.name,
    phone: booking.phone,
    governorate: booking.governorate || "بغداد",
    source: booking.source,
    visitDate: toDateInput(booking.visit_date),
    visitTime: toTimeInput(booking.visit_date),
    notes: booking.notes ?? ""
  };
}

export default function CallCenterPage() {
  const router = useRouter();
  const { user, token, loading } = useProtectedPage(["call_center"]);
  const [tab, setTab] = useState<TabKey>("bookings");
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [contacts, setContacts] = useState<Customer[]>([]);
  const [summary, setSummary] = useState<LiveSummary | null>(null);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<BookingStatus | "all">("all");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [loadingData, setLoadingData] = useState(false);
  const [error, setError] = useState("");
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [form, setForm] = useState<BookingFormState>(toBookingForm());
  const avatarSrc = resolveAvatarUrl(user?.avatar_url);

  const reloadBookings = useCallback(async () => {
    if (!token) return;
    setLoadingData(true);
    setError("");
    try {
      const [bookingsRes, summaryRes] = await Promise.all([
        listBookings(token, {
          pageSize: 100,
          search: query.trim() || undefined,
          status: statusFilter === "all" ? undefined : statusFilter,
          fromDate: fromDate ? `${fromDate}T00:00:00` : undefined,
          toDate: toDate ? `${toDate}T23:59:59` : undefined,
          sortDir: "desc"
        }),
        getLiveSummary(token).catch(() => null)
      ]);
      setBookings(bookingsRes.items);
      if (summaryRes) setSummary(summaryRes);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل الحجوزات");
    } finally {
      setLoadingData(false);
    }
  }, [token, query, statusFilter, fromDate, toDate]);

  const reloadContacts = useCallback(async () => {
    if (!token) return;
    setLoadingData(true);
    setError("");
    try {
      const data = await listCustomers(token, query.trim());
      setContacts(data.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل الزبائن");
    } finally {
      setLoadingData(false);
    }
  }, [token, query]);

  useEffect(() => {
    if (!token) return;
    if (tab === "bookings") {
      void reloadBookings();
      return;
    }
    void reloadContacts();
  }, [token, tab, reloadBookings, reloadContacts]);

  const computedStats = useMemo(() => {
    const total = summary?.total_bookings ?? bookings.length;
    const pending =
      summary?.pending_bookings ??
      bookings.filter((item) => computeEffectiveStatus(item) === "pending").length;
    const approved =
      summary?.approved_bookings ??
      bookings.filter((item) => computeEffectiveStatus(item) === "approved").length;
    const missed =
      summary?.missed_bookings ??
      bookings.filter((item) => {
        const status = computeEffectiveStatus(item);
        return status === "cancelled" || status === "no_show";
      }).length;
    return { total, pending, approved, missed };
  }, [bookings, summary]);

  function logout() {
    storage.clear();
    router.replace("/");
  }

  function resetFilters() {
    setStatusFilter("all");
    setFromDate("");
    setToDate("");
  }

  function openCreateForm() {
    setForm(toBookingForm(null));
    setIsFormOpen(true);
  }

  function openEditForm(booking: Booking) {
    if (booking.status !== "pending") {
      setError("يمكن تعديل الحجوزات التي لم يحضر بعد فقط");
      return;
    }
    setForm(toBookingForm(booking));
    setIsFormOpen(true);
  }

  async function saveBooking(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token) return;

    const dateTimeValue = `${form.visitDate}T${form.visitTime || "10:00"}:00`;
    const visitDate = new Date(dateTimeValue);
    if (Number.isNaN(visitDate.getTime())) {
      setError("موعد الحجز غير صالح");
      return;
    }

    setIsSaving(true);
    setError("");
    try {
      const payload = {
        name: form.name.trim(),
        phone: form.phone.trim(),
        governorate: form.governorate,
        source: form.source,
        visit_date: visitDate.toISOString(),
        notes: form.notes.trim() || null
      };
      if (!payload.name || !payload.phone) {
        throw new Error("يرجى إكمال الاسم ورقم الهاتف");
      }
      if (form.id) {
        await updateBooking(token, form.id, payload);
      } else {
        await createBooking(token, payload);
      }
      setIsFormOpen(false);
      await reloadBookings();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر حفظ الحجز");
    } finally {
      setIsSaving(false);
    }
  }

  function openWhatsapp(phone: string) {
    const normalized = normalizeWhatsappPhone(phone);
    window.open(`https://wa.me/${normalized}`, "_blank", "noopener,noreferrer");
  }

  function openCall(phone: string) {
    const digits = phone.replace(/[^\d+]/g, "");
    window.open(`tel:${digits}`, "_self");
  }

  if (loading) {
    return (
      <main className={styles.page}>
        <section className={styles.loading}>جارِ تحميل الواجهة...</section>
      </main>
    );
  }

  return (
    <main className={styles.page}>
      <section className={styles.mobileFrame}>
        <header className={styles.hero}>
          <div className={styles.heroOverlay} />
          <div className={styles.heroTop}>
            <div className={styles.heroActions}>
              <div className={styles.avatar}>
                {avatarSrc ? (
                  <img src={avatarSrc} alt={user?.full_name ?? "صورة الموظف"} />
                ) : (
                  <span>{(user?.full_name?.slice(0, 1) ?? "C").toUpperCase()}</span>
                )}
              </div>
              <button type="button" className={styles.editProfileBtn}>
                تعديل
              </button>
            </div>

            <div className={styles.brand}>
              <img src="/assets/Premium Gold and Teal Real Estate Emblem.png" alt="شعار" />
              <strong>عماد سكر</strong>
              <small>نظام ادارة مبيعات عماد سكر</small>
            </div>

            <button className={styles.logoutIconBtn} type="button" onClick={logout} aria-label="تسجيل خروج">
              <svg aria-hidden="true" viewBox="0 0 24 24" fill="none">
                <path
                  d="M10 4H6.8C5.806 4 5 4.806 5 5.8V18.2C5 19.194 5.806 20 6.8 20H10"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d="M14 8L19 12L14 16"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d="M19 12H10"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
          </div>

          <div className={styles.heroTitle}>
            <h1>مرحباً {user?.full_name ?? "أحمد"}</h1>
            <p>موظف الكول سنتر</p>
          </div>

          <div className={styles.stats}>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>📊</span>
              <strong>{computedStats.total}</strong>
              <small>الإجمالي</small>
            </article>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>⏳</span>
              <strong>{computedStats.pending}</strong>
              <small>بانتظار</small>
            </article>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>✅</span>
              <strong>{computedStats.approved}</strong>
              <small>تم الحضور</small>
            </article>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>⚠️</span>
              <strong>{computedStats.missed}</strong>
              <small>غائب/ملغي</small>
            </article>
          </div>
        </header>

        <section className={styles.body}>
          <div className={styles.tabs}>
            <button
              type="button"
              className={tab === "bookings" ? styles.tabActive : ""}
              onClick={() => setTab("bookings")}
            >
              الحجوزات
            </button>
            <button
              type="button"
              className={tab === "contacts" ? styles.tabActive : ""}
              onClick={() => setTab("contacts")}
            >
              تواصل
            </button>
          </div>

          <div className={styles.searchRow}>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={tab === "bookings" ? "بحث بالاسم أو الهاتف..." : "بحث عن زبون..."}
            />
            <button type="button" onClick={() => void (tab === "bookings" ? reloadBookings() : reloadContacts())}>
              بحث
            </button>
          </div>

          {tab === "bookings" ? (
            <>
              <div className={styles.filters}>
                <select
                  value={statusFilter}
                  onChange={(event) => setStatusFilter(event.target.value as BookingStatus | "all")}
                >
                  <option value="all">كل الحالات</option>
                  <option value="pending">لم يحضر بعد</option>
                  <option value="approved">حضر</option>
                  <option value="no_show">لم يحضر</option>
                </select>
                <label className={styles.dateField}>
                  <span className={styles.dateCaption}>من</span>
                  <input type="date" value={fromDate} onChange={(event) => setFromDate(event.target.value)} />
                </label>
                <label className={styles.dateField}>
                  <span className={styles.dateCaption}>إلى</span>
                  <input type="date" value={toDate} onChange={(event) => setToDate(event.target.value)} />
                </label>
                <button type="button" onClick={resetFilters}>
                  مسح
                </button>
              </div>

              {loadingData ? <p className={styles.muted}>جارِ تحميل الحجوزات...</p> : null}
              {error ? <p className={styles.error}>{error}</p> : null}

              <div className={styles.list}>
                {!loadingData && bookings.length === 0 ? (
                  <article className={styles.card}>
                    <p className={styles.muted}>لا توجد حجوزات مطابقة</p>
                  </article>
                ) : null}
                {bookings.map((booking) => {
                  const effectiveStatus = computeEffectiveStatus(booking);
                  return (
                    <article key={booking.id} className={styles.card}>
                      <div className={styles.cardHead}>
                        <h3>{booking.name}</h3>
                        <span
                          className={`${styles.statusBadge} ${
                            effectiveStatus === "approved"
                              ? styles.statusApproved
                              : effectiveStatus === "pending"
                                ? styles.statusPending
                                : styles.statusMissed
                          }`}
                        >
                          {STATUS_LABELS[effectiveStatus]}
                        </span>
                      </div>
                      <p>{booking.phone}</p>
                      <p>
                        {booking.governorate} - {SOURCE_LABELS[booking.source]}
                      </p>
                      <p>
                        الموعد: {formatCardDate(booking.visit_date)} - {formatCardTime(booking.visit_date)}
                      </p>
                      <div className={styles.actions}>
                        <button type="button" onClick={() => openWhatsapp(booking.phone)}>
                          واتساب
                        </button>
                        <button type="button" onClick={() => openCall(booking.phone)}>
                          اتصال
                        </button>
                        <button type="button" onClick={() => openEditForm(booking)}>
                          تعديل
                        </button>
                      </div>
                    </article>
                  );
                })}
              </div>
              <button className={styles.fab} type="button" onClick={openCreateForm}>
                + حجز جديد
              </button>
            </>
          ) : (
            <>
              {loadingData ? <p className={styles.muted}>جارِ تحميل الزبائن...</p> : null}
              {error ? <p className={styles.error}>{error}</p> : null}
              <div className={styles.list}>
                {!loadingData && contacts.length === 0 ? (
                  <article className={styles.card}>
                    <p className={styles.muted}>لا يوجد زبائن</p>
                  </article>
                ) : null}
                {contacts.map((customer) => (
                  <article key={customer.id} className={styles.card}>
                    <div className={styles.cardHead}>
                      <h3>{customer.name}</h3>
                      <span>{customer.status ?? "محتمل"}</span>
                    </div>
                    <p>{customer.phone}</p>
                    <div className={styles.actions}>
                      <button type="button" onClick={() => openWhatsapp(customer.phone)}>
                        تواصل واتساب
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            </>
          )}
        </section>

        {isFormOpen ? (
          <section className={styles.modal}>
            <form className={styles.modalCard} onSubmit={saveBooking}>
              <h3>{form.id ? "تعديل الحجز" : "إضافة حجز جديد"}</h3>

              <label>
                الاسم
                <input
                  value={form.name}
                  onChange={(event) => setForm((prev) => ({ ...prev, name: event.target.value }))}
                  required
                />
              </label>

              <label>
                الهاتف
                <input
                  value={form.phone}
                  onChange={(event) => setForm((prev) => ({ ...prev, phone: event.target.value }))}
                  required
                />
              </label>

              <label>
                المحافظة
                <select
                  value={form.governorate}
                  onChange={(event) => setForm((prev) => ({ ...prev, governorate: event.target.value }))}
                >
                  {GOVERNORATES.map((gov) => (
                    <option key={gov} value={gov}>
                      {gov}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                المصدر
                <select
                  value={form.source}
                  onChange={(event) => setForm((prev) => ({ ...prev, source: event.target.value as BookingSource }))}
                >
                  {Object.entries(SOURCE_LABELS).map(([key, label]) => (
                    <option key={key} value={key}>
                      {label}
                    </option>
                  ))}
                </select>
              </label>

              <div className={styles.inlineFields}>
                <label>
                  التاريخ
                  <input
                    type="date"
                    value={form.visitDate}
                    onChange={(event) => setForm((prev) => ({ ...prev, visitDate: event.target.value }))}
                    required
                  />
                </label>
                <label>
                  الوقت
                  <input
                    type="time"
                    value={form.visitTime}
                    onChange={(event) => setForm((prev) => ({ ...prev, visitTime: event.target.value }))}
                    required
                  />
                </label>
              </div>

              <label>
                ملاحظات
                <textarea
                  value={form.notes}
                  onChange={(event) => setForm((prev) => ({ ...prev, notes: event.target.value }))}
                  rows={3}
                />
              </label>

              <div className={styles.modalActions}>
                <button type="button" onClick={() => setIsFormOpen(false)}>
                  إلغاء
                </button>
                <button type="submit" disabled={isSaving}>
                  {isSaving ? "جارِ الحفظ..." : "حفظ"}
                </button>
              </div>
            </form>
          </section>
        ) : null}
      </section>
    </main>
  );
}
