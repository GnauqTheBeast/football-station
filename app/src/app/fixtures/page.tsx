// src/app/fixtures/page.tsx - Lịch thi đấu & Match Hub Pro (10 vòng, 30 trận)
import Link from "next/link";
import { querySafe, getRole } from "@/lib/db";
import { TeamBadge, CLUBS_INFO } from "@/components/TeamBadge";
import type { GlobalMatch } from "@/lib/types";

export const dynamic = "force-dynamic";

const MASTER_SQL = `SELECT matran, mavong, madoinha, madoikhach, masan, ngaygio,
  giave::text, sokhach, banthangnha, banthangkhach,
  thevangnha, thevangkhach, thedonha, thedokhach, trangthai
  FROM vw_global_tran_dau ORDER BY mavong, ngaygio ASC, matran`;

const STATION_SQL = `SELECT matran, mavong, madoinha, madoikhach, masan, ngaygio,
  NULL::text AS giave, NULL::int AS sokhach,
  banthangnha, banthangkhach, thevangnha, thevangkhach,
  thedonha, thedokhach, trangthai
  FROM tran_dau_chuyen_mon ORDER BY mavong, ngaygio ASC, matran`;

const SAN_NAMES: Record<string, string> = {
  SAN_HD: "SVĐ Hàng Đẫy (Hà Nội)",
  SAN_MD: "SVĐ Quốc Gia Mỹ Đình (Hà Nội)",
  SAN_LT: "SVĐ Lạch Tray (Hải Phòng)",
  SAN_TT: "SVĐ Thiên Trường (Nam Định)",
  SAN_PK: "SVĐ Pleiku (Gia Lai)",
};

