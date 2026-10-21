// src/components/Header.tsx - Header with role badge and active link.
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { StationInfo } from "@/lib/types";

interface HeaderProps {
  station: StationInfo | null;
  role: "master" | "station";
}

const NAV = [
  { href: "/", label: "Dashboard" },
  { href: "/fixtures", label: "Lịch thi đấu" },
  { href: "/standings", label: "BXH" },
  { href: "/scorers", label: "Vua phá lưới" },
  { href: "/admin/new-match-result", label: "Nhập kết quả" },
  { href: "/admin/ref", label: "Ref data" },
];

export function Header({ station, role }: HeaderProps) {
  const pathname = usePathname() ?? "/";
  const badgeClass = role === "master" ? "badge master" : "badge station";
  const badgeText = role === "master" ? "MASTER" : `STATION ${station?.station_id ?? "?"}`;
  const subtitle = station
    ? `${station.station_name} - Sân ${station.stadium_name}`
    : "Station chưa xác định (sửa STATION_ID trong .env)";

  const isActive = (href: string) =>
    href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(href + "/");

  return (
    <header className="header">
      <div className="brand">
        Football DDB <span className={badgeClass}>{badgeText}</span>
        <small>{subtitle}</small>
      </div>
      <nav>
        {NAV.map((item) => (
          <Link key={item.href} href={item.href} className={isActive(item.href) ? "active" : ""}>
            {item.label}
          </Link>
        ))}
      </nav>
    </header>
  );
}
