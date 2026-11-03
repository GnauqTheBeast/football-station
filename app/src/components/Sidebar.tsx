"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { StationInfo } from "@/lib/types";

interface NavItem {
  href: string;
  label: string;
  icon: string;
  badge?: string;
  badgeColor?: string;
}

const NAV_MASTER: NavItem[] = [
  { href: "/", label: "Tổng quan giải", icon: "dashboard" },
  { href: "/fixtures", label: "Lịch thi đấu (10 Vòng)", icon: "calendar_month", badge: "6 ĐỘI", badgeColor: "rose" },
  { href: "/standings", label: "Bảng xếp hạng", icon: "format_list_numbered" },
  { href: "/scorers", label: "Vua phá lưới", icon: "military_tech" },
  { href: "/clubs", label: "CLB & Cầu thủ", icon: "groups" },
  { href: "/revenue", label: "Doanh thu sân & Vé", icon: "stadium" },
  { href: "/admin/ref", label: "Quản trị Master", icon: "admin_panel_settings", badge: "Tổ 4 TT", badgeColor: "indigo" },
];

const NAV_STATION: NavItem[] = [
  { href: "/", label: "Tổng quan sân nhà", icon: "dashboard" },
  { href: "/fixtures", label: "Lịch thi đấu trạm", icon: "calendar_month" },
  { href: "/admin/new-match-result", label: "Biên bản & Ghi nhận", icon: "assignment", badge: "LIVE SYNC", badgeColor: "emerald" },
];

export function Sidebar({ station, role }: { station: StationInfo; role: "master" | "station" }) {
  const pathname = usePathname() ?? "/";
  const nav = role === "master" ? NAV_MASTER : NAV_STATION;
  const isActive = (href: string) =>
    href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(href + "/");

  return (
    <aside className="sidebar">
      {/* Brand Header */}
      <div className="sidebar-brand">
        <div className="brand-logo">
          <span className="material-symbols-outlined">sports_soccer</span>
        </div>
        <div className="brand-text">
          <div className="brand-title">
            V-LEAGUE<span className="brand-accent">PRO</span>
          </div>
          <p className="brand-sub">ĐỀ TÀI 13 • DBMS FDW</p>
        </div>
      </div>

      {/* Nav List */}
      <nav className="sidebar-nav">
        {nav.map((item) => {
          const active = isActive(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`nav-item ${active ? "active" : ""}`}
            >
              <div className="nav-item-inner">
                <span className="material-symbols-outlined nav-icon">{item.icon}</span>
                <span className="nav-label">{item.label}</span>
              </div>
              {item.badge && (
                <span className={`nav-badge ${item.badgeColor ?? "blue"}`}>
                  {item.badge}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* League Promo Card */}
      <div className="sidepromo">
        <div className="sidepromo-icon">
          <span className="material-symbols-outlined">trophy</span>
        </div>
        <div className="sidepromo-title">V-LEAGUE 1 · 2025/2026</div>
        <div className="sidepromo-sub">
          {role === "master"
            ? "Mạng lưới CSDL phân tán 5 trạm qua ZeroTier VPN mesh."
            : `Trạm cục bộ: Dữ liệu sân nhà CLB ${station.club}.`}
        </div>
        <Link href="/standings" className="sidepromo-link">
          Xem bảng xếp hạng &rarr;
        </Link>
      </div>

      {/* Node / Role Status Badge */}
      <div className="rolebadge">
        <div className="rolebadge-top">
          <span className="rolebadge-dot animate-pulse" />
          <strong className="rolebadge-name">
            {role === "master" ? "VFF MASTER" : station.station_name}
          </strong>
        </div>
        <div className="rolebadge-desc">
          {role === "master"
            ? "Ban Điều Hành VPF • Giám Sát #13"
            : `Đội nhà: ${station.club} • Sân vận động`}
        </div>
      </div>
    </aside>
  );
}
