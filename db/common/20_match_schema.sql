-- =========================================================================
-- 20_match_schema.sql — Station-owned match data (schema `match`)
-- Replicated station → master (sharded by station_id of the home stadium).
--
-- Composite key (station_id, fixture_id, ...) ties all rows of a single
-- match to one station, so 6 stations' data merges on the master without
-- key collision. These are published ONLY by stations (see
-- db/station/10_publication.sql); the master never publishes them.
-- =========================================================================
CREATE SCHEMA IF NOT EXISTS match;

-- 13. MatchResult (only exists when the match has been played)
CREATE TABLE IF NOT EXISTS match.match_result (
  station_id    int NOT NULL,
  fixture_id    int NOT NULL,
  played_at     timestamptz NOT NULL,
  home_goals    int NOT NULL CHECK (home_goals >= 0),
  away_goals    int NOT NULL CHECK (away_goals >= 0),
  attendance    int NOT NULL CHECK (attendance >= 0),
  ticket_price  numeric(12,2) NOT NULL CHECK (ticket_price >= 0),
  PRIMARY KEY (station_id, fixture_id),
  CONSTRAINT mr_station_fk   FOREIGN KEY (station_id) REFERENCES ref.station(station_id) ON DELETE RESTRICT,
  CONSTRAINT mr_fixture_fk   FOREIGN KEY (fixture_id) REFERENCES ref.fixture(fixture_id) ON DELETE CASCADE
);

-- 14. MatchSquad (up to 18 players per team per match — enforced by trigger)
CREATE TABLE IF NOT EXISTS match.match_squad (
  station_id    int NOT NULL,
  fixture_id    int NOT NULL,
  player_id     int NOT NULL,
  team_id       int NOT NULL,
  shirt_no      int NOT NULL CHECK (shirt_no BETWEEN 1 AND 35),
  PRIMARY KEY (station_id, fixture_id, player_id),
  CONSTRAINT ms_result_fk   FOREIGN KEY (station_id, fixture_id)
                             REFERENCES match.match_result(station_id, fixture_id) ON DELETE CASCADE,
  CONSTRAINT ms_player_fk   FOREIGN KEY (player_id)    REFERENCES ref.player(player_id) ON DELETE RESTRICT,
  CONSTRAINT ms_team_fk     FOREIGN KEY (team_id)      REFERENCES ref.team(team_id)     ON DELETE RESTRICT
);

-- 15. MatchEvent (goals, yellow, red)
CREATE TABLE IF NOT EXISTS match.match_event (
  station_id    int NOT NULL,
  event_id      bigint GENERATED ALWAYS AS IDENTITY,
  fixture_id    int NOT NULL,
  player_id     int NOT NULL,
  kind          text NOT NULL CHECK (kind IN ('goal','yellow','red')),
  minute        int NOT NULL CHECK (minute BETWEEN 0 AND 130),
  PRIMARY KEY (station_id, event_id),
  CONSTRAINT me_player_fk FOREIGN KEY (player_id)    REFERENCES ref.player(player_id) ON DELETE RESTRICT,
  -- No FK to match_squad/match_result directly because event insertion may
  -- happen in any order relative to squad/result. Membership and totals
  -- are enforced by triggers match_event_player_in_squad and
  -- match_event_goal_count_matches_result.
  CONSTRAINT me_station_fixture_chk CHECK (station_id IS NOT NULL AND fixture_id IS NOT NULL)
);
