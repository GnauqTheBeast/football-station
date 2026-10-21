-- =========================================================================
-- 10_publication.sql — Station publishes its 3 local match tables.
-- Master subscribes via station_subscription; master never publishes these,
-- so the flow is strictly station -> master (no loop).
-- =========================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'station_publication') THEN
    CREATE PUBLICATION station_publication FOR TABLE
      match.match_result,
      match.match_squad,
      match.match_event;
  END IF;
END $$;
