// src/app/fixtures/page.tsx - Lịch thi đấu full.

import { query } from "@/lib/db";
import type { Fixture } from "@/lib/types";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function FixturesList() {
  const fixtures = await query<Fixture>(
    `SELECT  f.fixture_id, f.round_id, f.home_team, f.away_team,
              f.stadium_id, f.kickoff,
              ht.name AS home_team_name, at.name AS away_team_name,
              std.name AS stadium_name, ro.round_no, s.name AS season_name,
              EXISTS (SELECT 1 FROM match.match_result mr WHERE mr.fixture_id = f.fixture_id) AS has_result
       FROM   ref.fixture   f
       JOIN   ref.team      ht  ON ht.team_id = f.home_team
       JOIN   ref.team      at  ON at.team_id = f.away_team
       JOIN   ref.stadium   std ON std.stadium_id = f.stadium_id
       JOIN   ref.round     ro  ON ro.round_id = f.round_id
       JOIN   ref.season    s   ON s.season_id = ro.season_id
       ORDER  BY s.name, ro.round_no, f.kickoff`
  );

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Lịch thi đấu</h1>
      <p className="muted">{fixtures.length} trận đã lên lịch.</p>

      <div className="panel">
        <table>
          <thead>
            <tr>
              <th>Vòng</th>
              <th>Cặp trận</th>
              <th>Sân</th>
              <th>Thời gian</th>
              <th className="right">Trạng thái</th>
            </tr>
          </thead>
          <tbody>
            {fixtures.map((f) => (
              <tr key={f.fixture_id}>
                <td>{f.season_name} - Vòng {f.round_no}</td>
                <td>
                  <Link href={`/fixtures/${f.fixture_id}`}>
                    <strong>{f.home_team_name}</strong> vs <strong>{f.away_team_name}</strong>
                  </Link>
                </td>
                <td>{f.stadium_name}</td>
                <td>{new Date(f.kickoff).toLocaleString("vi-VN")}</td>
                <td className="right">
                  {Date.now() < new Date(f.kickoff).getTime()
                    ? <span className="muted">chưa đá</span>
                    : <Link href={`/fixtures/${f.fixture_id}`} className="tag">xem</Link>}
                  {/* has_result is bool cast from SELECT EXISTS - typed loosely */}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
