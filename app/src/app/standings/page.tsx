// src/app/standings/page.tsx - Bảng xếp hạng V-League Pro
import { querySafe, getRole } from "@/lib/db";
import { TeamBadge, getClubMeta } from "@/components/TeamBadge";
import type { StandingRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function StandingsPage() {
  const role = getRole();
  const rows =
    role === "master"
      ? await querySafe<StandingRow>(`SELECT * FROM vw_bang_xep_hang ORDER BY vitri ASC`)
      : null;

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Hệ thống V-League 1</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Bảng xếp hạng</span>
          </div>
          <h1>Bảng Xếp Hạng V-League 1</h1>
          <div className="sub">
            Mùa giải 2025/2026 • Tổng hợp thời gian thực từ 5 trạm qua view phân tán postgres_fdw
          </div>
        </div>
      </div>

      {/* Main Standings Table Card */}
      <div className="card">
        <div className="card-header-row">
          <div>
            <h3>Bảng Tổng Sắp Thành Tích Các Đội</h3>
            <p className="card-sub">
              Xếp hạng tự động theo chuẩn V-League: Điểm &rarr; Hiệu số &rarr; Bàn thắng &rarr; Thắng sân khách &rarr; Kỷ luật thẻ
            </p>
          </div>
        </div>

        {role !== "master" ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">lock</span>
            <p>Bảng xếp hạng toàn giải chỉ có trên ứng dụng Master (tổng hợp FDW từ các trạm).</p>
          </div>
        ) : !rows ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">wifi_off</span>
            <p>Không đọc được dữ liệu bảng xếp hạng - kiểm tra kết nối trạm hoặc chạy `make setup-fdw`.</p>
          </div>
        ) : rows.length === 0 ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">sports</span>
            <p>Chưa có trận đấu nào kết thúc để tính điểm xếp hạng.</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="standings-table">
              <thead>
                <tr>
                  <th style={{ width: "50px" }}>#</th>
                  <th>CÂU LẠC BỘ</th>
                  <th className="number">TRẬN</th>
                  <th className="number">THẮNG</th>
                  <th className="number">HÒA</th>
                  <th className="number">THUA</th>
                  <th className="number">BT</th>
                  <th className="number">BB</th>
                  <th className="number">HIỆU SỐ</th>
                  <th className="number">BT KHÁCH</th>
                  <th className="number">THẺ ĐỎ</th>
                  <th className="number">THẺ VÀNG</th>
                  <th className="number highlight">ĐIỂM</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((s) => {
                  const club = getClubMeta(s.madoi);
                  const isTop1 = s.vitri === 1;
                  const isAfcZone = s.vitri <= 2;
                  const isRelegationZone = s.vitri === rows.length;

                  return (
                    <tr
                      key={s.madoi}
                      className={`standings-row ${
                        isTop1
                          ? "rank-champ"
                          : isAfcZone
                          ? "afc-zone"
                          : isRelegationZone
                          ? "relegation-zone"
                          : ""
                      }`}
                    >
                      <td>
                        <span
                          className={`rank-badge ${
                            s.vitri <= 3 ? `top-${s.vitri}` : "muted"
                          }`}
                        >
                          {s.vitri}
                        </span>
                      </td>
                      <td>
                        <div className="standings-team-cell">
                          <TeamBadge code={s.madoi} size={30} />
                          <div>
                            <div className="team-name">{club.name}</div>
                            <div className="team-code font-mono text-muted">{s.madoi}</div>
                          </div>
                          {isTop1 && <span className="trophy-icon">🏆</span>}
                        </div>
                      </td>
                      <td className="number font-mono">{s.sotrandadau}</td>
                      <td className="number font-mono emerald bold">{s.sotranthang}</td>
                      <td className="number font-mono text-muted">{s.sotranhoa}</td>
                      <td className="number font-mono rose bold">{s.sotranthua}</td>
                      <td className="number font-mono">{s.tongbanthang}</td>
                      <td className="number font-mono">{s.tongbanthua}</td>
                      <td className="number font-mono bold">
                        {s.hieuso > 0 ? `+${s.hieuso}` : s.hieuso}
                      </td>
                      <td className="number font-mono text-muted">{s.sotranthangsankhach}</td>
                      <td className="number font-mono">
                        {s.tongthedo > 0 ? (
                          <span className="card-badge red">{s.tongthedo}</span>
                        ) : (
                          "0"
                        )}
                      </td>
                      <td className="number font-mono">
                        {s.tongthevang > 0 ? (
                          <span className="card-badge yellow">{s.tongthevang}</span>
                        ) : (
                          "0"
                        )}
                      </td>
                      <td className="number highlight font-mono bold">
                        <span className="points-pill">{s.diemso}</span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* V-League Criteria Explainer Card */}
      <div className="card criteria-card">
        <div className="criteria-header">
          <span className="material-symbols-outlined text-accent">info</span>
          <h4>Quy Tắc Xếp Hạng V-League 1 (Điều Lệ Giải Đấu)</h4>
        </div>
        <div className="criteria-grid">
          <div className="criteria-item">
            <span className="criteria-num">1</span>
            <div>
              <strong>Tổng số điểm</strong>
              <p>Thắng: 3 điểm • Hòa: 1 điểm • Thua: 0 điểm</p>
            </div>
          </div>
          <div className="criteria-item">
            <span className="criteria-num">2</span>
            <div>
              <strong>Hiệu số bàn thắng</strong>
              <p>Tổng bàn thắng trừ tổng bàn thua</p>
            </div>
          </div>
          <div className="criteria-item">
            <span className="criteria-num">3</span>
            <div>
              <strong>Tổng số bàn thắng</strong>
              <p>Ưu tiên đội ghi nhiều bàn thắng hơn</p>
            </div>
          </div>
          <div className="criteria-item">
            <span className="criteria-num">4</span>
            <div>
              <strong>Thắng sân khách &amp; Thẻ phạt</strong>
              <p>Số trận thắng sân khách &rarr; Ít thẻ đỏ &rarr; Ít thẻ vàng</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
