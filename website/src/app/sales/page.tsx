"use client";

import { ChangeEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  addCustomerSalesNote,
  createDeal,
  listCustomerDeals,
  listCustomerSalesNotes,
  listCustomers,
  updateCustomer,
  updateUserProfile,
  uploadUserAvatar
} from "@/lib/api";
import { useProtectedPage } from "@/lib/auth";
import { storage } from "@/lib/storage";
import type { Customer, CustomerSalesNote, Deal } from "@/types";
import styles from "./sales.module.css";

const BACKEND_ORIGIN = (
  process.env.NEXT_PUBLIC_BACKEND_ORIGIN ?? "https://emadcrm.compassaccuracy.com"
).replace(/\/+$/, "");
const CROP_SIZE = 280;
const AVATAR_EXPORT_SIZE = 512;

const STATUS_LABELS: Record<string, string> = {
  buyer: "تم الشراء",
  potential: "محتمل",
  reservation: "زيارة مجدولة",
  hesitant: "متردد",
  not_interested: "غير مهتم",
  interested: "مهتم"
};

const MONTHS_AR = [
  "يناير",
  "فبراير",
  "مارس",
  "أبريل",
  "مايو",
  "يونيو",
  "يوليو",
  "أغسطس",
  "سبتمبر",
  "أكتوبر",
  "نوفمبر",
  "ديسمبر"
];

const HOUSE_TYPE_LABELS: Record<Deal["house_type"], string> = {
  house: "دار",
  villa: "فيلا"
};

const PAYMENT_TYPE_LABELS: Record<Deal["payment_type"], string> = {
  cash: "كاش",
  half_cash: "نصف كاش",
  installments: "دفعات"
};

function formatAmount(value: number): string {
  return new Intl.NumberFormat("ar-IQ").format(value);
}

function isBuyerStatus(value: string | null | undefined): boolean {
  return (value ?? "").trim().toLowerCase() === "buyer";
}

function formatCardDate(value: string): { day: string; monthYear: string } {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return { day: "-", monthYear: "لا يوجد موعد" };
  return {
    day: String(date.getDate()),
    monthYear: `${MONTHS_AR[date.getMonth()]} ${date.getFullYear()}`
  };
}

function resolveAvatarUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  const normalized = value.trim();
  if (!normalized) return null;
  const lowered = normalized.toLowerCase();
  if (lowered === "null" || lowered === "undefined" || lowered === "none") return null;
  if (/^data:image\//i.test(normalized)) return normalized;
  if (/^https?:\/\//i.test(normalized)) {
    try {
      const parsed = new URL(normalized);
      return parsed.origin === BACKEND_ORIGIN ? normalized : null;
    } catch {
      return null;
    }
  }
  if (normalized.startsWith("//")) {
    try {
      const parsed = new URL(`https:${normalized}`);
      return parsed.origin === BACKEND_ORIGIN ? parsed.toString() : null;
    } catch {
      return null;
    }
  }
  if (normalized.startsWith("/")) return `${BACKEND_ORIGIN}${normalized}`;
  return `${BACKEND_ORIGIN}/${normalized}`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

async function buildCroppedAvatar(
  imageSrc: string,
  zoom: number,
  offsetX: number,
  offsetY: number
): Promise<Blob> {
  const image = new Image();
  image.src = imageSrc;

  await new Promise<void>((resolve, reject) => {
    image.onload = () => resolve();
    image.onerror = () => reject(new Error("تعذر تحميل الصورة المحددة"));
  });

  const canvas = document.createElement("canvas");
  canvas.width = CROP_SIZE;
  canvas.height = CROP_SIZE;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("تعذر تهيئة أداة الاقتصاص");

  const baseScale = Math.max(CROP_SIZE / image.naturalWidth, CROP_SIZE / image.naturalHeight);
  const renderScale = baseScale * zoom;
  const renderWidth = image.naturalWidth * renderScale;
  const renderHeight = image.naturalHeight * renderScale;

  const centerX = CROP_SIZE / 2 + offsetX;
  const centerY = CROP_SIZE / 2 + offsetY;
  const drawX = centerX - renderWidth / 2;
  const drawY = centerY - renderHeight / 2;

  context.fillStyle = "#0f2e54";
  context.fillRect(0, 0, CROP_SIZE, CROP_SIZE);
  context.drawImage(image, drawX, drawY, renderWidth, renderHeight);

  const exportCanvas = document.createElement("canvas");
  exportCanvas.width = AVATAR_EXPORT_SIZE;
  exportCanvas.height = AVATAR_EXPORT_SIZE;
  const exportContext = exportCanvas.getContext("2d");
  if (!exportContext) throw new Error("تعذر تجهيز الصورة النهائية");
  exportContext.drawImage(canvas, 0, 0, AVATAR_EXPORT_SIZE, AVATAR_EXPORT_SIZE);

  const blob = await new Promise<Blob | null>((resolve) =>
    exportCanvas.toBlob((value) => resolve(value), "image/png", 0.95)
  );
  if (!blob) throw new Error("تعذر إنشاء الصورة النهائية");
  return blob;
}

export default function SalesPage() {
  const router = useRouter();
  const { user, token, loading } = useProtectedPage(["sales"]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [query, setQuery] = useState("");
  const [activeStatus, setActiveStatus] = useState("all");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [loadingCustomers, setLoadingCustomers] = useState(false);
  const [error, setError] = useState("");
  const [profileUser, setProfileUser] = useState(user);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [profileError, setProfileError] = useState("");
  const [fullNameInput, setFullNameInput] = useState("");
  const [usernameInput, setUsernameInput] = useState("");
  const [phoneInput, setPhoneInput] = useState("");
  const [passwordInput, setPasswordInput] = useState("");
  const [selectedAvatarBlob, setSelectedAvatarBlob] = useState<Blob | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const [cropSource, setCropSource] = useState<string | null>(null);
  const [cropZoom, setCropZoom] = useState(1);
  const [cropOffsetX, setCropOffsetX] = useState(0);
  const [cropOffsetY, setCropOffsetY] = useState(0);
  const [activeCustomer, setActiveCustomer] = useState<Customer | null>(null);
  const [quickAction, setQuickAction] = useState<"status" | "note" | "deal" | null>(null);
  const [quickStatus, setQuickStatus] = useState("potential");
  const [quickNote, setQuickNote] = useState("");
  const [quickSaving, setQuickSaving] = useState(false);
  const [noteLoading, setNoteLoading] = useState(false);
  const [salesNotes, setSalesNotes] = useState<CustomerSalesNote[]>([]);
  const [customerDeals, setCustomerDeals] = useState<Deal[]>([]);
  const [dealLoading, setDealLoading] = useState(false);
  const [dealMode, setDealMode] = useState<"create" | "view">("create");
  const [quickError, setQuickError] = useState("");
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

  const avatarSrc = avatarPreview ?? resolveAvatarUrl(profileUser?.avatar_url);
  const [avatarLoadFailed, setAvatarLoadFailed] = useState(false);
  const shouldShowAvatarImage = Boolean(avatarSrc) && !avatarLoadFailed;

  useEffect(() => {
    setProfileUser(user);
  }, [user]);

  useEffect(() => {
    setAvatarLoadFailed(false);
  }, [avatarSrc]);

  const statusCounts = useMemo(() => {
    const counts = new Map<string, number>();
    customers.forEach((customer) => {
      const key = (customer.status ?? "").trim();
      if (!key) return;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    });
    return counts;
  }, [customers]);

  const statusFilters = useMemo(() => {
    const items: Array<{ key: string; label: string; count: number }> = [];

    Object.keys(STATUS_LABELS).forEach((key) => {
      const count = statusCounts.get(key) ?? 0;
      items.push({ key, label: STATUS_LABELS[key], count });
    });

    statusCounts.forEach((count, key) => {
      if (STATUS_LABELS[key]) return;
      items.push({ key, label: key.replace(/_/g, " "), count });
    });

    return items;
  }, [statusCounts]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return customers.filter((c) => {
      if (activeStatus !== "all" && c.status !== activeStatus) return false;

      if (fromDate || toDate) {
        const value = c.updated_at ?? c.created_at;
        const customerDate = new Date(value);
        if (Number.isNaN(customerDate.getTime())) return false;

        if (fromDate) {
          const from = new Date(`${fromDate}T00:00:00`);
          if (customerDate < from) return false;
        }
        if (toDate) {
          const to = new Date(`${toDate}T23:59:59`);
          if (customerDate > to) return false;
        }
      }

      if (!q) return true;
      return (
        c.name.toLowerCase().includes(q) ||
        c.phone.toLowerCase().includes(q) ||
        (c.profession ?? "").toLowerCase().includes(q)
      );
    });
  }, [customers, query, activeStatus, fromDate, toDate]);

  useEffect(() => {
    if (activeStatus === "all") return;
    if (!statusCounts.has(activeStatus)) setActiveStatus("all");
  }, [activeStatus, statusCounts]);

  const counts = useMemo(() => {
    const now = new Date();
    const all = customers.length;
    let today = 0;
    let month = 0;
    let buyers = 0;

    customers.forEach((c) => {
      const createdAt = new Date(c.created_at);
      if (!Number.isNaN(createdAt.getTime())) {
        if (
          createdAt.getFullYear() === now.getFullYear() &&
          createdAt.getMonth() === now.getMonth()
        ) {
          month += 1;
        }

        if (
          createdAt.getFullYear() === now.getFullYear() &&
          createdAt.getMonth() === now.getMonth() &&
          createdAt.getDate() === now.getDate()
        ) {
          today += 1;
        }
      }

      if (isBuyerStatus(c.status)) buyers += 1;
    });

    return { all, today, month, buyers };
  }, [customers]);

  useEffect(() => {
    return () => {
      if (avatarPreview?.startsWith("blob:")) URL.revokeObjectURL(avatarPreview);
    };
  }, [avatarPreview]);

  useEffect(() => {
    if (!token) return;
    let active = true;

    async function load() {
      setLoadingCustomers(true);
      setError("");
      try {
        const data = await listCustomers(token);
        if (active) setCustomers(data.items);
      } catch (err) {
        if (active) {
          setError(err instanceof Error ? err.message : "تعذر تحميل الزبائن");
        }
      } finally {
        if (active) setLoadingCustomers(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [token]);

  const reloadCustomers = useCallback(async () => {
    if (!token) return;
    const data = await listCustomers(token);
    setCustomers(data.items);
  }, [token]);

  function openProfileEditor() {
    setProfileError("");
    setFullNameInput(profileUser?.full_name ?? "");
    setUsernameInput(profileUser?.username ?? "");
    setPhoneInput(profileUser?.phone ?? "");
    setPasswordInput("");
    setSelectedAvatarBlob(null);
    setIsEditOpen(true);
  }

  async function onSelectAvatar(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    event.target.value = "";
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") {
        setCropSource(reader.result);
        setCropZoom(1);
        setCropOffsetX(0);
        setCropOffsetY(0);
      }
    };
    reader.readAsDataURL(file);
  }

  async function applyCrop() {
    if (!cropSource) return;
    try {
      const blob = await buildCroppedAvatar(cropSource, cropZoom, cropOffsetX, cropOffsetY);
      const preview = URL.createObjectURL(blob);
      if (avatarPreview?.startsWith("blob:")) URL.revokeObjectURL(avatarPreview);
      setSelectedAvatarBlob(blob);
      setAvatarPreview(preview);
      setCropSource(null);
    } catch (err) {
      setProfileError(err instanceof Error ? err.message : "تعذر اقتصاص الصورة");
    }
  }

  async function saveProfile() {
    if (!token || !profileUser) return;
    setIsSavingProfile(true);
    setProfileError("");
    try {
      const payload = {
        full_name: fullNameInput.trim(),
        username: usernameInput.trim(),
        phone: phoneInput.trim() || null,
        ...(passwordInput.trim() ? { password: passwordInput.trim() } : {})
      };

      let updatedUser = await updateUserProfile(token, profileUser.id, payload);
      if (selectedAvatarBlob) {
        updatedUser = await uploadUserAvatar(
          token,
          profileUser.id,
          selectedAvatarBlob,
          `avatar_${Date.now()}.png`
        );
      }

      setProfileUser(updatedUser);
      storage.setUser(updatedUser);
      setIsEditOpen(false);
    } catch (err) {
      setProfileError(err instanceof Error ? err.message : "تعذر تحديث معلومات الموظف");
    } finally {
      setIsSavingProfile(false);
    }
  }

  function normalizeWhatsappPhone(raw: string): string {
    const digits = raw.replace(/\D/g, "");
    if (digits.startsWith("964")) return digits;
    if (digits.startsWith("0")) return `964${digits.slice(1)}`;
    return digits;
  }

  function openWhatsapp(phone: string) {
    const normalized = normalizeWhatsappPhone(phone);
    const url = `https://wa.me/${normalized}`;
    window.open(url, "_blank", "noopener,noreferrer");
  }

  function logout() {
    storage.clear();
    router.replace("/");
  }

  async function openQuickAction(customer: Customer, action: "status" | "note" | "deal") {
    setActiveCustomer(customer);
    setQuickAction(action);
    setQuickError("");
    setQuickStatus(customer.status ?? "potential");
    setQuickNote("");
    setSalesNotes([]);
    setCustomerDeals([]);
    setDealMode("create");
    if (action === "note" && token) {
      setNoteLoading(true);
      try {
        const notes = await listCustomerSalesNotes(token, customer.id);
        setSalesNotes(notes);
      } catch {
        setSalesNotes([]);
      } finally {
        setNoteLoading(false);
      }
    }
    if (action === "deal" && token) {
      setDealLoading(true);
      try {
        const deals = await listCustomerDeals(token, customer.id);
        setCustomerDeals(deals);
        setDealMode(deals.length ? "view" : "create");
      } catch {
        setCustomerDeals([]);
        setDealMode("create");
      } finally {
        setDealLoading(false);
      }
    }
  }

  function closeQuickAction() {
    setQuickAction(null);
    setActiveCustomer(null);
    setQuickError("");
    setQuickNote("");
    setSalesNotes([]);
    setCustomerDeals([]);
    setDealMode("create");
  }

  async function submitStatus() {
    if (!token || !activeCustomer) return;
    setQuickSaving(true);
    setQuickError("");
    try {
      await updateCustomer(token, activeCustomer.id, { status: quickStatus });
      await reloadCustomers();
      closeQuickAction();
    } catch (err) {
      setQuickError(err instanceof Error ? err.message : "تعذر تحديث حالة الزبون");
    } finally {
      setQuickSaving(false);
    }
  }

  async function submitNote() {
    if (!token || !activeCustomer || !quickNote.trim()) return;
    setQuickSaving(true);
    setQuickError("");
    try {
      const created = await addCustomerSalesNote(token, activeCustomer.id, quickNote.trim());
      setSalesNotes((prev) => [created, ...prev]);
      setQuickNote("");
      await reloadCustomers();
    } catch (err) {
      setQuickError(err instanceof Error ? err.message : "تعذر إضافة الملاحظة");
    } finally {
      setQuickSaving(false);
    }
  }

  async function submitDeal() {
    if (!token || !activeCustomer) return;
    const totalPrice = Number(dealForm.totalPrice);
    const downPayment = Number(dealForm.downPayment);
    const houseArea = dealForm.houseArea.trim() ? Number(dealForm.houseArea) : null;
    if (!Number.isFinite(totalPrice) || totalPrice <= 0) {
      setQuickError("السعر الكلي غير صالح");
      return;
    }
    if (!Number.isFinite(downPayment) || downPayment < 0) {
      setQuickError("الدفعة الأولى غير صالحة");
      return;
    }
    if (houseArea !== null && (!Number.isFinite(houseArea) || houseArea <= 0)) {
      setQuickError("المساحة غير صالحة");
      return;
    }

    setQuickSaving(true);
    setQuickError("");
    try {
      await createDeal(token, {
        customer_id: activeCustomer.id,
        name: activeCustomer.name,
        profession: activeCustomer.profession,
        email: activeCustomer.email,
        phone: activeCustomer.phone,
        house_type: dealForm.houseType as "house" | "villa",
        total_price: totalPrice,
        payment_type: dealForm.paymentType as "cash" | "half_cash" | "installments",
        down_payment: downPayment,
        house_area: houseArea,
        residential_block: dealForm.block.trim() || null,
        house_number: dealForm.houseNumber.trim() || null,
        notes: dealForm.notes.trim() || null
      });
      await updateCustomer(token, activeCustomer.id, { status: "buyer" });
      const deals = await listCustomerDeals(token, activeCustomer.id);
      setCustomerDeals(deals);
      setDealMode("view");
      await reloadCustomers();
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
    } catch (err) {
      setQuickError(err instanceof Error ? err.message : "تعذر إضافة الصفقة");
    } finally {
      setQuickSaving(false);
    }
  }

  if (loading) {
    return (
      <main className={styles.salesDashboard}>
        <section className={styles.loadingPanel}>جارِ التحميل...</section>
      </main>
    );
  }

  return (
    <main className={styles.salesDashboard}>
      <section className={styles.mobileFrame}>
        <header className={styles.salesHero}>
          <div className={styles.salesHeroOverlay} />
          <div className={styles.salesHeroTop}>
            <div className={styles.salesHeroActions}>
              <div className={styles.salesAvatar}>
                {shouldShowAvatarImage ? (
                  <img
                    src={avatarSrc ?? ""}
                    alt={profileUser?.full_name ?? "صورة الموظف"}
                    onError={() => setAvatarLoadFailed(true)}
                  />
                ) : (
                  <span>{(profileUser?.full_name?.slice(0, 1) ?? "S").toUpperCase()}</span>
                )}
              </div>
              <button className={styles.editProfileBtn} type="button" onClick={openProfileEditor}>
                تعديل
              </button>
            </div>
            <div className={styles.salesBrand}>
              <img
                className={styles.salesLogo}
                src="/assets/Premium Gold and Teal Real Estate Emblem.png"
                alt="لوكو عماد سكر"
              />
              <strong>عماد سكر</strong>
              <small>نظام ادراة مبيعات المجمع</small>
            </div>
            <button
              className={styles.logoutIconBtn}
              type="button"
              onClick={logout}
              aria-label="تسجيل خروج"
              title="تسجيل خروج"
            >
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
          <div className={styles.salesHeroTitle}>
            <h1>مرحباً {profileUser?.full_name ?? "أحمد"}</h1>
            <p>موظف المبيعات</p>
          </div>

          <div className={styles.salesStats}>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>👥</span>
              <strong>{counts.all}</strong>
              <small>عدد زبائني</small>
            </article>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>📅</span>
              <strong>{counts.today}</strong>
              <small>عدد زبائن اليوم</small>
            </article>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>🗓️</span>
              <strong>{counts.month}</strong>
              <small>عدد زبائن الشهر</small>
            </article>
            <article className={styles.statCard}>
              <span className={styles.statIcon}>🤝</span>
              <strong>{counts.buyers}</strong>
              <small>عدد المشترين فقط</small>
            </article>
          </div>
        </header>

        <section className={styles.salesBody}>
          <div className={styles.salesSearchRow}>
            <span className={`${styles.searchIcon} ${styles.searchIconPrimary}`} aria-hidden="true">
              ⌕
            </span>
            <input
              className={styles.salesSearchInput}
              placeholder="البحث عن زبون بالاسم او رقم الهاتف ..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
          </div>

          <div className={styles.salesPills}>
            <button
              className={`${styles.salesPill} ${activeStatus === "all" ? styles.salesPillActive : ""}`}
              type="button"
              onClick={() => setActiveStatus("all")}
            >
              جميع الزبائن ({counts.all})
            </button>
            {statusFilters.map((statusItem) => (
              <button
                key={statusItem.key}
                className={`${styles.salesPill} ${
                  activeStatus === statusItem.key ? styles.salesPillActive : ""
                }`}
                type="button"
                onClick={() => setActiveStatus(statusItem.key)}
              >
                {statusItem.label} ({statusItem.count})
              </button>
            ))}
          </div>

          <div className={styles.salesDateFilters}>
            <label className={styles.salesDateField}>
              <span className={styles.salesDateCaption}>من</span>
              <input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} />
            </label>
            <label className={styles.salesDateField}>
              <span className={styles.salesDateCaption}>إلى</span>
              <input type="date" value={toDate} onChange={(e) => setToDate(e.target.value)} />
            </label>
          </div>

          {error ? <p className={styles.error}>{error}</p> : null}
          {loadingCustomers ? <p className={styles.muted}>جارِ تحميل الزبائن...</p> : null}

          <div className={styles.salesCards}>
            {!loadingCustomers && filtered.length === 0 ? (
              <article className={styles.salesCustomerCard}>
                <div className={styles.salesEmpty}>لا يوجد زبائن مسجلين لك</div>
              </article>
            ) : null}

            {filtered.map((customer) => {
              const date = formatCardDate(customer.updated_at ?? customer.created_at);
              const statusText = STATUS_LABELS[customer.status ?? ""] ?? "مهتم";
              return (
                <article key={customer.id} className={styles.salesCustomerCard}>
                  <div className={styles.salesCardMain}>
                    <div className={styles.salesCardImage}>
                      <img src="/assets/Faceless Corporate Real Estate Avatar.png" alt="صورة الزبون" />
                    </div>

                    <div className={styles.salesCardInfo}>
                      <h3>{customer.name}</h3>
                      <p className={styles.salesPhone}>{customer.phone}</p>
                      <div className={styles.salesTags}>
                        <span className={`${styles.salesTag} ${styles.status}`}>{statusText}</span>
                      </div>
                    </div>

                    <div className={styles.salesCardDate}>
                      <small>اخر زيارة</small>
                      <strong>{date.day}</strong>
                      <span>{date.monthYear}</span>
                    </div>
                  </div>

                  <div className={styles.salesCardActions}>
                    <button type="button" onClick={() => openWhatsapp(customer.phone)}>
                      تواصل
                    </button>
                    <button type="button" onClick={() => void openQuickAction(customer, "note")}>
                      ملاحظة
                    </button>
                    <button type="button" onClick={() => void openQuickAction(customer, "deal")}>
                      {isBuyerStatus(customer.status) ? "عرض الصفقة" : "إضافة صفقة"}
                    </button>
                    <button type="button" onClick={() => void openQuickAction(customer, "status")}>
                      الحالة
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        </section>

        {quickAction && activeCustomer ? (
          <section
            className={`${styles.profileModal} ${styles.quickModal} ${
              quickAction === "note"
                ? styles.noteQuickModal
                : quickAction === "deal"
                  ? styles.dealQuickModal
                  : quickAction === "status"
                    ? styles.statusQuickModal
                  : ""
            }`}
          >
            <div
              className={`${styles.profileCard} ${styles.quickCard} ${
                quickAction === "note"
                  ? styles.noteQuickCard
                  : quickAction === "deal"
                    ? styles.dealQuickCard
                    : quickAction === "status"
                      ? styles.statusQuickCard
                    : ""
              }`}
            >
              <h3
                className={
                  quickAction === "note"
                    ? styles.noteQuickTitle
                    : quickAction === "deal"
                      ? styles.dealQuickTitleHidden
                      : quickAction === "status"
                        ? styles.statusQuickTitle
                      : ""
                }
              >
                {quickAction === "status"
                  ? "تغيير حالة الزبون"
                  : quickAction === "note"
                    ? "إضافة ملاحظة"
                    : "إضافة صفقة"}
              </h3>

              {quickAction === "status" ? (
                <label className={`${styles.profileLabel} ${styles.statusFieldLabel}`}>
                  الحالة
                  <select
                    className={`${styles.profileInput} ${styles.statusSelect}`}
                    value={quickStatus}
                    onChange={(e) => setQuickStatus(e.target.value)}
                  >
                    <option value="potential">محتمل</option>
                    <option value="interested">مهتم</option>
                    <option value="hesitant">متردد</option>
                    <option value="reservation">زيارة مجدولة</option>
                    <option value="not_interested">غير مهتم</option>
                    <option value="buyer">تم الشراء</option>
                  </select>
                </label>
              ) : null}

              {quickAction === "note" ? (
                <div className={styles.noteQuickLayout}>
                  <div className={styles.noteQuickTopBar}>
                    <div>
                      <p className={styles.noteQuickCustomerLabel}>الزبون المستهدف</p>
                      <strong className={styles.noteQuickCustomerName}>{activeCustomer.name}</strong>
                    </div>
                    <span className={styles.noteQuickCountPill}>
                      {salesNotes.length} {salesNotes.length === 1 ? "ملاحظة" : "ملاحظات"}
                    </span>
                  </div>

                  <label className={styles.noteComposerPanel}>
                    <span className={styles.noteComposerTitle}>ملاحظة جديدة</span>
                    <textarea
                      className={`${styles.profileInput} ${styles.noteComposerInput}`}
                      value={quickNote}
                      onChange={(e) => setQuickNote(e.target.value)}
                      placeholder="دوّن آخر تفاعل مع الزبون، الاعتراضات، والمتابعة القادمة..."
                      rows={5}
                    />
                    <span className={styles.noteComposerHint}>
                      كل ملاحظة تحفظ تلقائيا في سجل متابعة الزبون.
                    </span>
                  </label>

                  <div className={styles.noteTimelinePanel}>
                    <h4>سجل الملاحظات السابقة</h4>
                    <div className={styles.noteHistoryBox}>
                      {noteLoading ? (
                        <p className={styles.noteHistoryState}>جارِ تحميل الملاحظات...</p>
                      ) : salesNotes.length ? (
                        salesNotes.map((note) => (
                          <div key={note.id} className={styles.noteHistoryItem}>
                            <strong>{new Date(note.created_at).toLocaleString("ar-IQ")}</strong>
                            <p>{note.note}</p>
                          </div>
                        ))
                      ) : (
                        <p className={styles.noteHistoryState}>لا توجد ملاحظات سابقة</p>
                      )}
                    </div>
                  </div>
                </div>
              ) : null}

              {quickAction === "deal" ? (
                <div className={styles.dealQuickLayout}>
                  <div className={styles.dealQuickHero}>
                    <img
                      src="/assets/Twilight Modern Villa Pool Retreat.png"
                      alt="فيلا"
                      className={styles.dealQuickHeroImage}
                    />
                    <button type="button" className={styles.dealQuickClose} onClick={closeQuickAction}>
                      ×
                    </button>
                    <div className={styles.dealQuickHeroHeader}>
                      <h2>{dealMode === "view" ? "عرض الصفقة" : "إضافة صفقة"}</h2>
                      <p>{dealMode === "view" ? "معلومات صفقة البيع الحالية" : "إضافة صفقة جديدة للزبون"}</p>
                    </div>
                    <div className={styles.dealQuickTopBar}>
                      <div className={styles.dealQuickAvatarWrap}>
                        <img
                          src="/assets/Faceless Corporate Real Estate Avatar.png"
                          alt="صورة الزبون"
                          className={styles.dealQuickAvatar}
                        />
                      </div>
                      <div className={styles.dealQuickCustomerText}>
                        <strong className={styles.dealQuickCustomerName}>{activeCustomer.name}</strong>
                      </div>
                    </div>
                  </div>

                  {dealLoading ? (
                    <div className={styles.dealLoadingState}>جارِ تحميل بيانات الصفقة...</div>
                  ) : dealMode === "view" && customerDeals.length ? (
                    <div className={styles.dealViewLayout}>
                      <section className={styles.dealQuickPanel}>
                        <h4>تفاصيل الصفقة</h4>
                        <div className={styles.dealViewGrid}>
                          <div className={styles.dealViewItem}>
                            <small>نوع العقار</small>
                            <strong>{HOUSE_TYPE_LABELS[customerDeals[0].house_type]}</strong>
                          </div>
                          <div className={styles.dealViewItem}>
                            <small>نوع الدفع</small>
                            <strong>{PAYMENT_TYPE_LABELS[customerDeals[0].payment_type]}</strong>
                          </div>
                          <div className={styles.dealViewItem}>
                            <small>السعر الكلي</small>
                            <strong>{formatAmount(customerDeals[0].total_price)} د.ع</strong>
                          </div>
                          <div className={styles.dealViewItem}>
                            <small>الدفعة الأولى</small>
                            <strong>{formatAmount(customerDeals[0].down_payment)} د.ع</strong>
                          </div>
                          <div className={styles.dealViewItem}>
                            <small>المساحة</small>
                            <strong>{customerDeals[0].house_area ?? "-"}</strong>
                          </div>
                          <div className={styles.dealViewItem}>
                            <small>البلوك / رقم الدار</small>
                            <strong>
                              {customerDeals[0].residential_block || "-"} / {customerDeals[0].house_number || "-"}
                            </strong>
                          </div>
                        </div>
                        <div className={styles.dealViewNote}>
                          <small>ملاحظة الصفقة</small>
                          <p>{customerDeals[0].notes?.trim() || "لا توجد ملاحظة"}</p>
                        </div>
                      </section>
                    </div>
                  ) : (
                    <div className={styles.dealQuickGrid}>
                      <section className={styles.dealQuickPanel}>
                        <h4>نوع العقار والدفع</h4>
                        <div className={styles.quickDealGrid}>
                          <label className={styles.profileLabel}>
                            نوع العقار
                            <select
                              className={styles.profileInput}
                              value={dealForm.houseType}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, houseType: e.target.value }))}
                            >
                              <option value="house">دار</option>
                              <option value="villa">فيلا</option>
                            </select>
                          </label>
                          <label className={styles.profileLabel}>
                            نوع الدفع
                            <select
                              className={styles.profileInput}
                              value={dealForm.paymentType}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, paymentType: e.target.value }))}
                            >
                              <option value="cash">كاش</option>
                              <option value="half_cash">نصف كاش</option>
                              <option value="installments">دفعات</option>
                            </select>
                          </label>
                        </div>
                      </section>

                      <section className={styles.dealQuickPanel}>
                        <h4>التفاصيل المالية</h4>
                        <div className={styles.quickDealGrid}>
                          <label className={styles.profileLabel}>
                            السعر الكلي
                            <input
                              className={styles.profileInput}
                              value={dealForm.totalPrice}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, totalPrice: e.target.value }))}
                              inputMode="decimal"
                            />
                          </label>
                          <label className={styles.profileLabel}>
                            الدفعة الأولى
                            <input
                              className={styles.profileInput}
                              value={dealForm.downPayment}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, downPayment: e.target.value }))}
                              inputMode="decimal"
                            />
                          </label>
                        </div>
                      </section>

                      <section className={styles.dealQuickPanel}>
                        <h4>موقع العقار</h4>
                        <div className={styles.quickDealGrid}>
                          <label className={styles.profileLabel}>
                            المساحة
                            <input
                              className={styles.profileInput}
                              value={dealForm.houseArea}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, houseArea: e.target.value }))}
                              inputMode="decimal"
                            />
                          </label>
                          <label className={styles.profileLabel}>
                            البلوك
                            <input
                              className={styles.profileInput}
                              value={dealForm.block}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, block: e.target.value }))}
                            />
                          </label>
                          <label className={styles.profileLabel}>
                            رقم الدار
                            <input
                              className={styles.profileInput}
                              value={dealForm.houseNumber}
                              onChange={(e) => setDealForm((prev) => ({ ...prev, houseNumber: e.target.value }))}
                            />
                          </label>
                        </div>
                      </section>

                      <section className={`${styles.dealQuickPanel} ${styles.dealQuickNotesPanel}`}>
                        <h4>ملاحظة الصفقة</h4>
                        <label className={styles.profileLabel}>
                          تفاصيل إضافية
                          <textarea
                            className={`${styles.profileInput} ${styles.dealQuickTextarea}`}
                            value={dealForm.notes}
                            onChange={(e) => setDealForm((prev) => ({ ...prev, notes: e.target.value }))}
                            rows={4}
                            placeholder="اكتب تفاصيل مهمة عن التفاوض، التوقيت، أو شروط العميل..."
                          />
                        </label>
                      </section>
                    </div>
                  )}

                </div>
              ) : null}

              {quickError ? <p className={styles.profileError}>{quickError}</p> : null}

              <div
                className={`${styles.profileActions} ${
                  quickAction === "note"
                    ? styles.noteQuickActions
                    : quickAction === "deal"
                      ? styles.dealQuickActions
                      : quickAction === "status"
                        ? styles.statusQuickActions
                      : ""
                }`}
              >
                <button type="button" onClick={closeQuickAction}>
                  إلغاء
                </button>
                <button
                  type="button"
                  disabled={
                    quickSaving ||
                    (quickAction === "note" && !quickNote.trim())
                  }
                  onClick={
                    quickAction === "status"
                      ? submitStatus
                      : quickAction === "note"
                        ? submitNote
                        : dealMode === "view"
                          ? () => setDealMode("create")
                          : submitDeal
                  }
                >
                  {quickAction === "deal"
                    ? dealMode === "view"
                      ? "إضافة صفقة أخرى"
                      : quickSaving
                        ? "جارِ الحفظ..."
                        : "حفظ الصفقة"
                    : quickSaving
                      ? "جارِ الحفظ..."
                      : "حفظ"}
                </button>
              </div>
            </div>
          </section>
        ) : null}

        {isEditOpen ? (
          <section className={styles.profileModal}>
            <div className={styles.profileCard}>
              <h3>تعديل معلومات الموظف</h3>

              <div className={styles.profileAvatarEditor}>
                <div className={styles.profileAvatarPreview}>
                  {shouldShowAvatarImage ? (
                    <img
                      src={avatarSrc ?? ""}
                      alt="معاينة صورة الموظف"
                      onError={() => setAvatarLoadFailed(true)}
                    />
                  ) : (
                    <span>{(profileUser?.full_name?.slice(0, 1) ?? "S").toUpperCase()}</span>
                  )}
                </div>
                <label className={styles.avatarInputButton}>
                  اختيار صورة
                  <input accept="image/*" type="file" onChange={onSelectAvatar} />
                </label>
              </div>

              <label className={styles.profileLabel}>
                الاسم
                <input
                  className={styles.profileInput}
                  value={fullNameInput}
                  onChange={(e) => setFullNameInput(e.target.value)}
                />
              </label>
              <label className={styles.profileLabel}>
                يوزر نيم
                <input
                  className={styles.profileInput}
                  value={usernameInput}
                  onChange={(e) => setUsernameInput(e.target.value)}
                />
              </label>
              <label className={styles.profileLabel}>
                كلمة السر
                <input
                  className={styles.profileInput}
                  value={passwordInput}
                  onChange={(e) => setPasswordInput(e.target.value)}
                  type="password"
                  placeholder="اتركها فارغة بدون تغيير"
                />
              </label>
              <label className={styles.profileLabel}>
                رقم الهاتف
                <input
                  className={styles.profileInput}
                  value={phoneInput}
                  onChange={(e) => setPhoneInput(e.target.value)}
                />
              </label>

              {profileError ? <p className={styles.profileError}>{profileError}</p> : null}

              <div className={styles.profileActions}>
                <button type="button" onClick={() => setIsEditOpen(false)}>
                  إلغاء
                </button>
                <button type="button" onClick={saveProfile} disabled={isSavingProfile}>
                  {isSavingProfile ? "جارِ الحفظ..." : "حفظ"}
                </button>
              </div>
            </div>
          </section>
        ) : null}

        {cropSource ? (
          <section className={styles.cropperModal}>
            <div className={styles.cropperCard}>
              <h3>اقتصاص الصورة 1:1</h3>
              <div className={styles.cropperSquare}>
                <img
                  src={cropSource}
                  alt="اقتصاص"
                  style={{
                    transform: `translate(${cropOffsetX}px, ${cropOffsetY}px) scale(${cropZoom})`
                  }}
                />
              </div>

              <label className={styles.cropControl}>
                التكبير
                <input
                  type="range"
                  min="1"
                  max="2.5"
                  step="0.01"
                  value={cropZoom}
                  onChange={(e) => setCropZoom(Number(e.target.value))}
                />
              </label>
              <label className={styles.cropControl}>
                تحريك افقي
                <input
                  type="range"
                  min="-120"
                  max="120"
                  step="1"
                  value={cropOffsetX}
                  onChange={(e) => setCropOffsetX(clamp(Number(e.target.value), -120, 120))}
                />
              </label>
              <label className={styles.cropControl}>
                تحريك عمودي
                <input
                  type="range"
                  min="-120"
                  max="120"
                  step="1"
                  value={cropOffsetY}
                  onChange={(e) => setCropOffsetY(clamp(Number(e.target.value), -120, 120))}
                />
              </label>

              <div className={styles.cropperActions}>
                <button type="button" onClick={() => setCropSource(null)}>
                  إلغاء
                </button>
                <button type="button" onClick={applyCrop}>
                  تطبيق القص
                </button>
              </div>
            </div>
          </section>
        ) : null}

      </section>
    </main>
  );
}
