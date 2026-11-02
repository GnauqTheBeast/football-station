// src/app/layout.tsx - Root layout: sidebar + main.
import "./globals.css";
import { ReactNode } from "react";
import { Sidebar } from "@/components/Sidebar";
import { getStationInfo } from "@/lib/station";
import { getRole } from "@/lib/db";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "V-League Pro • Ban Điều Hành Đề Tài 13 (CSDL Phân Tán FDW)",
  description: "Hệ thống quản lý giải bóng đá V-League phân tán kiến trúc postgres_fdw",
};

export default async function RootLayout({ children }: { children: ReactNode }) {
  const role = getRole();
  const station = await getStationInfo();

  return (
    <html lang="vi">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Outfit:wght@500;600;700;800;900&family=Space+Grotesk:wght@400;500;600;700&display=swap"
          rel="stylesheet"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>
        <div className="shell">
          <Sidebar station={station} role={role} />
          <main className="main">{children}</main>
        </div>
      </body>
    </html>
  );
}
