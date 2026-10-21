// src/lib/station.ts - Resolve the StationInfo for this app instance
// using STATION_ID env var. Master has STATION_ID=0 and no station row.
import { query, getStationId, getRole } from "./db";
import type { StationInfo } from "./types";

export async function getStationInfo(): Promise<StationInfo | null> {
  const stationId = getStationId();
  const role = getRole();
  if (stationId === 0 || role === "master") {
    // Master app: not bound to a particular station.
    return {
      station_id: 0,
      station_name: "Master (central)",
      region: "-",
      stadium_id: 0,
      stadium_name: "-",
      capacity: 0,
      role: "master",
    };
  }

  const rows = await query<StationInfo>(
    `SELECT  s.station_id,
              s.name    AS station_name,
              s.region,
              st.stadium_id,
              st.name    AS stadium_name,
              st.capacity
       FROM ref.station s
       LEFT JOIN ref.stadium st ON st.station_id = s.station_id
       WHERE s.station_id = $1
       LIMIT 1`,
    [stationId]
  );

  if (rows.length === 0) return null;
  return { ...rows[0], role: "station" };
}
