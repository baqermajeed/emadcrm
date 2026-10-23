import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Emad CRM Web",
  description: "Mobile-first CRM for reception, sales, and manager"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
