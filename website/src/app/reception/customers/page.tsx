"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { CustomerCard } from "@/components/customer-card";
import { listCustomers } from "@/lib/api";
import { useProtectedPage } from "@/lib/auth";
import { storage } from "@/lib/storage";
import type { Customer } from "@/types";

export default function ReceptionCustomersPage() {
  const router = useRouter();
  const { user, token, loading } = useProtectedPage(["reception"]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [query, setQuery] = useState("");
  const [error, setError] = useState("");
  const [fetching, setFetching] = useState(false);

  useEffect(() => {
    if (!token) return;
    let active = true;

    async function load() {
      setFetching(true);
      setError("");
      try {
        const data = await listCustomers(token, query);
        if (active) setCustomers(data.items);
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : "فشل تحميل الزبائن");
      } finally {
        if (active) setFetching(false);
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [token, query]);

  if (loading) {
    return (
      <main className="shell">
        <section className="panel">جارِ التحقق من الجلسة...</section>
      </main>
    );
  }

  return (
    <main className="shell">
      <section className="panel">
        <div className="row">
          <div>
            <h1 className="title">زبائن موظف الاستقبال</h1>
            <p className="muted">{user?.full_name}</p>
          </div>
          <button
            className="button secondary"
            style={{ width: "auto", padding: "8px 12px" }}
            onClick={() => {
              storage.clear();
              router.replace("/");
            }}
            type="button"
          >
            خروج
          </button>
        </div>

        <input
          className="input"
          placeholder="بحث بالاسم أو الهاتف"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />

        {error ? <p className="error">{error}</p> : null}
        {fetching ? <p className="muted">جارِ تحميل الزبائن...</p> : null}

        <div className="stack">
          {customers.map((customer) => (
            <CustomerCard key={customer.id} customer={customer} />
          ))}
          {!fetching && customers.length === 0 ? (
            <p className="muted">لا يوجد زبائن مطابقين للبحث.</p>
          ) : null}
        </div>
      </section>
    </main>
  );
}
