"use client";

import { ChangeEvent, useEffect, useMemo, useState } from "react";
import { listCustomers, updateUserProfile, uploadUserAvatar } from "@/lib/api";
import { useProtectedPage } from "@/lib/auth";
import { storage } from "@/lib/storage";
import type { Customer } from "@/types";
import styles from "./sales.module.css";

const BACKEND_ORIGIN = process.env.NEXT_PUBLIC_BACKEND_ORIGIN ?? "https://emadcrm.compassaccuracy.com";
const CROP_SIZE = 280;

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
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  if (value.startsWith("/")) return `${BACKEND_ORIGIN}${value}`;
  return `${BACKEND_ORIGIN}/${value}`;
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
  canvas.width = 512;
  canvas.height = 512;
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
  exportCanvas.width = 512;
  exportCanvas.height = 512;
  const exportContext = exportCanvas.getContext("2d");
  if (!exportContext) throw new Error("تعذر تجهيز الصورة النهائية");
  exportContext.drawImage(canvas, 0, 0, 512, 512);

  const blob = await new Promise<Blob | null>((resolve) =>
    exportCanvas.toBlob((value) => resolve(value), "image/png", 0.95)
  );
  if (!blob) throw new Error("تعذر إنشاء الصورة النهائية");
  return blob;
}

export default function SalesPage() {
  const { user, token, loading } = useProtectedPage(["sales"]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [query, setQuery] = useState("");
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

  const avatarSrc = avatarPreview ?? resolveAvatarUrl(profileUser?.avatar_url);

  useEffect(() => {
    setProfileUser(user);
  }, [user]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return customers;
    return customers.filter((c) => {
      return (
        c.name.toLowerCase().includes(q) ||
        c.phone.toLowerCase().includes(q) ||
        (c.profession ?? "").toLowerCase().includes(q)
      );
    });
  }, [customers, query]);

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

      if (c.status === "buyer") buyers += 1;
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
                {avatarSrc ? (
                  <img src={avatarSrc} alt={profileUser?.full_name ?? "صورة الموظف"} />
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
          </div>
          <div className={styles.salesHeroTitle}>
            <h1>👋 مرحباً {profileUser?.full_name ?? "أحمد"}</h1>
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
            <button className={styles.salesFilterBtn} type="button">
              فلترة
            </button>
            <input
              className={styles.salesSearchInput}
              placeholder="البحث عن زبون بالاسم او رقم الهاتف ..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            <span className={styles.searchIcon}>⌕</span>
          </div>

          <div className={styles.salesPills}>
            <button className={`${styles.salesPill} ${styles.salesPillActive}`} type="button">
              جميع الزبائن ({counts.all})
            </button>
            <button className={styles.salesPill} type="button">
              زبائن اليوم ({counts.today})
            </button>
            <button className={styles.salesPill} type="button">
              زبائن الشهر ({counts.month})
            </button>
            <button className={styles.salesPill} type="button">
              المشترين ({counts.buyers})
            </button>
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
              const date = formatCardDate(customer.created_at);
              const statusText = STATUS_LABELS[customer.status ?? ""] ?? "مهتم";
              return (
                <article key={customer.id} className={styles.salesCustomerCard}>
                  <div className={styles.salesCardMain}>
                    <div className={styles.salesCardImage} />

                    <div className={styles.salesCardInfo}>
                      <h3>{customer.name}</h3>
                      <p className={styles.salesPhone}>{customer.phone}</p>
                      <div className={styles.salesTags}>
                        <span className={`${styles.salesTag} ${styles.status}`}>{statusText}</span>
                        <span className={`${styles.salesTag} ${styles.villa}`}>
                          فيلا {customer.booking_id?.slice(-3).toUpperCase() ?? "A12"}
                        </span>
                      </div>
                    </div>

                    <div className={styles.salesCardDate}>
                      <small>السبت</small>
                      <strong>{date.day}</strong>
                      <span>{date.monthYear}</span>
                    </div>
                  </div>

                  <div className={styles.salesCardActions}>
                    <button type="button">اتصال</button>
                    <button type="button">السجل</button>
                    <button type="button">ملاحظات</button>
                  </div>
                </article>
              );
            })}
          </div>
        </section>

        {isEditOpen ? (
          <section className={styles.profileModal}>
            <div className={styles.profileCard}>
              <h3>تعديل معلومات الموظف</h3>

              <div className={styles.profileAvatarEditor}>
                <div className={styles.profileAvatarPreview}>
                  {avatarSrc ? (
                    <img src={avatarSrc} alt="معاينة صورة الموظف" />
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

        <footer className={styles.bottomNav}>
          <button className={styles.navItem} type="button">
            <span>🏠</span>
            <small>الرئيسية</small>
          </button>
          <button className={`${styles.navItem} ${styles.navItemActive}`} type="button">
            <span>👥</span>
            <small>زبائني</small>
          </button>
          <button className={styles.addButton} type="button" aria-label="اضافة زبون">
            +
          </button>
          <button className={styles.navItem} type="button">
            <span>📅</span>
            <small>المواعيد</small>
          </button>
          <button className={styles.navItem} type="button">
            <span>⋯</span>
            <small>المزيد</small>
          </button>
        </footer>
      </section>
    </main>
  );
}
