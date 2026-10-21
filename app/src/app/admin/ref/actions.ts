// src/app/admin/ref/actions.ts - Master-only: add teams, players, referees, fixtures.
"use server";

import { query, getRole } from "@/lib/db";
import { revalidatePath } from "next/cache";

function requireMaster() {
  if (getRole() !== "master") {
    throw new Error("Chỉ role=master mới được chỉnh ref.*");
  }
}

export async function addTeam(formData: FormData) {
  requireMaster();
  const homeStadiumId = Number(formData.get("home_stadium_id"));
  const name = String(formData.get("name") ?? "").trim();
  const foundedYear = Number(formData.get("founded_year"));
  if (!name || !Number.isFinite(homeStadiumId) || !Number.isFinite(foundedYear)) {
    throw new Error("Thiếu hoặc sai trường khi thêm team.");
  }
  await query(
    `INSERT INTO ref.team (home_stadium_id, name, founded_year)
     VALUES ($1, $2, $3)`,
    [homeStadiumId, name, foundedYear]
  );
  revalidatePath("/admin/ref");
}

export async function addStadium(formData: FormData) {
  requireMaster();
  const stationId = Number(formData.get("station_id"));
  const name = String(formData.get("name") ?? "").trim();
  const capacity = Number(formData.get("capacity"));
  if (!name || !Number.isFinite(stationId) || !Number.isFinite(capacity)) {
    throw new Error("Thiếu hoặc sai trường khi thêm stadium.");
  }
  await query(
    `INSERT INTO ref.stadium (station_id, name, capacity) VALUES ($1, $2, $3)`,
    [stationId, name, capacity]
  );
  revalidatePath("/admin/ref");
}

export async function addPlayer(formData: FormData) {
  requireMaster();
  const fullName = String(formData.get("full_name") ?? "").trim();
  const birthDate = String(formData.get("birth_date") ?? "").trim();
  const nationality = String(formData.get("nationality") ?? "").trim();
  const position = String(formData.get("position") ?? "FW").trim();
  if (!fullName || !birthDate || !nationality) {
    throw new Error("Thiếu trường khi thêm player.");
  }
  if (!["GK", "DF", "MF", "FW"].includes(position)) {
    throw new Error("position phải là GK/DF/MF/FW");
  }
  await query(
    `INSERT INTO ref.player (full_name, birth_date, nationality, position)
     VALUES ($1, $2, $3, $4)`,
    [fullName, birthDate, nationality, position]
  );
  revalidatePath("/admin/ref");
}

export async function addReferee(formData: FormData) {
  requireMaster();
  const fullName = String(formData.get("full_name") ?? "").trim();
  const birthDate = String(formData.get("birth_date") ?? "").trim();
  const level = String(formData.get("level") ?? "national").trim();
  if (!fullName || !birthDate) {
    throw new Error("Thiếu trường khi thêm referee.");
  }
  if (!["FIFA", "elite", "national", "regional"].includes(level)) {
    throw new Error("level phải là FIFA/elite/national/regional");
  }
  await query(
    `INSERT INTO ref.referee (full_name, birth_date, level) VALUES ($1, $2, $3)`,
    [fullName, birthDate, level]
  );
  revalidatePath("/admin/ref");
}

export async function addFixture(formData: FormData) {
  requireMaster();
  const roundId = Number(formData.get("round_id"));
  const homeTeam = Number(formData.get("home_team"));
  const awayTeam = Number(formData.get("away_team"));
  const stadiumId = Number(formData.get("stadium_id"));
  const kickoff = String(formData.get("kickoff") ?? "").trim();
  if (!Number.isFinite(roundId) || !Number.isFinite(homeTeam) || !Number.isFinite(awayTeam) || !Number.isFinite(stadiumId) || !kickoff) {
    throw new Error("Thiếu trường khi thêm fixture.");
  }
  if (homeTeam === awayTeam) {
    throw new Error("home_team và away_team phải khác nhau.");
  }
  // Convert naive datetime-local "YYYY-MM-DDTHH:MM" to timestamptz
  const kickoffTz = kickoff.replace("T", " ") + ":00+07";
  await query(
    `INSERT INTO ref.fixture (round_id, home_team, away_team, stadium_id, kickoff)
     VALUES ($1, $2, $3, $4, $5::timestamptz)`,
    [roundId, homeTeam, awayTeam, stadiumId, kickoffTz]
  );
  revalidatePath("/admin/ref");
}

export async function renameTeam(formData: FormData) {
  requireMaster();
  const teamId = Number(formData.get("team_id"));
  const name = String(formData.get("name") ?? "").trim();
  if (!Number.isFinite(teamId) || !name) {
    throw new Error("team_id hoặc name không hợp lệ");
  }
  await query(
    `UPDATE ref.team SET name = $2 WHERE team_id = $1`,
    [teamId, name]
  );
  revalidatePath("/admin/ref");
  revalidatePath("/standings");
}
