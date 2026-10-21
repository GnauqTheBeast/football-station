// src/app/scorers/page.tsx - Top scorers view.
import { query } from "@/lib/db";
import type { TopScorer } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function Scorers() {
  const rows = await query<TopScorer>("SELECT * FROM ref.v_top_scorers");
  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Vua phá lưới</h1>
      <p className="muted">Top 10. Tổng hợp từ match_event qua các station.</p>

      <div className="panel">
        {rows.length === 0 ? (
          <p className="empty">Chưa có bàn thắng nào được ghi.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Cầu thủ</th>
                <th>Đội</th>
                <th className="number">Bàn</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((s, i) => (
                <tr key={s.player_id}>
                  <td className="muted">{i + 1}</td>
                  <td><strong>{s.full_name}</strong></td>
                  <td>{s.team_name}</td>
                  <td className="number"><strong>{s.goals}</strong></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
