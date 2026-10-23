"use client";

import { FormEvent, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { getRoleHome } from "@/lib/auth";
import { login } from "@/lib/api";
import { storage } from "@/lib/storage";

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const demoAccounts = useMemo(
    () => [
      "reception / 123456",
      "sales1 / 123456",
      "sales2 / 123456",
      "manager / 123456"
    ],
    []
  );

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
    <main className="shell">
      <section className="panel">
        <h1 className="title">تسجيل الدخول - Emad CRM</h1>
        <p className="muted">واجهة ويب موبايل لموظف الاستقبال والمبيعات والمدير.</p>
        <p className="muted">
          API: <code>Proxy {"->"} BACKEND_BASE_URL</code>
        </p>

        <form onSubmit={onSubmit}>
          {error ? <p className="error">{error}</p> : null}
          <input
            className="input"
            placeholder="اسم المستخدم"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
          <input
            className="input"
            type="password"
            placeholder="كلمة المرور"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button className="button" disabled={loading} type="submit">
            {loading ? "جارِ تسجيل الدخول..." : "دخول"}
          </button>
        </form>

        <p className="muted" style={{ marginTop: 12 }}>
          حسابات تجريبية: {demoAccounts.join(" | ")}
        </p>
      </section>
    </main>
  );
}