export default async function FixturesPage({
  searchParams,
}: {
  searchParams?: { round?: string; status?: string; club?: string; q?: string };
}) {
  const role = getRole();
  const selectedRound = searchParams?.round ? Number(searchParams.round) : null;
  const selectedStatus = searchParams?.status ?? "all";
  const selectedClub = searchParams?.club ?? "all";
  const searchQ = (searchParams?.q ?? "").trim().toLowerCase();

  const allMatches = await querySafe<GlobalMatch>(role === "master" ? MASTER_SQL : STATION_SQL);

  // Filter matches
  const matches = (allMatches ?? []).filter((m) => {
    if (selectedRound && m.mavong !== selectedRound) return false;
    if (selectedStatus === "done" && m.trangthai !== "DaKetThuc") return false;
    if (selectedStatus === "todo" && m.trangthai === "DaKetThuc") return false;
    if (selectedClub !== "all" && m.madoinha !== selectedClub && m.madoikhach !== selectedClub) return false;
    if (searchQ) {
      const matchHome = m.madoinha.toLowerCase().includes(searchQ);
      const matchAway = m.madoikhach.toLowerCase().includes(searchQ);
      const matchCode = m.matran.toLowerCase().includes(searchQ);
      if (!matchHome && !matchAway && !matchCode) return false;
    }
    return true;
  });

  const allRounds = allMatches ? [...new Set(allMatches.map((m) => m.mavong))].sort((a, b) => a - b) : [];
  const totalCount = allMatches?.length ?? 0;
  const doneCount = allMatches?.filter((m) => m.trangthai === "DaKetThuc").length ?? 0;
  const upcomingCount = totalCount - doneCount;

  const totalRev = (allMatches ?? []).reduce((sum, m) => {
    if (m.giave != null && m.sokhach != null) {
      return sum + Number(m.giave) * m.sokhach;
    }
    return sum;
  }, 0);

  // Trạm: đội nhà luôn là CLB của trạm, đối thủ = các đội khách từng đá ở đây.
  // Lọc CLB chỉ hiện các đối thủ thật, không hiện đủ 6 đội toàn giải.
  const opponentClubs =
    role === "master"
      ? Object.keys(CLUBS_INFO)
      : [...new Set((allMatches ?? []).map((m) => m.madoikhach))].sort();

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Hệ thống V-League 1</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Match Hub Pro</span>
          </div>
          <h1>{role === "master" ? "Lịch Thi Đấu & Điều Hành Cặp Đấu" : "Lịch Thi Đấu Trạm Sân Nhà"}</h1>
          <div className="sub">
            {role === "master"
              ? `Hợp nhất dữ liệu lịch thi đấu & kết quả 5 trạm qua ZeroTier FDW mesh`
              : "Dữ liệu các trận đấu diễn ra tại sân nhà do trạm quản lý"}
          </div>
        </div>

        {/* Quick Search */}
        <form className="table-search" method="GET" action="/fixtures">
          {selectedRound && <input type="hidden" name="round" value={selectedRound} />}
          {selectedStatus !== "all" && <input type="hidden" name="status" value={selectedStatus} />}
          {selectedClub !== "all" && <input type="hidden" name="club" value={selectedClub} />}
          <div className="search-wrap">
            <span className="material-symbols-outlined search-icon">search</span>
            <input
              name="q"
              defaultValue={searchParams?.q ?? ""}
              placeholder="Tìm CLB, mã trận (TR01)..."
              className="search-input"
            />
          </div>
        </form>
      </div>

      {/* Overview Hub Telemetry Cards */}
      <div className="kpis">
        <div className="kpi">
          <div className="label">Tổng số trận đấu</div>
          <div className="value">{totalCount}</div>
          <div className="kpi-sub">Toàn bộ giải đấu CSDL</div>
        </div>
        <div className="kpi">
          <div className="label">Đã hoàn thành</div>
          <div className="value emerald">{doneCount}</div>
          <div className="kpi-sub">
            {totalCount > 0 ? Math.round((doneCount / totalCount) * 100) : 0}% tiến độ mùa giải
          </div>
        </div>
        <div className="kpi">
          <div className="label">Chưa thi đấu</div>
          <div className="value amber">{upcomingCount}</div>
          <div className="kpi-sub">Trận chờ cập nhật tỉ số</div>
        </div>
        {role === "master" && (
          <div className="kpi">
            <div className="label">Doanh thu vé chốt</div>
            <div className="value purple">{(totalRev / 1000000000).toFixed(2)} tỷ ₫</div>
            <div className="kpi-sub">{totalRev.toLocaleString("vi-VN")} ₫ tổng thu</div>
          </div>
        )}
      </div>

      {/* Filter Bar: Status, Club & Round Pills */}
      <div className="fixtures-filters">
        {/* Status Filters */}
        <div className="filter-group">
          <span className="filter-group-label">Trạng thái:</span>
          <div className="pill-row">
            {[
              { id: "all", label: `Tất cả (${totalCount})` },
              { id: "done", label: `Đã kết thúc (${doneCount})` },
              { id: "todo", label: `Sắp diễn ra (${upcomingCount})` },
            ].map((item) => (
              <Link
                key={item.id}
                href={`/fixtures?status=${item.id}${selectedRound ? `&round=${selectedRound}` : ""}${selectedClub !== "all" ? `&club=${selectedClub}` : ""}`}
                className={`filter-pill ${selectedStatus === item.id ? "active" : ""}`}
              >
                {item.label}
              </Link>
            ))}
          </div>
        </div>

        {/* Club Filter — Master: 6 đội; Trạm: chỉ các đối thủ từng đá sân nhà */}
        <div className="filter-group">
          <span className="filter-group-label">
            {role === "master" ? "Câu lạc bộ:" : "Đối thủ:"}
          </span>
          <div className="pill-row">
            <Link
              href={`/fixtures?club=all${selectedRound ? `&round=${selectedRound}` : ""}${selectedStatus !== "all" ? `&status=${selectedStatus}` : ""}`}
              className={`filter-pill ${selectedClub === "all" ? "active" : ""}`}
            >
              {role === "master" ? "Tất cả đội" : "Tất cả trận"}
            </Link>
            {opponentClubs.map((code) => (
              <Link
                key={code}
                href={`/fixtures?club=${code}${selectedRound ? `&round=${selectedRound}` : ""}${selectedStatus !== "all" ? `&status=${selectedStatus}` : ""}`}
                className={`filter-pill ${selectedClub === code ? "active" : ""}`}
              >
                <TeamBadge code={code} size={18} />
                <span>{code}</span>
              </Link>
            ))}
          </div>
        </div>

        {/* Round Filter */}
        {allRounds.length > 0 && (
          <div className="filter-group">
            <span className="filter-group-label">Vòng đấu:</span>
            <div className="round-pills-row">
              <Link
                href={`/fixtures?round=${selectedStatus !== "all" ? `&status=${selectedStatus}` : ""}${selectedClub !== "all" ? `&club=${selectedClub}` : ""}`}
                className={`round-pill ${selectedRound === null ? "active" : ""}`}
              >
                Tất cả vòng
              </Link>
              {allRounds.map((v) => (
                <Link
                  key={v}
                  href={`/fixtures?round=${v}${selectedStatus !== "all" ? `&status=${selectedStatus}` : ""}${selectedClub !== "all" ? `&club=${selectedClub}` : ""}`}
                  className={`round-pill ${selectedRound === v ? "active" : ""}`}
                >
                  Vòng {v}
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Match Cards List */}
      {!allMatches ? (
        <div className="card empty-card">
          <span className="material-symbols-outlined empty-icon">wifi_off</span>
          <h3>Không thể kết nối cơ sở dữ liệu Master/Station</h3>
          <p>Kiểm tra container Postgres hoặc cấu hình mạng FDW qua ZeroTier.</p>
        </div>
      ) : matches.length === 0 ? (
        <div className="card empty-card">
          <span className="material-symbols-outlined empty-icon">event_busy</span>
          <h3>Không tìm thấy trận đấu nào</h3>
          <p>Vui lòng thử lại với các tiêu chí tìm kiếm hoặc bộ lọc khác.</p>
        </div>
      ) : (
        allRounds
          .filter((v) => selectedRound === null || selectedRound === v)
          .map((v) => {
            const roundMatches = matches.filter((m) => m.mavong === v);
            if (roundMatches.length === 0) return null;
            const roundDone = roundMatches.filter((m) => m.trangthai === "DaKetThuc").length;

            return (
              <div key={v} className="round-section">
                <div className="round-section-header">
                  <div className="round-title-wrap">
                    <span className="round-num-badge">VÒNG {v}</span>
                    <span className="round-meta">
                      {roundMatches.length} trận đấu • {roundDone} đã kết thúc
                    </span>
                  </div>
                  <div className="round-progress-wrap">
                    <div className="round-progress-bar">
                      <div
                        className="round-progress-fill"
                        style={{
                          width: `${(roundDone / roundMatches.length) * 100}%`,
                        }}
                      />
                    </div>
                    <span className="round-progress-pct">
                      {Math.round((roundDone / roundMatches.length) * 100)}%
                    </span>
                  </div>
                </div>

                <div className="match-cards-grid">
                  {roundMatches.map((m) => {
                    const finished = m.trangthai === "DaKetThuc";
                    const rev =
                      m.giave != null && m.sokhach != null ? Number(m.giave) * m.sokhach : null;
                    const dateFormatted = new Date(m.ngaygio).toLocaleDateString("vi-VN", {
                      weekday: "short",
                      day: "2-digit",
                      month: "2-digit",
                      hour: "2-digit",
                      minute: "2-digit",
                    });
                    const stadiumText = SAN_NAMES[m.masan] ?? `Sân ${m.masan}`;

                    return (
                      <Link
                        key={m.matran}
                        href={`/fixtures/${m.matran}`}
                        className={`fixture-match-card ${finished ? "finished" : "upcoming"}`}
                      >
                        {/* Top bar of card */}
                        <div className="card-top-bar">
                          <span className="match-id font-mono">#{m.matran}</span>
                          <span className="match-stadium">
                            <span className="material-symbols-outlined">stadium</span>
                            {stadiumText}
                          </span>
                          <span className={`status-pill ${finished ? "done" : "live"}`}>
                            {finished ? "ĐÃ KẾT THÚC" : "SẮP DIỄN RA"}
                          </span>
                        </div>

                        {/* Match center row */}
                        <div className="match-versus-row">
                          {/* Home team */}
                          <div className="team-side home">
                            <span className="team-name">{m.madoinha}</span>
                            <TeamBadge code={m.madoinha} size={42} />
                          </div>

                          {/* Score / Status Center */}
                          <div className="score-center-box">
                            {finished ? (
                              <div className="score-glow-pill">
                                <span>{m.banthangnha}</span>
                                <span className="score-divider">:</span>
                                <span>{m.banthangkhach}</span>
                              </div>
                            ) : (
                              <div className="vs-pill">VS</div>
                            )}
                            <div className="match-date-time">{dateFormatted}</div>
                          </div>

                          {/* Away team */}
                          <div className="team-side away">
                            <TeamBadge code={m.madoikhach} size={42} />
                            <span className="team-name">{m.madoikhach}</span>
                          </div>
                        </div>

                        {/* Bottom telemetry footer */}
                        <div className="card-footer-bar">
                          <div className="footer-stats">
                            {m.sokhach != null && (
                              <span className="spec-count">
                                <span className="material-symbols-outlined">groups</span>
                                {m.sokhach.toLocaleString("vi-VN")} CĐV
                              </span>
                            )}
                            {rev != null && (
                              <span className="rev-amount">
                                <span className="material-symbols-outlined">payments</span>
                                {rev.toLocaleString("vi-VN")} ₫
                              </span>
                            )}
                            {finished && (
                              <span className="card-discipline">
                                {m.thevangnha + m.thevangkhach} 🟨 · {m.thedonha + m.thedokhach} 🟥
                              </span>
                            )}
                          </div>
                          <span className="view-detail-btn">
                            Biên bản &rarr;
                          </span>
                        </div>
                      </Link>
                    );
                  })}
                </div>
              </div>
            );
          })
      )}
    </div>
  );
}
