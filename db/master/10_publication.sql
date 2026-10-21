-- =========================================================================
-- 10_publication.sql — Master publishes all 12 reference tables.
-- Stations subscribe via master_subscription; stations never publish these,
-- so the flow is strictly master -> station (no loop).
-- =========================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'master_publication') THEN
    CREATE PUBLICATION master_publication FOR TABLE
      ref.station,
      ref.season,
      ref.round,
      ref.stadium,
      ref.team,
      ref.team_kit,
      ref.player,
      ref.referee,
      ref.role_pay,
      ref.registration,
      ref.fixture,
      ref.match_referee;
  END IF;
END $$;
