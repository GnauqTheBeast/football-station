// src/app/admin/new-match-result/actions.ts - Server action: insert match_result + squad + events.
"use server";

import { query, getStationId, getRole } from "@/lib/db";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

export async function submitMatchResult(formData: FormData) {
  if (getRole() !== "station") {
    throw new Error("Chỉ station mới được nhập match_result.");
  }
  const stationId = getStationId();
  if (stationId <= 0) {
    throw new Error("STATION_ID chưa được cấu hình cho app này.");
  }

  const fixtureId = Number(formData.get("fixture_select"));
  const homeGoals = Number(formData.get("home_goals"));
  const awayGoals = Number(formData.get("away_goals"));
  const attendance = Number(formData.get("attendance"));
  const ticketPrice = Number(formData.get("ticket_price"));
  const squadPlayers = String(formData.get("squad_players") ?? "");
  const events = String(formData.get("events") ?? "");

  if (!Number.isFinite(fixtureId) || fixtureId <= 0) {
    throw new Error("Chưa chọn fixture.");
  }

  // Validate fixture thuộc station này (sân thuộc station).
  const owns = await query<{ ok: number }>(
    `SELECT 1 AS ok
     FROM ref.fixture f
     JOIN ref.stadium s ON s.stadium_id = f.stadium_id
     WHERE f.fixture_id = $1 AND s.station_id = $2`,
    [fixtureId, stationId]
  );
  if (owns.length === 0) {
    throw new Error("Fixture này không thuộc sân của station bạn - không được nhập kết quả.");
  }

  // Insert match_result (idempotent: ON CONFLICT update).
  await query(
    `INSERT INTO match.match_result (station_id, fixture_id, played_at, home_goals, away_goals, attendance, ticket_price)
     VALUES ($1, $2, now(), $3, $4, $5, $6)
     ON CONFLICT (station_id, fixture_id)
     DO UPDATE SET home_goals = EXCLUDED.home_goals,
                   away_goals = EXCLUDED.away_goals,
                   attendance = EXCLUDED.attendance,
                   ticket_price = EXCLUDED.ticket_price`,
    [stationId, fixtureId, homeGoals, awayGoals, attendance, ticketPrice]
  );

  if (squadPlayers.trim()) {
    await query(
      `DELETE FROM match.match_squad WHERE station_id = $1 AND fixture_id = $2`,
      [stationId, fixtureId]
    );
    for (const item of squadPlayers.split(",")) {
      const [pid, tid, shirtStr] = item.split(":").map((x) => x.trim());
      const pidN = Number(pid), tidN = Number(tid), shirtN = Number(shirtStr);
      if (!Number.isFinite(pidN) || !Number.isFinite(tidN) || !Number.isFinite(shirtN)) continue;
      try {
        await query(
          `INSERT INTO match.match_squad (station_id, fixture_id, player_id, team_id, shirt_no)
           VALUES ($1, $2, $3, $4, $5)`,
          [stationId, fixtureId, pidN, tidN, shirtN]
        );
      } catch {
        // Trigger có thể reject (player chưa đăng ký, >18). Bỏ qua row lỗi.
      }
    }
  }

  if (events.trim()) {
    await query(
      `DELETE FROM match.match_event WHERE station_id = $1 AND fixture_id = $2`,
      [stationId, fixtureId]
    );
    for (const item of events.split(",")) {
      const [pid, kind, minuteStr] = item.split(":").map((x) => x.trim());
      const pidN = Number(pid), minuteN = Number(minuteStr);
      if (!Number.isFinite(pidN) || !Number.isFinite(minuteN)) continue;
      if (!["goal", "yellow", "red"].includes(kind)) continue;
      try {
        await query(
          `INSERT INTO match.match_event (station_id, fixture_id, player_id, kind, minute)
           VALUES ($1, $2, $3, $4, $5)`,
          [stationId, fixtureId, pidN, kind, minuteN]
        );
      } catch {
        // Trigger có thể reject. Bỏ qua row lỗi.
      }
    }
  }

  revalidatePath(`/fixtures/${fixtureId}`);
  redirect(`/fixtures/${fixtureId}`);
}

export async function deleteMatchResult(formData: FormData) {
  if (getRole() !== "station") {
    throw new Error("Chỉ station mới được xóa match_result.");
  }
  const stationId = getStationId();
  const fixtureId = Number(formData.get("fixture_id"));
  if (!Number.isFinite(fixtureId)) throw new Error("fixture_id không hợp lệ");
  await query(`DELETE FROM match.match_event WHERE station_id = $1 AND fixture_id = $2`, [stationId, fixtureId]);
  await query(`DELETE FROM match.match_squad WHERE station_id = $1 AND fixture_id = $2`, [stationId, fixtureId]);
  await query(`DELETE FROM match.match_result WHERE station_id = $1 AND fixture_id = $2`, [stationId, fixtureId]);
  revalidatePath(`/fixtures/${fixtureId}`);
  redirect(`/fixtures/${fixtureId}`);
}
