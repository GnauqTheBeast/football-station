// src/app/clubs/page.tsx - Danh sách cầu thủ toàn giải (dữ liệu thật)
// Nguồn: CAU_THU (Master) LEFT JOIN vw_global_su_kien_tran_dau (FDW).
// Lưu ý nghiệp vụ: CAU_THU trên Master không có cột CLB chủ quản (mapping nằm ở
// HOP_DONG_CAU_THU, bảng này chưa triển khai ở Master) nên trang này KHÔNG gán
// CLB cho từng cầu thủ — chỉ lọc theo vị trí + tìm kiếm, thống kê bàn/thẻ thật.
import Link from "next/link";
import { querySafe, getRole } from "@/lib/db";

export const dynamic = "force-dynamic";

interface PlayerRow {
  macauthu: string;
  hoten: string;
  vitri: string;
  ban: string;
  vang: string;
  do_: string;
}

const POS_LABELS: Record<string, { label: string; code: string; color: string }> = {
  ThuMon: { label: "Thủ môn", code: "GK", color: "#f59e0b" },
  HauVe: { label: "Hậu vệ", code: "DF", color: "#3b82f6" },
  TienVe: { label: "Tiền vệ", code: "MF", color: "#10b981" },
  TienDao: { label: "Tiền đạo", code: "FW", color: "#ef4444" },
};

