// src/app/fixtures/[id]/page.tsx - Fixture detail + (if played) result + squad + events.

import { query, getRole, getStationId } from "@/lib/db";
import {
  Fixture,
  MatchResult,
  MatchSquadRow,
  MatchEvent,
  Player,
} from "@/lib/types";
import Link from "next/link";
import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

interface PageProps {
  params: { id: string };
}

export default async function FixtureDetail({ params }: PageProps) {
  const fixtureId = Number(params.id);
  if (!Number.isFinite(fixtureId)) notFound();

  const role = getRole();
  const stationId = getStationId();

  const fixtures = await query<Fixture>(
    `SELECT  f.fixture_id, f.round_id, f.home_team, f.away_team,
              f.stadium_id, f.kickoff,
              ht.name AS home_team_name, at.name AS away_team_name,
              std.name AS stadium_name, std.station_id AS home_station_id,
              ro.round_no, s.name AS season_name
     FROM    ref.fixture   f
     JOIN    ref.team      ht  ON ht.team_id = f.home_team
     JOIN    ref.team      at  ON at.team_id = f.away_team
     JOIN    ref.stadium   std ON std.stadium_id = f.stadium_id
     JOIN    ref.round     ro  ON ro.round_id = f.round_id
     JOIN    ref.season    s   ON s.season_id = ro.season_id
     WHERE   f.fixture_id = $1`,
    [fixtureId]
  );
  if (fixtures.length === 0) notFound();
  const f = fixtures[0];

  const results = await query<MatchResult>(
    `SELECT mr.station_id, mr.fixture_id, mr.played_at, mr.home_goals, mr.away_goals,
            mr.attendance, mr.ticket_price::text,
            ht.name AS home_team_name, at.name AS away_team_name,
            std.name AS stadium_name
     FROM match.match_result mr
     JOIN ref.fixture  f   ON f.fixture_id = mr.fixture_id
     JOIN ref.team      ht  ON ht.team_id = f.home_team
     JOIN ref.team      at  ON at.team_id = f.away_team
     JOIN ref.stadium   std ON std.stadium_id = f.stadium_id
     WHERE mr.fixture_id = $1
     ORDER BY mr.played_at DESC
     LIMIT 10`,
    [fixtureId]
  );

  const squadsByTeam: Record<number, MatchSquadRow[]> = {};
  const events = await query<MatchEvent>(
    `SELECT me.station_id, me.event_id, me.fixture_id, me.player_id, me.kind, me.minute,
            p.full_name AS player_name
     FROM match.match_event me
     JOIN ref.player p ON p.player_id = me.player_id
     WHERE me.fixture_id = $1
     ORDER BY me.minute`,
    [fixtureId]
  );

  const squads = await query<MatchSquadRow>(
    `SELECT ms.station_id, ms.fixture_id, ms.player_id, ms.team_id, ms.shirt_no,
            p.full_name AS player_name
     FROM match.match_squad ms
     JOIN ref.player p ON p.player_id = ms.player_id
     WHERE ms.fixture_id = $1
     ORDER BY ms.team_id, ms.shirt_no`,
    [fixtureId]
  );

  for (const s of squads) {
    if (!squadsByTeam[s.team_id]) squadsByTeam[s.team_id] = [];
    squadsByTeam[s.team_id].push(s);
  }

  // Master can edit ref.* ("home_station_id" extended Fixture); station can
  // add match.* if this fixture's stadium belongs to their station.
  const canAddResult =
    role === "station" &&
    stationId > 0 &&
    ((f as unknown as { home_station_id?: number }).home_station_id ?? 0) === stationId &&
    results.length === 0;

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h1 style={{ margin: 0 }}>
          {f.home_team_name} <span className="muted">vs</span> {f.away_team_name}
        </h1>
        <Link className="btn secondary" href="/fixtures">&larr; Danh sách</Link>
      </div>
      <p className="muted">
        {f.season_name} - Vòng {f.round_no} - Sân {f.stadium_name}
        <br />
        {new Date(f.kickoff).toLocaleString("vi-VN")}
      </p>

      {results.length === 0 ? (
        <div className="panel">
          <h2>Kết quả</h2>
          {canAddResult ? (
            <div>
              <p className="muted" style={{ marginBottom: "0.85rem" }}>
                Trận chưa có kết quả. Bạn có thể nhập kết quả cho fixture này (sân thuộc vùng station của bạn).
              </p>
              <Link className="btn" href={`/admin/new-match-result?fixture=${f.fixture_id}`}>
                Nhập kết quả
              </Link>
            </div>
          ) : (
            <p className="empty">
              {role === "master"
                ? "Trận chưa đá - kết quả do station sở hữu stadium nhập."
                : "Trận này không thuộc stadium của station này - không thể nhập kết quả."}
            </p>
          )}
        </div>
      ) : (
        <div className="panel">
          <h2>Tỉ số <small>station {results[0].station_id} - {new Date(results[0].played_at).toLocaleString("vi-VN")}</small></h2>
          <div style={{ fontSize: "1.8rem", fontWeight: 700, textAlign: "center", padding: "1rem" }}>
            {results[0].home_team_name}
            <span className="score" style={{ margin: "0 1rem", fontSize: "2rem" }}>
              {results[0].home_goals} - {results[0].away_goals}
            </span>
            {results[0].away_team_name}
          </div>
          <p className="center muted">
            {results[0].attendance.toLocaleString("vi-VN")} khán giả - vé {Number(results[0].ticket_price).toLocaleString("vi-VN")} ₫
          </p>
        </div>
      )}

      <div className="grid grid-2">
        <div className="panel">
          <h2>Đội hình <small>home: {f.home_team_name}</small></h2>
          {(!squadsByTeam[f.home_team] || squadsByTeam[f.home_team].length === 0) ? (
            <p className="empty">Chưa có squad.</p>
          ) : (
            <ul style={{ paddingLeft: "1.2rem", margin: 0 }}>
              {squadsByTeam[f.home_team].map((s) => (
                <li key={s.player_id}>
                  <span className="muted">#{s.shirt_no}</span> {s.player_name}
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="panel">
          <h2>Đội hình <small>away: {f.away_team_name}</small></h2>
          {(!squadsByTeam[f.away_team] || squadsByTeam[f.away_team].length === 0) ? (
            <p className="empty">Chưa có squad.</p>
          ) : (
            <ul style={{ paddingLeft: "1.2rem", margin: 0 }}>
              {squadsByTeam[f.away_team].map((s) => (
                <li key={s.player_id}>
                  <span className="muted">#{s.shirt_no}</span> {s.player_name}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      <div className="panel">
        <h2>Sự kiện <small>{events.length} bàn/thẻ</small></h2>
        {events.length === 0 ? (
          <p className="empty">Chưa có sự kiện.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Phút</th>
                <th>Cầu thủ</th>
                <th className="right">Loại</th>
              </tr>
            </thead>
            <tbody>
              {events.map((e) => (
                <tr key={e.event_id}>
                  <td className="number">{e.minute}'</td>
                  <td>{e.player_name}</td>
                  <td className="right">
                    <span className={`tag ${e.kind}`}>
                      {e.kind === "goal" ? "Bàn" : e.kind === "yellow" ? "Vàng" : "Đỏ"}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
