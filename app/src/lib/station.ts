// src/lib/station.ts - Meta 6 station + station health trên master.
import { querySafe, getStationId, getRole } from "./db";
import type { StationMeta, StationHealth, StationInfo } from "./types";

export const STATIONS: StationMeta[] = [
  { id: 1, club: "HNFC", db: "vleague_hnfc", schema: "site1_hnfc", server: "srv_tuan_hnfc", san: "SAN_HD" },
  { id: 2, club: "CAHN", db: "vleague_cahn", schema: "site2_cahn", server: "srv_thong_cahn", san: "SAN_HD" },
  { id: 3, club: "VTT", db: "vleague_viettel", schema: "site3_viettel", server: "srv_dung_viettel", san: "SAN_MD" },
  { id: 4, club: "HPFC", db: "vleague_haiphong", schema: "site4_hpfc", server: "srv_quanganh_hpfc", san: "SAN_LT" },
  { id: 5, club: "NDFC", db: "vleague_namdinh", schema: "site5_ndfc", server: "srv_bich_ndfc", san: "SAN_TT" },
  { id: 6, club: "HAGL", db: "vleague_hagl", schema: "site6_hagl", server: "srv_minhdung_hagl", san: "SAN_PK" },
];

export async function getStationInfo(): Promise<StationInfo> {
  const role = getRole();
  if (role === "master") {
    return { station_id: 0, station_name: "Master (VFF Trung tâm)", club: "-", role: "master" };
  }
  const id = getStationId();
  const meta = STATIONS.find((s) => s.id === id);
  return {
    station_id: id,
    station_name: meta ? `Station ${id} (${meta.club})` : `Station ${id} (chưa rõ CLB)`,
    club: meta?.club ?? "?",
    role: "station",
  };
}

// Health: schema foreign đã IMPORT chưa + đếm trận. Null = master chưa có view.
export async function getStationsHealth(): Promise<StationHealth[] | null> {
  const imported = await querySafe<{ schema: string }>(
    `SELECT DISTINCT table_schema AS schema FROM information_schema.tables
     WHERE table_type = 'FOREIGN' AND table_name = 'tran_dau_chuyen_mon'`
  );
  if (!imported) return null;
  const have = new Set(imported.map((r) => r.schema));
  const out: StationHealth[] = [];
  for (const s of STATIONS) {
    if (!have.has(s.schema)) {
      out.push({ ...s, imported: false, tranCount: null });
      continue;
    }
    const cnt = await querySafe<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM ${s.schema}.tran_dau_chuyen_mon`
    );
    out.push({ ...s, imported: true, tranCount: cnt ? Number(cnt[0].c) : null });
  }
  return out;
}