export default async function ClubsPage({
  searchParams,
}: {
  searchParams?: { pos?: string; q?: string };
}) {
  const role = getRole();
  const activePos = searchParams?.pos ?? "all";
  const searchQ = (searchParams?.q ?? "").trim().toLowerCase();

  const rows = await querySafe<PlayerRow>(
    `SELECT ct.macauthu, ct.hoten, ct.vitri,
            COUNT(CASE WHEN sk.loaisukien = 'BanThang' THEN 1 END)::text AS ban,
            COUNT(CASE WHEN sk.loaisukien = 'TheVang' THEN 1 END)::text AS vang,
            COUNT(CASE WHEN sk.loaisukien = 'TheDo' THEN 1 END)::text AS do_
     FROM cau_thu ct
     LEFT JOIN vw_global_su_kien_tran_dau sk ON sk.macauthu = ct.macauthu
     GROUP BY ct.macauthu, ct.hoten, ct.vitri
     ORDER BY COUNT(CASE WHEN sk.loaisukien = 'BanThang' THEN 1 END) DESC, ct.macauthu ASC`
  );

  const allPlayers = rows ?? [];

  const filteredPlayers = allPlayers.filter((p) => {
    if (activePos !== "all" && p.vitri !== activePos) return false;
    if (searchQ) {
      const matchName = p.hoten.toLowerCase().includes(searchQ);
      const matchCode = p.macauthu.toLowerCase().includes(searchQ);
      if (!matchName && !matchCode) return false;
    }
    return true;
  });

  const totalGoals = allPlayers.reduce((sum, p) => sum + Number(p.ban), 0);
  const totalYellow = allPlayers.reduce((sum, p) => sum + Number(p.vang), 0);
  const totalRed = allPlayers.reduce((sum, p) => sum + Number(p.do_), 0);

  return (
    <div className="page-container">
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Hệ thống V-League 1</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Danh sách cầu thủ</span>
          </div>
          <h1>Cầu Thủ Toàn Giải &amp; Thống Kê Sự Kiện</h1>
          <div className="sub">
            {role === "master"
              ? `Danh mục ${allPlayers.length} cầu thủ (CAU_THU) + sự kiện FDW từ các trạm`
              : "Dữ liệu danh mục cầu thủ trạm"}
          </div>
        </div>
        {role === "master" && (
          <div className="topbar-actions">
            <Link className="btn secondary" href="/admin/ref">
              <span className="material-symbols-outlined">person_add</span>
              Thêm Cầu Thủ Master
            </Link>
          </div>
        )}
      </div>

      {/* KPI thật từ CSDL */}
      <div className="kpis">
        <div className="kpi">
          <div className="kpi-icon-wrap blue">
            <span className="material-symbols-outlined">groups</span>
          </div>
          <div className="label">Tổng cầu thủ đăng ký</div>
          <div className="value">{allPlayers.length}</div>
          <div className="kpi-sub">Bảng CAU_THU tại Master</div>
        </div>
        <div className="kpi">
          <div className="kpi-icon-wrap emerald">
            <span className="material-symbols-outlined">sports_soccer</span>
          </div>
          <div className="label">Tổng bàn thắng</div>
          <div className="value emerald">{totalGoals} ⚽</div>
          <div className="kpi-sub">Sự kiện BanThang toàn giải</div>
        </div>
        <div className="kpi">
          <div className="kpi-icon-wrap amber">
            <span className="material-symbols-outlined">style</span>
          </div>
          <div className="label">Tổng thẻ phạt</div>
          <div className="value amber">
            {totalYellow} 🟨 · {totalRed} 🟥
          </div>
          <div className="kpi-sub">Kỷ luật FDW toàn giải</div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="filter-search-bar">
        <div className="position-pills">
          {[
            { id: "all", label: "Tất cả vị trí" },
            { id: "TienDao", label: "Tiền đạo (FW)" },
            { id: "TienVe", label: "Tiền vệ (MF)" },
            { id: "HauVe", label: "Hậu vệ (DF)" },
            { id: "ThuMon", label: "Thủ môn (GK)" },
          ].map((item) => {
            const isActive = activePos === item.id;
            return (
              <Link
                key={item.id}
                href={`/clubs?pos=${item.id}${searchQ ? `&q=${encodeURIComponent(searchQ)}` : ""}`}
                className={`pos-pill ${isActive ? "active" : ""}`}
              >
                {item.label}
              </Link>
            );
          })}
        </div>

        <form className="table-search" method="GET" action="/clubs">
          {activePos !== "all" && <input type="hidden" name="pos" value={activePos} />}
          <div className="search-wrap">
            <span className="material-symbols-outlined search-icon">search</span>
            <input
              name="q"
              defaultValue={searchParams?.q ?? ""}
              placeholder="Tìm theo tên hoặc mã CT..."
              className="search-input"
            />
          </div>
        </form>
      </div>

      {/* Player Roster Card */}
      <div className="card roster-card">
        <div className="card-header-row">
          <div>
            <h3>
              Danh Sách Cầu Thủ Đăng Ký
              <span className="count-pill">{filteredPlayers.length} cầu thủ</span>
            </h3>
            <p className="card-sub">
              Dữ liệu danh mục CAU_THU kết hợp sự kiện bàn thắng / thẻ phạt thời gian thực qua postgres_fdw.
              CLB chủ quản chưa có trong CSDL Master (chờ bảng HOP_DONG_CAU_THU).
            </p>
          </div>
        </div>

        {!rows ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">wifi_off</span>
            <p>Không đọc được danh mục cầu thủ - kiểm tra kết nối Master.</p>
          </div>
        ) : filteredPlayers.length === 0 ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">group_off</span>
            <p>Không tìm thấy cầu thủ nào phù hợp với bộ lọc hiện tại.</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="roster-table">
              <thead>
                <tr>
                  <th style={{ width: "80px" }}>MÃ</th>
                  <th>CẦU THỦ</th>
                  <th>VỊ TRÍ</th>
                  <th className="number">BÀN THẮNG ⚽</th>
                  <th className="number">THẺ VÀNG 🟨</th>
                  <th className="number">THẺ ĐỎ 🟥</th>
                </tr>
              </thead>
              <tbody>
                {filteredPlayers.map((p) => {
                  const pos = POS_LABELS[p.vitri] ?? { label: p.vitri, code: "PL", color: "#94a3b8" };
                  const goals = Number(p.ban);
                  const yellow = Number(p.vang);
                  const red = Number(p.do_);

                  return (
                    <tr key={p.macauthu} className="roster-row">
                      <td className="player-code font-mono">{p.macauthu}</td>
                      <td>
                        <div className="player-name-cell">
                          <span className="player-avatar">{p.hoten.charAt(0)}</span>
                          <div>
                            <div className="player-name">{p.hoten}</div>
                            <div className="player-sub">{pos.label}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="pos-badge" style={{ borderColor: `${pos.color}40`, color: pos.color }}>
                          {pos.code} • {pos.label}
                        </span>
                      </td>
                      <td className="number">
                        {goals > 0 ? (
                          <span className="goal-badge">{goals} ⚽</span>
                        ) : (
                          <span className="muted-dash">-</span>
                        )}
                      </td>
                      <td className="number">
                        {yellow > 0 ? (
                          <span className="card-badge yellow">{yellow} 🟨</span>
                        ) : (
                          <span className="muted-dash">-</span>
                        )}
                      </td>
                      <td className="number">
                        {red > 0 ? (
                          <span className="card-badge red">{red} 🟥</span>
                        ) : (
                          <span className="muted-dash">-</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
