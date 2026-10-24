import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const lamaSans = localFont({
  src: "../../../frontend_desc/assets/fonts/LamaSans-SemiBold.otf",
  weight: "600",
  style: "normal",
  display: "swap"
});

export const metadata: Metadata = {
  title: "Emad CRM Web",
  description: "Mobile-first CRM for reception, sales, and manager"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body className={lamaSans.className}>{children}</body>
    </html>
  );
}
