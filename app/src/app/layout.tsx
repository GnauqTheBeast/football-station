// src/app/layout.tsx - Root layout: SSR, dark theme, header per request.
import "./globals.css";
import { ReactNode } from "react";
import { Header } from "@/components/Header";
import { getStationInfo } from "@/lib/station";
import { getRole } from "@/lib/db";

export const dynamic = "force-dynamic"; // Always SSR - data changes with replication.

export default async function RootLayout({ children }: { children: ReactNode }) {
  const role = getRole();
  const station = await getStationInfo();

  return (
    <html lang="vi">
      <body>
        <Header station={station} role={role} />
        <main className="container">{children}</main>
      </body>
    </html>
  );
}
