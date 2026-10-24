"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { getRoleHome } from "@/lib/auth";
import { login } from "@/lib/api";
import { storage } from "@/lib/storage";

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [rememberMe, setRememberMe] = useState(true);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setError("");

    try {
      const response = await login(username, password);
      storage.setToken(response.access_token);
      storage.setUser(response.user);
      router.replace(getRoleHome(response.user.role));
    } catch (err) {
      setError(err instanceof Error ? err.message : "حدث خطأ أثناء تسجيل الدخول");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-screen">
      <div className="login-overlay" />
      <div className="login-floating-glow login-floating-glow-top" />
      <div className="login-floating-glow login-floating-glow-bottom" />

      <section className="login-shell">
        <header className="login-brand fade-up">
          <Image
            className="login-logo"
            src="/assets/Premium%20Gold%20and%20Teal%20Real%20Estate%20Emblem.png"
            alt="شعار عماد السكن"
            width={94}
            height={94}
            priority
          />
          <h1>عماد السكن</h1>
          <p>نظام إدارة المبيعات</p>
        </header>

        <article className="login-card fade-up" style={{ animationDelay: "120ms" }}>
          <h2>مرحبا بعودتك</h2>
          <p>سجل الدخول للوصول إلى حسابك</p>

          <form onSubmit={onSubmit} className="login-form">
            {error ? <p className="error">{error}</p> : null}

            <label className="login-field">
              <span className="login-icon">✉</span>
              <input
                className="login-input"
                placeholder="اسم المستخدم أو البريد الإلكتروني"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                required
              />
            </label>

            <label className="login-field">
              <span className="login-icon">🔒</span>
              <input
                className="login-input"
                type="password"
                placeholder="كلمة المرور"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </label>

            <div className="login-meta-row">
              <button type="button" className="login-link-btn">
                نسيت كلمة المرور؟
              </button>

              <label className="remember-wrap">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                />
                <span>تذكرني</span>
              </label>
            </div>

            <button className="login-btn-primary" disabled={loading} type="submit">
              <span>{loading ? "جارِ تسجيل الدخول..." : "تسجيل الدخول"}</span>
              <b aria-hidden>›</b>
            </button>
          </form>
        </article>
      </section>
    </main>
  );
}
