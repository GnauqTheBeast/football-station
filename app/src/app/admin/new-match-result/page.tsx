// src/app/admin/new-match-result/page.tsx - Form nhập kết quả cho station.
import { query, getStationId, getRole } from "@/lib/db";
import type { Fixture, Player } from "@/lib/types";
import { submitMatchResult } from "./actions";
import Link from "next/link";

export const dynamic = "force-dynamic";

interface PageProps {
  searchParams: { fixture?: string };
}

export default async function NewMatchResultPage({ searchParams }: PageProps) {
  const role = getRole();
  const stationId = getStationId();

  if (role !== "station" || stationId <= 0) {
    return (
      <div>
        <h1>Nhập kết quả</h1>
        <div className="alert error">
          Trang này chỉ dành cho station. App này đang chạy role=master - master không ghi match.*.
        </div>
        <Link className="btn secondary" href="/">Quay lại Dashboard</Link>
      </div>
    );
  }

  const fixtures = await query<Fixture>(
    `SELECT  f.fixture_id, f.round_id, f.home_team, f.away_team,
              f.stadium_id, f.kickoff,
              ht.name AS home_team_name, at.name AS away_team_name,
              std.name AS stadium_name, ro.round_no, s.name AS season_name
     FROM    ref.fixture   f
     JOIN    ref.team      ht  ON ht.team_id = f.home_team
     JOIN    ref.team      at  ON at.team_id = f.away_team
     JOIN    ref.stadium   std ON std.stadium_id = f.stadium_id
     JOIN    ref.round     ro  ON ro.round_id = f.round_id
     JOIN    ref.season    s   ON s.season_id = ro.season_id
     WHERE   std.station_id = $1
       AND   NOT EXISTS (
              SELECT 1 FROM match.match_result mr
              WHERE mr.fixture_id = f.fixture_id AND mr.station_id = $1
            )
     ORDER BY f.kickoff ASC`,
    [stationId]
  );

  const players = await query<Player>("SELECT * FROM ref.player ORDER BY player_id");

  const initialFixtureId =
    searchParams.fixture && Number.isFinite(Number(searchParams.fixture))
      ? Number(searchParams.fixture)
      : fixtures[0]?.fixture_id;

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Nhập kết quả</h1>
      <p className="muted">
        Station {stationId}. Chỉ nhập cho fixture có sân thuộc station của bạn.
      </p>

      {fixtures.length === 0 ? (
        <div className="alert error">Không có fixture nào sẵn sàng để nhập kết quả.</div>
      ) : (
        <form action={submitMatchResult} className="panel">
          <div className="form-row">
            <label>Trận</label>
            <select name="fixture_select" defaultValue={initialFixtureId}>
              {fixtures.map((f) => (
                <option key={f.fixture_id} value={f.fixture_id}>
                  {f.home_team_name} vs {f.away_team_name} - {new Date(f.kickoff).toLocaleString("vi-VN")} ({f.stadium_name})
                </option>
              ))}
            </select>
            <small className="muted">
              Chọn fixture ở drop-down (form sẽ submit fixture này).
            </small>
          </div>

          <div className="form-grid-2">
            <div className="form-row">
              <label>Bàn thắng đội nhà</label>
              <input type="number" name="home_goals" min={0} max={20} required defaultValue={0} />
            </div>
            <div className="form-row">
              <label>Bàn thắng đội khách</label>
              <input type="number" name="away_goals" min={0} max={20} required defaultValue={0} />
            </div>
            <div className="form-row">
              <label>Số khán giả</label>
              <input type="number" name="attendance" min={0} required defaultValue={0} />
            </div>
            <div className="form-row">
              <label>Giá vé (₫)</label>
              <input type="number" name="ticket_price" min={0} step={1000} required defaultValue={100000} />
            </div>
          </div>

          <div className="form-row">
            <label>Đội hình (CSV - từng player_id:team_id:shirt_no, cách nhau bởi dấu phẩy) <small>tùy chọn</small></label>
            <textarea name="squad_players" rows={2} placeholder="1:1:10, 2:1:11, 5:2:9" />
            <small className="muted">Số áo không trùng. Cầu thủ phải đang đăng ký cho đội đó.</small>
          </div>

          <div className="form-row">
            <label>Sự kiện (CSV - từng player_id:kind:minute, kind ∈ goal/yellow/red) <small>tùy chọn</small></label>
            <textarea name="events" rows={2} placeholder="1:goal:14, 5:yellow:60" />
            <small className="muted">Cầu thủ phải nằm trong squad. Tổng goal phải khớp tỉ số.</small>
          </div>

          <button type="submit" className="btn">Lưu kết quả</button>
        </form>
      )}

      <div className="panel" style={{ marginTop: "1.5rem", background: "var(--panel-light)", borderColor: "var(--border)" }}>
        <h2>Hướng dẫn CSV</h2>
        <p className="muted" style={{ fontSize: "0.85rem", lineHeight: 1.6 }}>
          <strong>Đội hình</strong>: <code>player_id:team_id:shirt_no</code>, ví dụ <code>1:1:10, 2:1:11, 5:2:9</code>.<br />
          <strong>Sự kiện</strong>: <code>player_id:kind:minute</code>, kind là <code>goal</code>, <code>yellow</code> hoặc <code>red</code>.<br />
          Trigger DB có thể reject row nếu cầu thủ không đăng ký cho đội / không có trong squad. Row lỗi bị bỏ qua, row hợp lệ vẫn được insert.
        </p>
      </div>

      <div className="panel" style={{ background: "var(--panel-light)", borderColor: "var(--border)" }}>
        <h2>Danh sách cầu thủ (ref.player đã nhân bản tới station)</h2>
        <table>
          <thead>
            <tr><th>player_id</th><th>Họ tên</th><th>Quốc tịch</th><th>Vị trí</th></tr>
          </thead>
          <tbody>
            {players.map((p) => (
              <tr key={p.player_id}>
                <td>{p.player_id}</td>
                <td>{p.full_name}</td>
                <td>{p.nationality}</td>
                <td>{p.position}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
