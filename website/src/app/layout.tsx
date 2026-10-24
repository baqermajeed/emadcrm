import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const lamaSans = localFont({
  src: [
    {
      path: "../../../frontend_desc/assets/fonts/LamaSans-Regular.otf",
      weight: "400",
      style: "normal"
    },
    {
      path: "../../../frontend_desc/assets/fonts/LamaSans-Medium.otf",
      weight: "500",
      style: "normal"
    },
    {
      path: "../../../frontend_desc/assets/fonts/LamaSans-SemiBold.otf",
      weight: "600",
      style: "normal"
    },
    {
      path: "../../../frontend_desc/assets/fonts/LamaSans-Bold.otf",
      weight: "700",
      style: "normal"
    },
    {
      path: "../../../frontend_desc/assets/fonts/LamaSans-Bold.otf",
      weight: "800",
      style: "normal"
    },
    {
      path: "../../../frontend_desc/assets/fonts/LamaSans-Bold.otf",
      weight: "900",
      style: "normal"
    }
  ],
  variable: "--font-lama-sans",
  display: "swap"
});

export const metadata: Metadata = {
  title: "Emad CRM Web",
  description: "Mobile-first CRM for reception, sales, and manager"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body className={`${lamaSans.className} ${lamaSans.variable}`}>{children}</body>
    </html>
  );
}
