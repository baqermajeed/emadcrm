import type { Customer } from "@/types";

interface CustomerCardProps {
  customer: Customer;
}

export function CustomerCard({ customer }: CustomerCardProps) {
  return (
    <article className="card">
      <header className="card-header">
        <h3>{customer.name}</h3>
        <span className="badge">{customer.status ?? "potential"}</span>
      </header>

      <div className="card-grid">
        <p>
          <strong>الهاتف:</strong> {customer.phone}
        </p>
        <p>
          <strong>العنوان:</strong> {customer.address ?? "-"}
        </p>
        <p>
          <strong>المهنة:</strong> {customer.profession ?? "-"}
        </p>
        <p>
          <strong>موظف المبيعات:</strong> {customer.sales_employee_name ?? "-"}
        </p>
      </div>

      {customer.notes ? (
        <p className="notes">
          <strong>ملاحظات:</strong> {customer.notes}
        </p>
      ) : null}
    </article>
  );
}
