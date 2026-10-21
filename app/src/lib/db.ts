// src/lib/db.ts - PostgreSQL connection pool (server-only)
import { Pool } from "pg";

// All env vars are read at module load time (server-side only).
// Sent through docker-compose env or .env.local in dev.
const host = process.env.POSTGRES_HOST ?? "localhost";
const port = Number(process.env.POSTGRES_PORT ?? 5430);
const user = process.env.POSTGRES_USER ?? "admin";
const password = process.env.POSTGRES_PASSWORD ?? "admin123";
const database = process.env.POSTGRES_DB ?? "football";

if (!host) {
  throw new Error("POSTGRES_HOST env var required by db.ts");
}

// Reuse pool across hot reloads in dev.
const globalForDb = globalThis as unknown as { __pgPool?: Pool };

export const pool: Pool =
  globalForDb.__pgPool ??
  new Pool({
    host,
    port,
    user,
    password,
    database,
    max: 5,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

if (process.env.NODE_ENV !== "production") globalForDb.__pgPool = pool;

export async function query<T = Record<string, any>>(
  text: string,
  params?: (string | number | null)[]
): Promise<T[]> {
  const res = await pool.query(text, params);
  return res.rows as unknown as T[];
}

// Read once per request - the station this app instance represents.
export function getStationId(): number {
  const v = process.env.STATION_ID ?? "0";
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : 0;
}

export function getRole(): "master" | "station" {
  return process.env.NODE_ROLE === "master" ? "master" : "station";
}
