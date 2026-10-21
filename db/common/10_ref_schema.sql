-- =========================================================================
-- 10_ref_schema.sql - Master-owned reference tables (schema `ref`)
-- Replicated master → station. Station NEVER publishes these (only match.*),
-- so there is no replication loop.
--
-- Logical replication copies rows but not schema, so these tables are
-- created on every node by this file (run by init-node.sh on both roles).
-- =========================================================================
CREATE SCHEMA IF NOT EXISTS ref;
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- needed for EXCLUDE on registration

-- 1. Station (master owns). Each distributed site is a station.
CREATE TABLE IF NOT EXISTS ref.station (
  station_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       text NOT NULL,
  region     text NOT NULL
);

-- 2. Season
CREATE TABLE IF NOT EXISTS ref.season (
  season_id  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       text NOT NULL,
  start_date date NOT NULL,
  end_date   date NOT NULL,
  CONSTRAINT season_date_chk CHECK (end_date >= start_date)
);

-- 3. Round (8 teams × 2 legs = 14 rounds)
CREATE TABLE IF NOT EXISTS ref.round (
  round_id   int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  season_id  int NOT NULL REFERENCES ref.season(season_id) ON DELETE CASCADE,
  round_no   int NOT NULL,
  start_date date NOT NULL,
  end_date   date NOT NULL,
  CONSTRAINT round_date_chk    CHECK (end_date >= start_date),
  CONSTRAINT round_no_chk      CHECK (round_no >= 1),
  CONSTRAINT round_season_uniq UNIQUE (season_id, round_no)
);

-- 4. Stadium (one stadium belongs to one station)
CREATE TABLE IF NOT EXISTS ref.stadium (
  stadium_id  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  station_id  int NOT NULL REFERENCES ref.station(station_id) ON DELETE RESTRICT,
  name        text NOT NULL,
  capacity    int NOT NULL,
  CONSTRAINT stadium_cap_chk CHECK (capacity > 0)
);

-- 5. Team (home stadium; must have ≥6 even number of teams - app-level check)
CREATE TABLE IF NOT EXISTS ref.team (
  team_id          int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  home_stadium_id  int NOT NULL REFERENCES ref.stadium(stadium_id) ON DELETE RESTRICT,
  name             text NOT NULL,
  founded_year     int NOT NULL,
  CONSTRAINT team_year_chk CHECK (founded_year BETWEEN 1850 AND extract(year from now())::int)
);

-- 6. TeamKit (composite PK; ≥2 colors per team - enforced by trigger)
CREATE TABLE IF NOT EXISTS ref.team_kit (
  team_id  int NOT NULL REFERENCES ref.team(team_id) ON DELETE CASCADE,
  color    text NOT NULL,
  kind     text NOT NULL CHECK (kind IN ('home','away','third','goalkeeper')),
  PRIMARY KEY (team_id, color)
);

-- 7. Player (no team link directly - use Registration)
CREATE TABLE IF NOT EXISTS ref.player (
  player_id   int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name   text NOT NULL,
  birth_date  date NOT NULL,
  nationality text NOT NULL,
  position    text NOT NULL CHECK (position IN ('GK','DF','MF','FW'))
);

-- 8. Referee (need ≥16 to cover one round: 4 matches × 4 roles)
CREATE TABLE IF NOT EXISTS ref.referee (
  referee_id  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name   text NOT NULL,
  birth_date  date NOT NULL,
  level       text NOT NULL CHECK (level IN ('FIFA','elite','national','regional'))
);

-- 9. RolePay (pay-per-match per role - data, not hardcoded)
-- Design: 4 referees per match = 1 main (chính) + 2 linesmen (biên) + 1 table (bàn).
-- Three roles → three pay rates.
CREATE TABLE IF NOT EXISTS ref.role_pay (
  role           text PRIMARY KEY CHECK (role IN ('main','linesman','table')),
  pay_per_match  numeric(12,2) NOT NULL CHECK (pay_per_match >= 0)
);

-- 10. Registration (covers both contract + loan via owner_team_id)
--      "one team at a time" enforced by EXCLUDE on (player_id, period)
CREATE TABLE IF NOT EXISTS ref.registration (
  reg_id          int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  player_id       int NOT NULL REFERENCES ref.player(player_id)        ON DELETE CASCADE,
  team_id         int NOT NULL REFERENCES ref.team(team_id)            ON DELETE RESTRICT,  -- current playing team
  owner_team_id   int NOT NULL REFERENCES ref.team(team_id)            ON DELETE RESTRICT,  -- contract owner (different if on loan)
  shirt_no        int NOT NULL CHECK (shirt_no BETWEEN 1 AND 35),
  period          daterange NOT NULL,
  CONSTRAINT reg_team_shirt_uniq  EXCLUDE USING gist (
    team_id   WITH =,
    shirt_no  WITH =,
    period    WITH &&
  ),  -- shirt_no unique within a team, non-overlapping periods
  CONSTRAINT reg_player_one_team  EXCLUDE USING gist (
    player_id WITH =,
    period    WITH &&
  )  -- a player plays for exactly one team at any time
);

-- 11. Fixture (full season schedule)
CREATE TABLE IF NOT EXISTS ref.fixture (
  fixture_id   int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  round_id     int NOT NULL REFERENCES ref.round(round_id)               ON DELETE CASCADE,
  home_team    int NOT NULL REFERENCES ref.team(team_id)                 ON DELETE RESTRICT,
  away_team    int NOT NULL REFERENCES ref.team(team_id)                 ON DELETE RESTRICT,
  stadium_id   int NOT NULL REFERENCES ref.stadium(stadium_id)          ON DELETE RESTRICT,
  kickoff      timestamptz NOT NULL,
  CONSTRAINT fixture_teams_differ   CHECK (home_team <> away_team)
  -- The constraint kickoff >= round.start_date is checked by a trigger
  -- (ref.fixture_kickoff_in_round) because CHECK cannot use a subquery.
);

-- 12. MatchReferee (exactly 4 per fixture: 1 main, 2 linesmen, 1 table)
--      The 1-2-1 distribution is enforced by trigger match_referee_role_dist.
CREATE TABLE IF NOT EXISTS ref.match_referee (
  fixture_id   int NOT NULL REFERENCES ref.fixture(fixture_id)         ON DELETE CASCADE,
  referee_id   int NOT NULL REFERENCES ref.referee(referee_id)          ON DELETE RESTRICT,
  role         text NOT NULL REFERENCES ref.role_pay(role)              ON DELETE RESTRICT,
  PRIMARY KEY (fixture_id, referee_id)
);
