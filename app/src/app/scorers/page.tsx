// src/app/scorers/page.tsx - Vua phá lưới Top 10 (fn_top10_vua_pha_luoi)
// Lưu ý nghiệp vụ: CAU_THU trên Master không lưu CLB chủ quản (mapping nằm ở
// HOP_DONG_CAU_THU, bảng này chưa triển khai ở Master) nên trang này chỉ hiện
// tên + mã cầu thủ + số bàn, không gán CLB bừa.
import { querySafe, getRole } from "@/lib/db";
import type { TopScorerRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function ScorersPage() {
  const role = getRole();
  const rows =
    role === "master"
      ? await querySafe<TopScorerRow>(`SELECT * FROM fn_top10_vua_pha_luoi()`)
      : null;

  const top1 = rows && rows.length > 0 ? rows[0] : null;
  const maxGoals = top1 ? Number(top1.sobanthang) || 1 : 1;

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Hệ thống V-League 1</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Vua phá lưới</span>
          </div>
          <h1>Bảng Xếp Hạng Vua Phá Lưới</h1>
          <div className="sub">
            Top 10 chân sút xuất sắc nhất mùa giải • Hợp nhất sự kiện ghi bàn từ các trạm FDW
          </div>
        </div>
      </div>

      {/* Golden Boot Leader Spotlight Hero */}
      {top1 && (
        <div className="golden-boot-hero">
          <div className="boot-content">
            <div className="boot-badge-wrap">
              <span className="boot-trophy-icon">🥇</span>
              <span className="boot-title-tag">DẪN ĐẦU DANH HIỆU CHIẾC GIÀY VÀNG</span>
            </div>

            <div className="boot-player-row">
              <div className="boot-player-info">
                <h2 className="boot-player-name">{top1.hoten}</h2>
                <div className="boot-player-meta">
                  <span className="font-mono">#{top1.macauthu}</span>
                </div>
              </div>

              <div className="boot-goals-box">
                <span className="boot-goals-num">{top1.sobanthang}</span>
                <span className="boot-goals-label">BÀN THẮNG ⚽</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Top 10 Scorers List Card */}
      <div className="card">
        <div className="card-header-row">
          <div>
            <h3>Top 10 Cầu Thủ Ghi Bàn Nhiều Nhất</h3>
            <p className="card-sub">
              Dữ liệu tổng hợp từ các sự kiện BanThang ghi nhận tại biên bản các trạm
            </p>
          </div>
        </div>

        {role !== "master" ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">lock</span>
            <p>Thống kê Vua phá lưới toàn giải chỉ có trên ứng dụng Master.</p>
          </div>
        ) : !rows ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">wifi_off</span>
            <p>Không đọc được dữ liệu Vua phá lưới - kiểm tra trạm hoặc chạy `make setup-fdw`.</p>
          </div>
        ) : rows.length === 0 ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">sports_soccer</span>
            <p>Chưa có bàn thắng nào được ghi nhận trong giải đấu.</p>
          </div>
        ) : (
          <div className="scorers-full-list">
            {rows.map((s) => {
              const goals = Number(s.sobanthang);
              const pct = Math.round((goals / maxGoals) * 100);
              const isTop3 = s.xephang <= 3;

              return (
                <div key={s.macauthu} className={`scorer-full-row ${isTop3 ? `rank-${s.xephang}` : ""}`}>
                  <div className="scorer-rank-cell">
                    <span className={`rank-badge ${isTop3 ? `top-${s.xephang}` : "muted"}`}>
                      {s.xephang === 1 ? "🥇 1" : s.xephang === 2 ? "🥈 2" : s.xephang === 3 ? "🥉 3" : s.xephang}
                    </span>
                  </div>

                  <div className="scorer-player-cell">
                    <div>
                      <div className="player-title">{s.hoten}</div>
                      <div className="player-meta-line">
                        <span className="font-mono text-muted">#{s.macauthu}</span>
                      </div>
                    </div>
                  </div>

                  <div className="scorer-bar-cell">
                    <div className="scorer-metric-track">
                      <div className="scorer-metric-fill" style={{ width: `${pct}%` }} />
                    </div>
                  </div>

                  <div className="scorer-goals-cell">
                    <span className="goal-pill font-mono bold">
                      {goals} bàn ⚽
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
