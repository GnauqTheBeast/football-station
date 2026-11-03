// src/app/fixtures/[id]/page.tsx - Biên bản trận đấu (dữ liệu thật từ CSDL)
// Master: vw_global_* (FDW) + TRAN_DAU_DOANH_THU. Station: bảng local.
// Trọng tài / sân / HLV: query thẳng bảng danh mục, bảng nào chưa có dữ liệu
// thì hiện empty state trung thực thay vì số bịa.
import Link from "next/link";
import { querySafe, getRole } from "@/lib/db";
import { TeamBadge, getClubMeta } from "@/components/TeamBadge";
import type { GlobalMatch, GlobalEvent } from "@/lib/types";
import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

interface SanRow {
  masan: string;
  tensan: string;
  diachi: string;
  succhua: number;
}

interface DoiRow {
  madoi: string;
  tendoi: string;
  hlv: string;
  masannha: string;
}

interface RefRow {
  vaitro: string;
  matrongtai: string;
  hoten: string;
  capbac: string;
}

const VAITRO_LABELS: Record<string, string> = {
  Chinh: "Trọng tài chính",
  Bien1: "Trợ lý trọng tài 1 (biên)",
  Bien2: "Trợ lý trọng tài 2 (biên)",
  Ban: "Trọng tài bàn (thứ 4)",
};

