// src/app/page.tsx - Dashboard: KPIs + recent played/next fixtures.

import { getStationInfo } from "@/lib/station";
import { getStationId, getRole, query } from "@/lib/db";
import type { Fixture, MatchResult, Standing, Player } from "@/lib/types";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function Dashboard() {
  const role = getRole();
  const stationId = getStationId();
  const station = await getStationInfo();

  // For master: see ALL matches; for station: only this station's matches.
  const matchFilter = role === "station" && stationId > 0 ? "mr.station_id = $1" : "TRUE";
  const params = role === "station" && stationId > 0 ? [stationId] : [];

  const recent = await query<MatchResult>(
    `SELECT mr.station_id, mr.fixture_id, mr.played_at, mr.home_goals, mr.away_goals,
            mr.attendance, mr.ticket_price::text,
            ht.name AS home_team_name, at.name AS away_team_name,
            std.name AS stadium_name
     FROM match.match_result mr
     JOIN ref.fixture  f   ON f.fixture_id = mr.fixture_id
     JOIN ref.team     ht  ON ht.team_id = f.home_team
     JOIN ref.team     at  ON at.team_id = f.away_team
     JOIN ref.stadium  std ON std.stadium_id = f.stadium_id
     WHERE ${matchFilter}
     ORDER BY mr.played_at DESC
     LIMIT 5`,
    params
  );

  const upcoming = await query<Fixture>(
    `SELECT f.fixture_id, f.round_id, f.home_team, f.away_team, f.stadium_id, f.kickoff,
            ht.name AS home_team_name, at.name AS away_team_name,
            std.name AS stadium_name, ro.round_no, s.name AS season_name
     FROM ref.fixture        f
     JOIN ref.team           ht  ON ht.team_id = f.home_team
     JOIN ref.team           at  ON at.team_id = f.away_team
     JOIN ref.stadium        std ON std.stadium_id = f.stadium_id
     JOIN ref.round          ro  ON ro.round_id = f.round_id
     JOIN ref.season         s   ON s.season_id = ro.season_id
     WHERE f.kickoff > now()
       AND NOT EXISTS (
         SELECT 1 FROM match.match_result mr WHERE mr.fixture_id = f.fixture_id
         ${role === "station" && stationId > 0 ? "AND mr.station_id = $1" : ""}
       )
     ORDER BY f.kickoff ASC
     LIMIT 5`,
    params
  );

  const standings = role === "master" ? await query<Standing>(
    "SELECT * FROM ref.v_standings LIMIT 8"
  ) : [];

  const playerCount = await query<{count: number}>("SELECT count(*)::int AS count FROM ref.player");
  const teamCount = await query<{count: number}>("SELECT count(*)::int AS count FROM ref.team");
  const fixtureCount = await query<{count: number}>("SELECT count(*)::int AS count FROM ref.fixture");
  const resultCount = await query<{count: number}>(
    `SELECT count(*)::int AS count FROM match.match_result
     ${role === "station" && stationId > 0 ? "WHERE station_id = $1" : ""}`,
    role === "station" && stationId > 0 ? [stationId] : []
  );

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>
        {role === "master" ? "Master Dashboard" : `Trạm ${station?.station_name ?? "?"}`}
      </h1>
      <p className="muted">
        {role === "master"
          ? "Trung tâm dữ liệu - có quyền ghi ref.*, xem tất cả match.* replicate từ các station."
          : `Sân nhà: ${station?.stadium_name ?? "?"} (sức chứa ${station?.capacity ?? 0}). Có quyền ghi match.* cho station_id=${stationId}.`}
      </p>

      <div className="kpis">
        <div className="kpi">
          <div className="label">Đội bóng</div>
          <div className="value">{teamCount[0].count}</div>
        </div>
        <div className="kpi">
          <div className="label">Cầu thủ</div>
          <div className="value">{playerCount[0].count}</div>
        </div>
        <div className="kpi">
          <div className="label">Lịch đấu</div>
          <div className="value">{fixtureCount[0].count}</div>
        </div>
        <div className="kpi">
          <div className="label">Trận đã đá</div>
          <div className="value">{resultCount[0].count}</div>
        </div>
      </div>

      <div className="grid grid-2">
        <div className="panel">
          <h2>
            Trận đã đá gần đây <small>top 5</small>
          </h2>
          {recent.length === 0 ? (
            <p className="empty">Chưa có trận nào. Vào "Nhập kết quả" để thêm.</p>
          ) : (
            <table>
              <tbody>
                {recent.map((r) => (
                  <tr key={`${r.fixture_id}-${r.station_id}`}>
                    <td>
                      <Link href={`/fixtures/${r.fixture_id}`}>
                        {r.home_team_name} <span className="score">{r.home_goals}-{r.away_goals}</span> {r.away_team_name}
                      </Link>
                      <div className="muted" style={{fontSize: "0.75rem"}}>
                        {new Date(r.played_at).toLocaleString("vi-VN")} - {r.stadium_name}
                      </div>
                    </td>
                    <td className="right muted">{r.attendance.toLocaleString("vi-VN")} khán giả</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        <div className="panel">
          <h2>
            Trận sắp tới <small>top 5</small>
          </h2>
          {upcoming.length === 0 ? (
            <p className="empty">Không có trận sắp tới. Thêm fixture qua ref.* trên master.</p>
          ) : (
            <table>
              <tbody>
                {upcoming.map((f) => (
                  <tr key={f.fixture_id}>
                    <td>
                      <Link href={`/fixtures/${f.fixture_id}`}>
                        {f.home_team_name} <span className="muted">vs</span> {f.away_team_name}
                      </Link>
                      <div className="muted" style={{fontSize: "0.75rem"}}>
                        {new Date(f.kickoff).toLocaleString("vi-VN")} - Vòng {f.round_no} - {f.stadium_name}
                      </div>
                    </td>
                    {role === "station" && (
                      <td className="right">
                        <Link className="btn secondary" href={`/admin/new-match-result?fixture=${f.fixture_id}`}>
                          Nhập
                        </Link>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {role === "master" && standings.length > 0 && (
        <div className="panel">
          <h2>Bảng xếp hạng <small>tổng hợp từ tất cả stations</small></h2>
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Đội</th>
                <th className="number">T</th>
                <th className="number">H</th>
                <th className="number">B</th>
                <th className="number">Bàn</th>
                <th className="number">HS</th>
                <th className="number">Đ</th>
              </tr>
            </thead>
            <tbody>
              {standings.map((s, i) => (
                <tr key={s.team_id}>
                  <td className="muted">{i + 1}</td>
                  <td>{s.name}</td>
                  <td className="number">{s.played}</td>
                  <td className="number good">{s.won}</td>
                  <td className="number">{s.drawn}</td>
                  <td className="number bad">{s.lost}</td>
                  <td className="number">{s.gf}-{s.ga}</td>
                  <td className="number">{s.gd >= 0 ? "+" : ""}{s.gd}</td>
                  <td className="number"><strong>{s.pts}</strong></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
