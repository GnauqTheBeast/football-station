// src/app/page.tsx - Dashboard V-League Pro (Score90X Style)
import Link from "next/link";
import { querySafe, getRole, getStationId } from "@/lib/db";
import { getStationInfo, getStationsHealth, STATIONS } from "@/lib/station";
import { TeamBadge, getClubMeta } from "@/components/TeamBadge";
import type { GlobalMatch, GlobalEvent, StandingRow, TopScorerRow } from "@/lib/types";

export const dynamic = "force-dynamic";

const MATCH_COLS = `matran, mavong, madoinha, madoikhach, masan, ngaygio,
  giave::text, sokhach, banthangnha, banthangkhach,
  thevangnha, thevangkhach, thedonha, thedokhach, trangthai`;

const SAN_NAMES: Record<string, string> = {
  SAN_HD: "SVĐ Hàng Đẫy",
  SAN_MD: "SVĐ QG Mỹ Đình",
  SAN_LT: "SVĐ Lạch Tray",
  SAN_TT: "SVĐ Thiên Trường",
  SAN_PK: "SVĐ Pleiku",
};

export default async function DashboardPage({
  searchParams,
}: {
  searchParams?: { tab?: string; q?: string };
}) {
  const role = getRole();
  if (role === "station") return <StationDashboard />;

  const tab = searchParams?.tab === "done" || searchParams?.tab === "todo" ? searchParams.tab : "all";
  const searchQ = (searchParams?.q ?? "").trim().toLowerCase();

  const [kpis, health, matches, standings, scorers] = await Promise.all([
    querySafe<{ tran: string; khach: string; tien: string }>(
      `SELECT COUNT(*)::text AS tran,
              COALESCE(SUM(sokhach),0)::text AS khach,
              COALESCE(SUM(sokhach * giave),0)::text AS tien
       FROM vw_global_tran_dau`
    ),
    getStationsHealth(),
    querySafe<GlobalMatch>(`SELECT ${MATCH_COLS} FROM vw_global_tran_dau ORDER BY ngaygio DESC`),
    querySafe<StandingRow>(`SELECT * FROM vw_bang_xep_hang ORDER BY vitri LIMIT 5`),
    querySafe<TopScorerRow>(`SELECT * FROM fn_top10_vua_pha_luoi() LIMIT 5`),
  ]);

  const allMatches = matches ?? [];
  const filteredMatches = allMatches.filter((m) => {
    if (!searchQ) return true;
    return (
      m.madoinha.toLowerCase().includes(searchQ) ||
      m.madoikhach.toLowerCase().includes(searchQ) ||
      m.matran.toLowerCase().includes(searchQ)
    );
  });

  const doneMatches = filteredMatches.filter((m) => m.trangthai === "DaKetThuc");
  const todoMatches = filteredMatches.filter((m) => m.trangthai !== "DaKetThuc");
  const heroMatch = doneMatches[0] ?? filteredMatches[0];

  let heroEvents: GlobalEvent[] = [];
  if (heroMatch) {
    const ev = await querySafe<GlobalEvent>(
      `SELECT sk.masukien, sk.matran, sk.macauthu, sk.loaisukien, sk.phutghinhan, ct.hoten
       FROM vw_global_su_kien_tran_dau sk
       LEFT JOIN cau_thu ct ON ct.macauthu = sk.macauthu
       WHERE sk.matran = $1 ORDER BY sk.phutghinhan ASC`,
      [heroMatch.matran]
    );
    if (ev) heroEvents = ev;
  }

  const displayedMatches = tab === "done" ? doneMatches : tab === "todo" ? todoMatches : filteredMatches;
  const k = kpis?.[0];
  const onlineCount = health?.filter((h) => h.imported).length ?? 0;
  const totalSpectators = k ? Number(k.khach) : 0;
  const totalRevenue = k ? Number(k.tien) : 0;

  const heroHomeClub = heroMatch ? getClubMeta(heroMatch.madoinha) : null;
  const heroAwayClub = heroMatch ? getClubMeta(heroMatch.madoikhach) : null;

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Hệ thống V-League 1</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Tổng quan giải đấu</span>
          </div>
          <h1>Trung Tâm Điều Hành V-League Pro</h1>
          <div className="sub">
            VFF Master Hub • CSDL phân tán hợp nhất {onlineCount}/{STATIONS.length} trạm qua postgres_fdw
          </div>
        </div>

        {/* Global Search Bar */}
        <form className="table-search" method="GET" action="/">
          <div className="search-wrap">
            <span className="material-symbols-outlined search-icon">search</span>
            <input
              name="q"
              defaultValue={searchParams?.q ?? ""}
              placeholder="Tìm CLB, mã trận (TR01)..."
              className="search-input"
            />
            {tab !== "all" && <input type="hidden" name="tab" value={tab} />}
          </div>
        </form>
      </div>

      {/* 4 Primary KPI Broadcast Cards */}
      <div className="kpis">
        <div className="kpi">
          <div className="kpi-icon-wrap blue">
            <span className="material-symbols-outlined">sports_soccer</span>
          </div>
          <div className="label">Tổng số trận đấu</div>
          <div className="value">{k ? Number(k.tran) : "-"}</div>
          <div className="kpi-sub">
            {doneMatches.length} đã kết thúc • {todoMatches.length} sắp đá
          </div>
        </div>

        <div className="kpi">
          <div className="kpi-icon-wrap cyan">
            <span className="material-symbols-outlined">groups</span>
          </div>
          <div className="label">Tổng khán giả tới sân</div>
          <div className="value">{totalSpectators.toLocaleString("vi-VN")}</div>
          <div className="kpi-sub">
            {k && Number(k.tran) > 0
              ? `Trung bình ~${Math.round(totalSpectators / Number(k.tran)).toLocaleString("vi-VN")} CĐV/trận`
              : "Chưa có trận đấu"}
          </div>
        </div>

        <div className="kpi">
          <div className="kpi-icon-wrap emerald">
            <span className="material-symbols-outlined">payments</span>
          </div>
          <div className="label">Doanh thu bán vé</div>
          <div className="value emerald">
            {(totalRevenue / 1000000000).toFixed(2)} tỷ ₫
          </div>
          <div className="kpi-sub">{totalRevenue.toLocaleString("vi-VN")} ₫ toàn giải</div>
        </div>

        <div className="kpi">
          <div className="kpi-icon-wrap purple">
            <span className="material-symbols-outlined">hub</span>
          </div>
          <div className="label">Mạng FDW ZeroTier</div>
          <div className="value purple">
            {health ? `${onlineCount}/${STATIONS.length}` : "-"}
          </div>
          <div className="kpi-sub">
            {onlineCount === STATIONS.length ? "Toàn bộ trạm đã liên kết" : "Đang kiểm tra kết nối trạm"}
          </div>
        </div>
      </div>

      {/* HERO MATCH BROADCAST BANNER (SCORE90X CLASH) */}
      {heroMatch && heroHomeClub && heroAwayClub && (
        <div className="dashboard-hero-clash">
          <div className="clash-bg-glow-left" style={{ background: heroHomeClub.bgGradient }} />
          <div className="clash-bg-glow-right" style={{ background: heroAwayClub.bgGradient }} />

          <div className="clash-inner">
            {/* Top metadata */}
            <div className="clash-top-row">
              <div className="clash-tag-wrap">
                <span className="clash-status-pill">
                  <span className="live-dot" />
                  {heroMatch.trangthai === "DaKetThuc" ? "TRẬN ĐẤU TIÊU ĐIỂM" : "TRẬN ĐẤU SẮP DIỄN RA"}
                </span>
                <span className="clash-round-text">
                  V-League 1 • Vòng {heroMatch.mavong} • #{heroMatch.matran}
                </span>
              </div>
              <div className="clash-venue-text">
                <span className="material-symbols-outlined">stadium</span>
                {SAN_NAMES[heroMatch.masan] ?? heroMatch.masan}
                {heroMatch.sokhach && ` • ${heroMatch.sokhach.toLocaleString("vi-VN")} CĐV`}
              </div>
            </div>

            {/* Scoreboard Clash */}
            <div className="clash-scoreboard">
              {/* Home */}
              <div className="clash-team home">
                <div className="team-text-block">
                  <h2 className="team-name">{heroHomeClub.name}</h2>
                  <span className="team-sub" style={{ color: heroHomeClub.accentColor }}>
                    Đội chủ nhà
                  </span>
                </div>
                <TeamBadge code={heroMatch.madoinha} size={58} />
              </div>

              {/* Center score */}
              <div className="clash-center-score">
                <span className="score-half-label">
                  {heroMatch.trangthai === "DaKetThuc" ? "KẾT THÚC" : "VS"}
                </span>
                <div className="clash-score-numbers">
                  <span>{heroMatch.banthangnha}</span>
                  <span className="colon">:</span>
                  <span>{heroMatch.banthangkhach}</span>
                </div>
                <div className="clash-time-badge font-mono">
                  {heroMatch.trangthai === "DaKetThuc" ? "FT 90'" : "Sắp đá"}
                </div>
              </div>

              {/* Away */}
              <div className="clash-team away">
                <TeamBadge code={heroMatch.madoikhach} size={58} />
                <div className="team-text-block text-left">
                  <h2 className="team-name">{heroAwayClub.name}</h2>
                  <span className="team-sub" style={{ color: heroAwayClub.accentColor }}>
                    Đội khách
                  </span>
                </div>
              </div>
            </div>

            {/* Bottom Scorer preview + CTA */}
            <div className="clash-bottom-bar">
              <div className="clash-scorers-preview">
                {heroEvents.length > 0 ? (
                  <div className="event-pills-row">
                    {heroEvents.slice(0, 4).map((e) => (
                      <span key={e.masukien} className="mini-event-pill">
                        {e.phutghinhan}&prime; {e.hoten ?? e.macauthu} {e.loaisukien === "BanThang" ? "⚽" : "🟨"}
                      </span>
                    ))}
                  </div>
                ) : (
                  <span className="text-muted text-xs">
                    {new Date(heroMatch.ngaygio).toLocaleString("vi-VN")}
                  </span>
                )}
              </div>

              <div className="clash-cta-row">
                <Link href={`/fixtures/${heroMatch.matran}`} className="btn-hero-match">
                  <span className="material-symbols-outlined">assignment</span>
                  Chi Tiết Biên Bản &rarr;
                </Link>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MATCH TICKER LIST & TABS */}
      <div className="card match-list-card">
        <div className="card-header-row">
          <div>
            <h3>Trận Đấu Toàn Giải (Lịch &amp; Kết Quả)</h3>
            <p className="card-sub">Tổng hợp thời gian thực từ 5 trạm ngoại lai qua FDW</p>
          </div>
          <Link href="/fixtures" className="header-link">
            Xem lịch 10 vòng &rarr;
          </Link>
        </div>

        {/* Tab switcher */}
        <div className="tabs">
          <Link
            className={`tab ${tab === "all" ? "active" : ""}`}
            href={`/${searchQ ? `?q=${encodeURIComponent(searchQ)}` : ""}`}
          >
            Tất cả trận ({filteredMatches.length})
          </Link>
          <Link
            className={`tab ${tab === "done" ? "active" : ""}`}
            href={`/?tab=done${searchQ ? `&q=${encodeURIComponent(searchQ)}` : ""}`}
          >
            Đã kết thúc ({doneMatches.length})
          </Link>
          <Link
            className={`tab ${tab === "todo" ? "active" : ""}`}
            href={`/?tab=todo${searchQ ? `&q=${encodeURIComponent(searchQ)}` : ""}`}
          >
            Sắp diễn ra ({todoMatches.length})
          </Link>
        </div>

        {/* Matches list */}
        {displayedMatches.length === 0 ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">sports_score</span>
            <p>
              {searchQ
                ? `Không tìm thấy trận đấu nào khớp với từ khóa "${searchQ}".`
                : "Chưa có trận đấu nào trong danh mục này."}
            </p>
          </div>
        ) : (
          <div className="match-rows-list">
            {displayedMatches.slice(0, 8).map((m) => {
              const finished = m.trangthai === "DaKetThuc";
              const rev =
                m.giave != null && m.sokhach != null ? Number(m.giave) * m.sokhach : null;
              return (
                <Link key={m.matran} className="mrow-card" href={`/fixtures/${m.matran}`}>
                  <div className="mrow-left">
                    <span className="mrow-id font-mono">#{m.matran}</span>
                    <span className="mrow-round">Vòng {m.mavong}</span>
                  </div>

                  <div className="mrow-versus">
                    <div className="side-team home">
                      <span className="name">{m.madoinha}</span>
                      <TeamBadge code={m.madoinha} size={28} />
                    </div>

                    <div className="score-pill-box">
                      {finished ? (
                        <span className="score-text">
                          {m.banthangnha} - {m.banthangkhach}
                        </span>
                      ) : (
                        <span className="vs-tag">VS</span>
                      )}
                    </div>

                    <div className="side-team away">
                      <TeamBadge code={m.madoikhach} size={28} />
                      <span className="name">{m.madoikhach}</span>
                    </div>
                  </div>

                  <div className="mrow-right">
                    {rev != null ? (
                      <span className="rev-pill font-mono">{rev.toLocaleString("vi-VN")} ₫</span>
                    ) : (
                      <span className="stadium-pill">{SAN_NAMES[m.masan] ?? m.masan}</span>
                    )}
                    <span className={`status-dot-tag ${finished ? "done" : "todo"}`}>
                      {finished ? "ĐÃ ĐÁ" : "CHƯA"}
                    </span>
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </div>

      {/* LOWER 3-SECTION GRID: STANDINGS, TOP SCORERS & FDW STATION HEALTH */}
      <div className="dashboard-bottom-grid">
        {/* MINI STANDINGS */}
        <div className="card">
          <div className="card-header-row">
            <div>
              <h3>Bảng Xếp Hạng Top 5</h3>
              <p className="card-sub">Điểm số → Hiệu số → Bàn thắng</p>
            </div>
            <Link href="/standings" className="header-link">
              Đầy đủ &rarr;
            </Link>
          </div>

          {!standings || standings.length === 0 ? (
            <p className="empty-state">Chưa có dữ liệu bảng xếp hạng.</p>
          ) : (
            <div className="table-responsive">
              <table className="mini-standings-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>CLB</th>
                    <th className="number">TRẬN</th>
                    <th className="number">HS</th>
                    <th className="number">ĐIỂM</th>
                  </tr>
                </thead>
                <tbody>
                  {standings.map((s) => (
                    <tr key={s.madoi} className={s.vitri === 1 ? "rank-leader" : ""}>
                      <td>
                        <span className={`rank-badge ${s.vitri <= 3 ? `top-${s.vitri}` : ""}`}>
                          {s.vitri}
                        </span>
                      </td>
                      <td>
                        <div className="table-team-cell">
                          <TeamBadge code={s.madoi} size={24} />
                          <strong>{s.madoi}</strong>
                        </div>
                      </td>
                      <td className="number">{s.sotrandadau}</td>
                      <td className="number font-mono">
                        {s.hieuso >= 0 ? `+${s.hieuso}` : s.hieuso}
                      </td>
                      <td className="number font-mono bold emerald">{s.diemso}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* TOP SCORERS */}
        <div className="card">
          <div className="card-header-row">
            <div>
              <h3>Vua Phá Lưới Top 5</h3>
              <p className="card-sub">Gộp sự kiện 5 trạm qua FDW</p>
            </div>
            <Link href="/scorers" className="header-link">
              Top 10 &rarr;
            </Link>
          </div>

          {!scorers || scorers.length === 0 ? (
            <p className="empty-state">Chưa có cầu thủ ghi bàn.</p>
          ) : (
            <div className="scorers-mini-list">
              {scorers.map((s) => {
                const maxGoals = Number(scorers[0].sobanthang) || 1;
                const pct = Math.round((Number(s.sobanthang) / maxGoals) * 100);
                return (
                  <div key={s.macauthu} className="scorer-item">
                    <span className={`rank-badge ${s.xephang <= 3 ? `top-${s.xephang}` : ""}`}>
                      {s.xephang}
                    </span>
                    <div className="scorer-info">
                      <div className="scorer-name-row">
                        <strong>{s.hoten}</strong>
                        <span className="goal-number-badge font-mono">
                          {s.sobanthang} bàn ⚽
                        </span>
                      </div>
                      <div className="scorer-progress-track">
                        <div className="scorer-progress-fill" style={{ width: `${pct}%` }} />
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* FDW ZERO TIER NODES */}
        <div className="card">
          <div className="card-header-row">
            <div>
              <h3>Mạng Lưới FDW {STATIONS.length} Trạm</h3>
              <p className="card-sub">ZeroTier VPN Mesh • Đề tài 13</p>
            </div>
          </div>

          <div className="station-mesh-list">
            {!health ? (
              <p className="empty-state">Chưa cấu hình foreign tables.</p>
            ) : (
              health.map((h) => (
                <div key={h.id} className="mesh-station-item">
                  <div className="mesh-station-left">
                    <span className={`mesh-status-dot ${h.imported ? "online" : "offline"}`} />
                    <TeamBadge code={h.club} size={22} />
                    <div>
                      <div className="mesh-station-name">
                        Trạm S{h.id} • {h.club}
                      </div>
                      <div className="mesh-station-sub">{h.san}</div>
                    </div>
                  </div>
                  <div className="mesh-station-count">
                    {h.imported ? (
                      <span className="badge-online font-mono">{h.tranCount} trận</span>
                    ) : (
                      <span className="badge-offline">offline</span>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// Station Dashboard for Node role = station
async function StationDashboard() {
  const id = getStationId();
  const info = await getStationInfo();
  const matches = await querySafe<GlobalMatch>(
    `SELECT matran, mavong, madoinha, madoikhach, masan, ngaygio,
            NULL::text AS giave, NULL::int AS sokhach,
            banthangnha, banthangkhach, thevangnha, thevangkhach,
            thedonha, thedokhach, trangthai
     FROM tran_dau_chuyen_mon ORDER BY ngaygio`
  );

  const doneCount = matches?.filter((m) => m.trangthai === "DaKetThuc").length ?? 0;
  const todoCount = (matches?.length ?? 0) - doneCount;

  return (
    <div className="page-container">
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Trạm Cục Bộ</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Trạm {id} ({info.club})</span>
          </div>
          <h1>{info.station_name}</h1>
          <div className="sub">
            Quản lý {matches?.length ?? 0} trận sân nhà - dữ liệu local, Master kéo qua FDW
          </div>
        </div>
        <div className="topbar-actions">
          <Link className="btn" href="/admin/new-match-result">
            <span className="material-symbols-outlined">add_task</span>
            Nhập kết quả &amp; Chốt trận
          </Link>
        </div>
      </div>

      <div className="kpis">
        <div className="kpi">
          <div className="label">Trận sân nhà</div>
          <div className="value">{matches?.length ?? 0}</div>
        </div>
        <div className="kpi">
          <div className="label">Đã hoàn thành</div>
          <div className="value emerald">{doneCount}</div>
        </div>
        <div className="kpi">
          <div className="label">Chờ nhập tỉ số</div>
          <div className="value amber">{todoCount}</div>
        </div>
      </div>

      <div className="card">
        <h3>Danh Sách Trận Sân Nhà Của Trạm</h3>
        {!matches || matches.length === 0 ? (
          <p className="empty-state">Chưa có trận nào được ghi nhận tại trạm này.</p>
        ) : (
          <div className="table-responsive">
            <table className="roster-table">
              <thead>
                <tr>
                  <th>MÃ TRẬN</th>
                  <th>CẶP ĐẤU</th>
                  <th>TỈ SỐ</th>
                  <th>THỜI GIAN</th>
                  <th className="number">TRẠNG THÁI</th>
                </tr>
              </thead>
              <tbody>
                {matches.map((m) => (
                  <tr key={m.matran}>
                    <td>
                      <Link href={`/fixtures/${m.matran}`} className="font-mono bold">
                        #{m.matran}
                      </Link>
                    </td>
                    <td>
                      <div className="table-team-cell">
                        <TeamBadge code={m.madoinha} size={24} />
                        <strong>{m.madoinha}</strong> vs <strong>{m.madoikhach}</strong>
                        <TeamBadge code={m.madoikhach} size={24} />
                      </div>
                    </td>
                    <td>
                      <span className="score-pill">
                        {m.banthangnha} - {m.banthangkhach}
                      </span>
                    </td>
                    <td className="text-muted">
                      {new Date(m.ngaygio).toLocaleString("vi-VN")}
                    </td>
                    <td className="number">
                      <span
                        className={`status-pill ${
                          m.trangthai === "DaKetThuc" ? "done" : "live"
                        }`}
                      >
                        {m.trangthai === "DaKetThuc" ? "Đã chốt" : "Chờ nhập"}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
