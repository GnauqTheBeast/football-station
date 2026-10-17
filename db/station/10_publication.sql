-- Station databases publish their local data to the master.
-- Idempotent: safe to re-run by scripts/start-station.sh on an existing volume.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'station_publication') THEN
    CREATE PUBLICATION station_publication FOR TABLE demo.message;
  END IF;
END $$;
