"use client";

import { useRouter } from "next/navigation";
import { useProtectedPage } from "@/lib/auth";
import { storage } from "@/lib/storage";

export default function ManagerPage() {
  const router = useRouter();
  const { user, loading } = useProtectedPage(["manager"]);

  if (loading) {
    return (
      <main className="shell">
        <section className="panel">جارِ التحميل...</section>
      </main>
    );
  }

  return (
    <main className="shell">
      <section className="panel">
        <h1 className="title">واجهة المدير</h1>
        <p className="muted">مرحباً {user?.full_name}. هذه صفحة أولية للتقارير ولوحات المتابعة.</p>
        <button
          className="button"
          onClick={() => {
            storage.clear();
            router.replace("/");
          }}
          type="button"
        >
          تسجيل خروج
        </button>
      </section>
    </main>
  );
}