export default async function FixtureDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const role = getRole();
  const id = decodeURIComponent(params.id);

  const matchSql =
    role === "master"
      ? `SELECT matran, mavong, madoinha, madoikhach, masan, ngaygio,
           giave::text, sokhach, banthangnha, banthangkhach,
           thevangnha, thevangkhach, thedonha, thedokhach, trangthai
         FROM vw_global_tran_dau WHERE matran = $1`
      : `SELECT matran, mavong, madoinha, madoikhach, masan, ngaygio,
           NULL::text AS giave, NULL::int AS sokhach,
           banthangnha, banthangkhach, thevangnha, thevangkhach,
           thedonha, thedokhach, trangthai
         FROM tran_dau_chuyen_mon WHERE matran = $1`;

  const eventSql =
    role === "master"
      ? `SELECT sk.masukien, sk.matran, sk.macauthu, sk.loaisukien, sk.phutghinhan, ct.hoten, ct.vitri
         FROM vw_global_su_kien_tran_dau sk
         LEFT JOIN cau_thu ct ON ct.macauthu = sk.macauthu
         WHERE sk.matran = $1 ORDER BY sk.phutghinhan ASC`
      : `SELECT masukien, matran, macauthu, loaisukien, phutghinhan, NULL::text AS hoten, NULL::text AS vitri
         FROM su_kien_tran_dau WHERE matran = $1 ORDER BY phutghinhan ASC`;

  const [mRows, events] = await Promise.all([
    querySafe<GlobalMatch>(matchSql, [id]),
    querySafe<GlobalEvent>(eventSql, [id]),
  ]);

  if (!mRows || mRows.length === 0) notFound();
  const m = mRows[0];
  const ev = events ?? [];

  // Sân / đội / trọng tài: query đúng theo mã của trận
  const [sanReal, doiReal, refReal] = await Promise.all([
    querySafe<SanRow>(`SELECT masan, tensan, diachi, succhua FROM san_van_dong WHERE masan = $1`, [m.masan]),
    querySafe<DoiRow>(`SELECT madoi, tendoi, hlv, masannha FROM doi_bong WHERE madoi IN ($1, $2)`, [m.madoinha, m.madoikhach]),
    querySafe<RefRow>(
      `SELECT pc.vaitro, pc.matrongtai, tt.hoten, tt.capbac
       FROM phan_cong_trong_tai pc JOIN trong_tai tt ON tt.matrongtai = pc.matrongtai
       WHERE pc.matran = $1 ORDER BY pc.vaitro`,
      [m.matran]
    ),
  ]);

  const homeClub = getClubMeta(m.madoinha);
  const awayClub = getClubMeta(m.madoikhach);
  const doiMap = new Map((doiReal ?? []).map((d) => [d.madoi, d]));
  const homeName = doiMap.get(m.madoinha)?.tendoi ?? homeClub.name;
  const awayName = doiMap.get(m.madoikhach)?.tendoi ?? awayClub.name;
  const homeHlv = doiMap.get(m.madoinha)?.hlv ?? null;
  const awayHlv = doiMap.get(m.madoikhach)?.hlv ?? null;

  const san = (sanReal ?? [])[0] ?? null;
  const stadiumName = san?.tensan ?? `Sân ${m.masan}`;
  const stadiumLoc = san?.diachi ?? null;
  const capacity = san?.succhua ?? null;

  const refs = refReal ?? [];

  const finished = m.trangthai === "DaKetThuc";
  const attendance: number | null = m.sokhach ?? null;
  const attendancePct =
    attendance != null && capacity ? Math.min(100, Math.round((attendance / capacity) * 100)) : null;
  const revenue = m.giave != null && m.sokhach != null ? Number(m.giave) * m.sokhach : null;

  // Cầu thủ ghi dấu ấn trong trận — gom từ sự kiện thật của trận này
  const playerStatsMap: Record<string, { hoten: string; vitri: string | null; goals: number; yellow: number; red: number }> = {};
  ev.forEach((e) => {
    if (!playerStatsMap[e.macauthu]) {
      playerStatsMap[e.macauthu] = { hoten: e.hoten ?? e.macauthu, vitri: e.vitri ?? null, goals: 0, yellow: 0, red: 0 };
    }
    if (e.loaisukien === "BanThang") playerStatsMap[e.macauthu].goals++;
    if (e.loaisukien === "TheVang") playerStatsMap[e.macauthu].yellow++;
    if (e.loaisukien === "TheDo") playerStatsMap[e.macauthu].red++;
  });
  const matchPlayers = Object.entries(playerStatsMap).sort(
    (a, b) => b[1].goals - a[1].goals || b[1].yellow - a[1].yellow
  );

  return (
    <div className="page-container">
      {/* Top Header & Breadcrumb */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <Link href="/">Hệ thống V-League 1</Link>
            <span className="material-symbols-outlined">chevron_right</span>
            <Link href="/fixtures">Vòng {m.mavong}</Link>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Biên bản trực tuyến #{m.matran}</span>
          </div>
          <h1>Biên Bản Trận Đấu &amp; Sự Kiện Trực Tuyến</h1>
          <div className="sub">
            V-League 1 • Vòng {m.mavong} • {stadiumName}
            {stadiumLoc ? ` (${stadiumLoc})` : ""}
          </div>
        </div>

        <div className="topbar-actions">
          <Link className="btn secondary" href="/fixtures">
            &larr; Lịch thi đấu
          </Link>
          {role === "station" && !finished && (
            <Link className="btn" href={`/admin/new-match-result?m=${m.matran}`}>
              <span className="material-symbols-outlined">edit_note</span>
              Nhập sự kiện / Chốt trận
            </Link>
          )}
        </div>
      </div>

      {/* PHẦN 1: SCOREBOARD */}
      <div className="match-detail-hero">
        <div className="hero-gradient-left" style={{ background: homeClub.bgGradient }} />
        <div className="hero-gradient-right" style={{ background: awayClub.bgGradient }} />

        <div className="hero-content-grid">
          <div className="hero-team-box home">
            <TeamBadge code={m.madoinha} size={68} />
            <div className="hero-team-info">
              <span className="hero-team-role-pill home">ĐỘI CHỦ NHÀ</span>
              <h2 className="hero-team-name">{homeName}</h2>
              <p className="hero-team-sub">
                {homeHlv ? `HLV: ${homeHlv}` : `Mã đội: ${m.madoinha}`}
              </p>
            </div>
            <div className="hero-score-digit home">{finished ? m.banthangnha : "-"}</div>
          </div>

          <div className="hero-center-hub">
            <div className="hero-round-badge">V-LEAGUE 1 • VÒNG {m.mavong}</div>

            <div className="hero-status-row">
              {finished ? (
                <span className="hero-status-badge finished">
                  <span className="material-symbols-outlined">verified</span>
                  ĐÃ KẾT THÚC
                </span>
              ) : (
                <span className="hero-status-badge live">
                  <span className="live-dot" />
                  CHƯA DIỄN RA
                </span>
              )}
            </div>

            <div className="hero-match-time">
              {new Date(m.ngaygio).toLocaleDateString("vi-VN", {
                weekday: "long",
                day: "2-digit",
                month: "2-digit",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit",
              })}
            </div>

            <div className="hero-telemetry-box">
              <div className="telemetry-item">
                <span className="telemetry-label">KHÁN GIẢ TỚI SÂN</span>
                <span className="telemetry-val">
                  {attendance != null ? (
                    <>
                      {attendance.toLocaleString("vi-VN")}{" "}
                      {capacity && <small>/ {capacity.toLocaleString("vi-VN")}</small>}
                    </>
                  ) : (
                    <small>Chưa cập nhật</small>
                  )}
                </span>
                {attendancePct != null && (
                  <div className="telemetry-progress-track">
                    <div className="telemetry-progress-fill" style={{ width: `${attendancePct}%` }} />
                  </div>
                )}
              </div>

              <div className="telemetry-item">
                <span className="telemetry-label">DOANH THU BÁN VÉ</span>
                <span className="telemetry-val emerald font-mono">
                  {revenue != null ? `${revenue.toLocaleString("vi-VN")} ₫` : "Chưa chốt"}
                </span>
                <span className="telemetry-sub">{stadiumName}</span>
              </div>
            </div>
          </div>

          <div className="hero-team-box away">
            <div className="hero-score-digit away">{finished ? m.banthangkhach : "-"}</div>
            <div className="hero-team-info right">
              <span className="hero-team-role-pill away">ĐỘI KHÁCH</span>
              <h2 className="hero-team-name">{awayName}</h2>
              <p className="hero-team-sub">
                {awayHlv ? `HLV: ${awayHlv}` : `Mã đội: ${m.madoikhach}`}
              </p>
            </div>
            <TeamBadge code={m.madoikhach} size={68} />
          </div>
        </div>
      </div>

      {/* PHẦN 2: TỔ TRỌNG TÀI — dữ liệu thật từ PHAN_CONG_TRONG_TAI */}
      <div className="card referee-card">
        <div className="referee-header-row">
          <div className="ref-title-wrap">
            <span className="material-symbols-outlined text-accent">sports</span>
            <h3>Tổ Trọng Tài Điều Hành Trận Đấu</h3>
          </div>
          <span className="constraint-badge">
            <span className="material-symbols-outlined">verified_user</span>
            Nguồn: PHAN_CONG_TRONG_TAI &times; TRONG_TAI
          </span>
        </div>

        {refs.length === 0 ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">person_off</span>
            <p>
              Chưa có dữ liệu phân công trọng tài cho trận {m.matran} trong CSDL
              (bảng PHAN_CONG_TRONG_TAI chưa được đồng bộ lên {role === "master" ? "Master" : "trạm"}).
            </p>
          </div>
        ) : (
          <div className="referee-grid">
            {refs.map((ref) => (
              <div key={`${ref.vaitro}-${ref.matrongtai}`} className="referee-item-box">
                <div className="ref-top">
                  <div>
                    <span className="ref-role-label">{VAITRO_LABELS[ref.vaitro] ?? ref.vaitro}</span>
                    <h4 className="ref-name">{ref.hoten}</h4>
                    <p className="ref-grade">
                      Mã: {ref.matrongtai}
                      {ref.capbac ? ` • ${ref.capbac}` : ""}
                    </p>
                  </div>
                  <div className="ref-icon-wrap">
                    <span className="material-symbols-outlined">sports</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* PHẦN 3: CẦU THỦ GHI DẤU ẤN (từ sự kiện thật) + DIỄN BIẾN */}
      <div className="match-core-grid">
        <div className="roster-column">
          <div className="card">
            <div className="card-header-row">
              <div>
                <h3>
                  <span className="material-symbols-outlined text-accent">badge</span>
                  Cầu Thủ Ghi Dấu Ấn Trong Trận
                </h3>
                <p className="card-sub">Gom từ SU_KIEN_TRAN_DAU của trận {m.matran}</p>
              </div>
            </div>

            {matchPlayers.length === 0 ? (
              <div className="empty-state">
                <span className="material-symbols-outlined empty-icon">group_off</span>
                <p>
                  {finished
                    ? "Trận này không ghi nhận sự kiện cầu thủ nào."
                    : "Trận chưa diễn ra - trạm sân nhà sẽ ghi nhận sự kiện thời gian thực khi bóng lăn."}
                </p>
              </div>
            ) : (
              <div className="table-responsive">
                <table className="roster-table compact">
                  <thead>
                    <tr>
                      <th>MÃ</th>
                      <th>CẦU THỦ</th>
                      <th>VỊ TRÍ</th>
                      <th className="number">BÀN ⚽</th>
                      <th className="number">THẺ</th>
                    </tr>
                  </thead>
                  <tbody>
                    {matchPlayers.map(([code, st]) => (
                      <tr key={code}>
                        <td className="font-mono text-muted">#{code}</td>
                        <td>
                          <strong>{st.hoten}</strong>
                        </td>
                        <td>
                          <span className="pos-badge-sm">
                            {st.vitri === "ThuMon"
                              ? "GK"
                              : st.vitri === "HauVe"
                              ? "DF"
                              : st.vitri === "TienVe"
                              ? "MF"
                              : st.vitri === "TienDao"
                              ? "FW"
                              : "—"}
                          </span>
                        </td>
                        <td className="number">
                          {st.goals > 0 ? (
                            <span className="goal-badge">{st.goals} ⚽</span>
                          ) : (
                            <span className="muted-dash">-</span>
                          )}
                        </td>
                        <td className="number">
                          {st.red > 0 ? (
                            <span className="card-badge red">{st.red} 🟥</span>
                          ) : st.yellow > 0 ? (
                            <span className="card-badge yellow">{st.yellow} 🟨</span>
                          ) : (
                            <span className="muted-dash">-</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>

        <div className="events-column">
          <div className="card">
            <div className="card-header-row">
              <div>
                <h3>
                  <span className="material-symbols-outlined text-accent">timeline</span>
                  Diễn Biến Sự Kiện Trận Đấu
                </h3>
                <span className="event-count-badge">{ev.length} SỰ KIỆN GHI NHẬN</span>
              </div>
            </div>

            {ev.length === 0 ? (
              <div className="empty-state">
                <span className="material-symbols-outlined empty-icon">schedule</span>
                <p>
                  {finished
                    ? "Trận này không có sự kiện bàn thắng hoặc thẻ phạt."
                    : "Trận chưa diễn ra - trạm sân nhà sẽ ghi nhận sự kiện thời gian thực khi bóng lăn."}
                </p>
              </div>
            ) : (
              <div className="events-timeline">
                {ev.map((e) => {
                  const isGoal = e.loaisukien === "BanThang";
                  const isOwnGoal = e.loaisukien === "PhanLuoi";
                  const isRed = e.loaisukien === "TheDo";

                  return (
                    <div key={e.masukien} className="timeline-item">
                      <div
                        className={`timeline-min-bubble ${
                          isGoal ? "goal" : isOwnGoal ? "owngoal" : isRed ? "red" : "yellow"
                        }`}
                      >
                        {e.phutghinhan}&prime;
                      </div>

                      <div className="timeline-event-card">
                        <div className="event-info">
                          <span
                            className={`event-type-pill ${
                              isGoal ? "goal" : isOwnGoal ? "owngoal" : isRed ? "red" : "yellow"
                            }`}
                          >
                            {isGoal
                              ? "BÀN THẮNG ⚽"
                              : isOwnGoal
                              ? "PHẢN LƯỚI NHÀ 🥅"
                              : isRed
                              ? "THẺ ĐỎ 🟥"
                              : "THẺ VÀNG 🟨"}
                          </span>
                          <div className="event-player-name">{e.hoten ?? e.macauthu}</div>
                          <div className="event-meta">
                            Mã: {e.macauthu} {e.vitri && `• ${e.vitri}`}
                          </div>
                        </div>

                        <div className="event-icon-badge">
                          {isGoal ? "⚽" : isOwnGoal ? "🥅" : isRed ? "🟥" : "🟨"}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            <div className="integrity-card">
              <div className="integrity-header">
                <span className="material-symbols-outlined text-emerald">rule</span>
                <span className="integrity-title">Đối chiếu số liệu trận đấu</span>
              </div>
              <p className="integrity-desc">
                Tỉ số {m.banthangnha} - {m.banthangkhach} • Thẻ vàng ({m.thevangnha + m.thevangkhach}) •
                Thẻ đỏ ({m.thedonha + m.thedokhach}) — theo TRAN_DAU_CHUYEN_MON. Sự kiện chi tiết: {ev.length} dòng.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
