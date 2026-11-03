// src/components/TeamBadge.tsx - Team badge: màu sắc trình bày theo mã CLB.
// Tên CLB/màu sắc là nhãn hiển thị. Sức chứa sân, HLV, trọng tài... lấy từ CSDL.

export interface ClubMeta {
  code: string;
  name: string;
  short: string;
  stadiumCode: string;
  bgGradient: string;
  borderColor: string;
  textColor: string;
  accentColor: string;
}

export const CLUBS_INFO: Record<string, ClubMeta> = {
  HNFC: {
    code: "HNFC",
    name: "Hà Nội FC",
    short: "HN",
    stadiumCode: "SAN_HD",
    bgGradient: "linear-gradient(135deg, #4c1d95 0%, #2e1065 100%)",
    borderColor: "#a855f7",
    textColor: "#f3e8ff",
    accentColor: "#a855f7",
  },
  CAHN: {
    code: "CAHN",
    name: "Công An Hà Nội",
    short: "CA",
    stadiumCode: "SAN_HD",
    bgGradient: "linear-gradient(135deg, #991b1b 0%, #450a0a 100%)",
    borderColor: "#ef4444",
    textColor: "#fee2e2",
    accentColor: "#ef4444",
  },
  VTT: {
    code: "VTT",
    name: "Thể Công Viettel",
    short: "VT",
    stadiumCode: "SAN_MD",
    bgGradient: "linear-gradient(135deg, #881337 0%, #4c0519 100%)",
    borderColor: "#f43f5e",
    textColor: "#ffe4e6",
    accentColor: "#f43f5e",
  },
  HPFC: {
    code: "HPFC",
    name: "Hải Phòng FC",
    short: "HP",
    stadiumCode: "SAN_LT",
    bgGradient: "linear-gradient(135deg, #c2410c 0%, #7c2d12 100%)",
    borderColor: "#f97316",
    textColor: "#ffedd5",
    accentColor: "#f97316",
  },
  NDFC: {
    code: "NDFC",
    name: "Thép Xanh Nam Định",
    short: "NĐ",
    stadiumCode: "SAN_TT",
    bgGradient: "linear-gradient(135deg, #854d0e 0%, #422006 100%)",
    borderColor: "#eab308",
    textColor: "#fef08a",
    accentColor: "#eab308",
  },
  HAGL: {
    code: "HAGL",
    name: "Hoàng Anh Gia Lai",
    short: "GL",
    stadiumCode: "SAN_PK",
    bgGradient: "linear-gradient(135deg, #065f46 0%, #022c22 100%)",
    borderColor: "#10b981",
    textColor: "#d1fae5",
    accentColor: "#10b981",
  },
};

export function getClubMeta(code: string): ClubMeta {
  const upper = (code || "").toUpperCase().trim();
  if (CLUBS_INFO[upper]) return CLUBS_INFO[upper];
  return {
    code: upper || "FC",
    name: upper || "CLB",
    short: (upper || "FC").slice(0, 2),
    stadiumCode: "SAN_VLEAGUE",
    bgGradient: "linear-gradient(135deg, #1e293b 0%, #0f172a 100%)",
    borderColor: "#475569",
    textColor: "#cbd5e1",
    accentColor: "#64748b",
  };
}

export function TeamBadge({
  code,
  size = 36,
  showName = false,
}: {
  code: string;
  size?: number;
  showName?: boolean;
}) {
  const club = getClubMeta(code);

  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "0.5rem",
        verticalAlign: "middle",
      }}
      title={`${club.name} (${club.code})`}
    >
      <span
        style={{
          width: size,
          height: size,
          minWidth: size,
          borderRadius: Math.round(size * 0.32),
          background: club.bgGradient,
          border: `1.5px solid ${club.borderColor}`,
          color: club.textColor,
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "var(--font-display, Outfit, sans-serif)",
          fontWeight: 800,
          fontSize: Math.max(10, Math.round(size * 0.36)),
          letterSpacing: "-0.02em",
          boxShadow: `0 4px 14px -2px ${club.borderColor}40, inset 0 1px 0 rgba(255,255,255,0.2)`,
          flexShrink: 0,
        }}
      >
        {club.short}
      </span>
      {showName && (
        <span style={{ fontWeight: 700, fontSize: "0.92rem", color: "#f8fafc" }}>
          {club.name}
        </span>
      )}
    </div>
  );
}
