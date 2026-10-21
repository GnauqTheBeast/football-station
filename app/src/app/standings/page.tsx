// src/app/standings/page.tsx - Bảng xếp hạng full.
import { query } from "@/lib/db";
import type { Standing } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function Standings() {
  const rows = await query<Standing>("SELECT * FROM ref.v_standings");
  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Bảng xếp hạng</h1>
      <p className="muted">{rows.length} đội. Tổng hợp từ tất cả station qua master_subscription.</p>

      <div className="panel">
        {rows.length === 0 ? (
          <p className="empty">Chưa có trận nào đá xong.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Đội</th>
                <th className="number">Trận</th>
                <th className="number">Thắng</th>
                <th className="number">Hòa</th>
                <th className="number">Thua</th>
                <th className="number">Bàn thắng</th>
                <th className="number">Bàn thua</th>
                <th className="number">HS</th>
                <th className="number">Điểm</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((s, i) => (
                <tr key={s.team_id}>
                  <td className="muted">{i + 1}</td>
                  <td><strong>{s.name}</strong></td>
                  <td className="number">{s.played}</td>
                  <td className="number good">{s.won}</td>
                  <td className="number">{s.drawn}</td>
                  <td className="number bad">{s.lost}</td>
                  <td className="number">{s.gf}</td>
                  <td className="number">{s.ga}</td>
                  <td className="number">{s.gd >= 0 ? "+" : ""}{s.gd}</td>
                  <td className="number"><strong>{s.pts}</strong></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
