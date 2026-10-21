// src/app/admin/ref/page.tsx - Master-only: CRUD forms for ref.* tables.
import { getRole, query } from "@/lib/db";
import type { Team, Stadium, Player, Station, Round, Season } from "@/lib/types";
import Link from "next/link";
import {
  addTeam,
  addStadium,
  addPlayer,
  addReferee,
  addFixture,
  renameTeam,
} from "./actions";

export const dynamic = "force-dynamic";

export default async function RefAdmin() {
  const role = getRole();

  if (role !== "master") {
    return (
      <div>
        <h1>Ref data</h1>
        <div className="alert error">
          Trang này chỉ dành cho role=master. Station nhận ref.* qua replication - không được ghi trực tiếp.
        </div>
        <Link className="btn secondary" href="/">Quay lại Dashboard</Link>
      </div>
    );
  }

  const teams = await query<Team>("SELECT * FROM ref.team ORDER BY team_id");
  const stadiums = await query<Stadium & { station_name?: string }>(
    `SELECT s.*, st.name AS station_name
     FROM ref.stadium s LEFT JOIN ref.station st ON st.station_id = s.station_id
     ORDER BY s.stadium_id`
  );
  const players = await query<Player>("SELECT * FROM ref.player ORDER BY player_id LIMIT 50");
  const referees = await query<{ referee_id: number; full_name: string; birth_date: string; level: string }>(
    "SELECT * FROM ref.referee ORDER BY referee_id"
  );
  const stations = await query<Station>("SELECT * FROM ref.station ORDER BY station_id");
  const seasons = await query<Season>("SELECT * FROM ref.season ORDER BY season_id");
  const rounds = await query<{ round_id: number; season_id: number; round_no: number; start_date: string; end_date: string }>(
    "SELECT * FROM ref.round ORDER BY round_id"
  );

  return (
    <div>
      <h1 style={{ marginTop: 0 }}>Ref data <small className="muted">(master-only)</small></h1>
      <p className="muted">
        Thêm/sửa ref.* ở đây. Mọi thay đổi sẽ nhân bản xuống toàn bộ station qua master_publication.
      </p>

      <div className="grid grid-2">
        {/* Stadium form */}
        <div className="panel">
          <h2>Thêm sân (stadium)</h2>
          <form action={addStadium}>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Station sở hữu</label>
                <select name="station_id" required>
                  {stations.map((s) => (
                    <option key={s.station_id} value={s.station_id}>
                      {s.station_id} - {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>Sức chứa</label>
                <input type="number" name="capacity" min={100} required defaultValue={10000} />
              </div>
            </div>
            <div className="form-row">
              <label>Tên sân</label>
              <input type="text" name="name" required />
            </div>
            <button className="btn" type="submit">Thêm sân</button>
          </form>
          <table style={{ marginTop: "1rem" }}>
            <thead><tr><th>id</th><th>Sân</th><th>Station</th><th className="number">Capacity</th></tr></thead>
            <tbody>
              {stadiums.map((s) => (
                <tr key={s.stadium_id}>
                  <td>{s.stadium_id}</td>
                  <td>{s.name}</td>
                  <td>{s.station_name}</td>
                  <td className="number">{s.capacity.toLocaleString("vi-VN")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Team form */}
        <div className="panel">
          <h2>Thêm đội (team)</h2>
          <form action={addTeam}>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Sân nhà</label>
                <select name="home_stadium_id" required>
                  {stadiums.map((s) => (
                    <option key={s.stadium_id} value={s.stadium_id}>
                      {s.stadium_id} - {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>Năm thành lập</label>
                <input type="number" name="founded_year" min={1850} max={new Date().getFullYear()} required defaultValue={1990} />
              </div>
            </div>
            <div className="form-row">
              <label>Tên đội</label>
              <input type="text" name="name" required />
            </div>
            <button className="btn" type="submit">Thêm đội</button>
          </form>

          {/* Rename an existing team (demonstrates master->station replication) */}
          <h3 style={{ marginTop: "1.25rem", fontSize: "0.9rem" }}>Đổi tên đội (test master → station replication)</h3>
          <form action={renameTeam} style={{ display: "flex", gap: "0.5rem", alignItems: "end" }}>
            <div className="form-row" style={{ flex: 1 }}>
              <label>Team</label>
              <select name="team_id" required>
                {teams.map((t) => (
                  <option key={t.team_id} value={t.team_id}>
                    {t.team_id} - {t.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-row" style={{ flex: 1.5 }}>
              <label>Tên mới</label>
              <input type="text" name="name" required />
            </div>
            <button className="btn secondary" type="submit">Đổi</button>
          </form>

          <table style={{ marginTop: "1rem" }}>
            <thead><tr><th>id</th><th>Tên</th><th>Sân nhà</th><th className="number">Thành lập</th></tr></thead>
            <tbody>
              {teams.map((t) => (
                <tr key={t.team_id}>
                  <td>{t.team_id}</td>
                  <td>{t.name}</td>
                  <td>{t.home_stadium_id}</td>
                  <td className="number">{t.founded_year}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Player form */}
        <div className="panel">
          <h2>Thêm cầu thủ (player)</h2>
          <form action={addPlayer}>
            <div className="form-row">
              <label>Họ tên</label>
              <input type="text" name="full_name" required />
            </div>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Ngày sinh</label>
                <input type="date" name="birth_date" required />
              </div>
              <div className="form-row">
                <label>Quốc tịch</label>
                <input type="text" name="nationality" required defaultValue="Vietnam" />
              </div>
            </div>
            <div className="form-row">
              <label>Vị trí</label>
              <select name="position" required defaultValue="FW">
                <option value="GK">GK</option>
                <option value="DF">DF</option>
                <option value="MF">MF</option>
                <option value="FW">FW</option>
              </select>
            </div>
            <button className="btn" type="submit">Thêm cầu thủ</button>
          </form>
          <table style={{ marginTop: "1rem" }}>
            <thead><tr><th>id</th><th>Họ tên</th><th>Quốc tịch</th><th>VT</th></tr></thead>
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

        {/* Referee form */}
        <div className="panel">
          <h2>Thêm trọng tài (referee)</h2>
          <form action={addReferee}>
            <div className="form-row">
              <label>Họ tên</label>
              <input type="text" name="full_name" required />
            </div>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Ngày sinh</label>
                <input type="date" name="birth_date" required />
              </div>
              <div className="form-row">
                <label>Cấp</label>
                <select name="level" required defaultValue="national">
                  <option value="FIFA">FIFA</option>
                  <option value="elite">elite</option>
                  <option value="national">national</option>
                  <option value="regional">regional</option>
                </select>
              </div>
            </div>
            <button className="btn" type="submit">Thêm trọng tài</button>
          </form>
          <table style={{ marginTop: "1rem" }}>
            <thead><tr><th>id</th><th>Họ tên</th><th>Cấp</th></tr></thead>
            <tbody>
              {referees.map((r) => (
                <tr key={r.referee_id}>
                  <td>{r.referee_id}</td>
                  <td>{r.full_name}</td>
                  <td>{r.level}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Fixture form */}
        <div className="panel" style={{ gridColumn: "1 / -1" }}>
          <h2>Thêm trận đấu (fixture)</h2>
          <form action={addFixture}>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Vòng</label>
                <select name="round_id" required>
                  {rounds.map((r) => (
                    <option key={r.round_id} value={r.round_id}>
                      Vòng {r.round_no} (id {r.round_id})
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>Sân</label>
                <select name="stadium_id" required>
                  {stadiums.map((s) => (
                    <option key={s.stadium_id} value={s.stadium_id}>
                      {s.stadium_id} - {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>Đội nhà</label>
                <select name="home_team" required>
                  {teams.map((t) => (
                    <option key={t.team_id} value={t.team_id}>{t.team_id} - {t.name}</option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>Đội khách</label>
                <select name="away_team" required>
                  {teams.map((t) => (
                    <option key={t.team_id} value={t.team_id}>{t.team_id} - {t.name}</option>
                  ))}
                </select>
              </div>
              <div className="form-row">
                <label>Thời gian kickoff (giờ VN)</label>
                <input type="datetime-local" name="kickoff" required />
              </div>
            </div>
            <button className="btn" type="submit">Thêm fixture</button>
          </form>
          <p className="muted" style={{ marginTop: "1rem", fontSize: "0.85rem" }}>
            ⚠️ Trigger "fixture_kickoff_in_round" yêu cầu kickoff nằm trong khoảng round.start_date .. round.end_date.
          </p>
        </div>
      </div>

      <div className="panel" style={{ marginTop: "1.5rem" }}>
        <h2>Stations</h2>
        <table>
          <thead><tr><th>id</th><th>Tên</th><th>Region</th></tr></thead>
          <tbody>
            {stations.map((s) => (
              <tr key={s.station_id}>
                <td>{s.station_id}</td>
                <td>{s.name}</td>
                <td>{s.region}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="panel">
        <h2>Seasons & Rounds</h2>
        <table>
          <thead><tr><th>Season</th><th>Round_no</th><th>Bắt đầu</th><th>Kết thúc</th></tr></thead>
          <tbody>
            {rounds.map((r) => {
              const season = seasons.find((s) => s.season_id === r.season_id);
              const fmt = (d: string | Date) =>
                d instanceof Date ? d.toISOString().slice(0, 10) : String(d);
              return (
                <tr key={r.round_id}>
                  <td>{season?.name ?? r.season_id}</td>
                  <td>{r.round_no}</td>
                  <td>{fmt(r.start_date)}</td>
                  <td>{fmt(r.end_date)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
