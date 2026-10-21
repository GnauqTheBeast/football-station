-- =========================================================================
-- 30_triggers.sql - Complex constraints not expressible as CHECK/FK.
--
-- All triggers are default (ENABLE ORIGIN) - they fire only on the node
-- where the app writes, not on the subscriber (logical replication runs
-- with session_replication_role = 'replica', so origin triggers are
-- skipped during apply). This is correct: validate at the origin once.
-- =========================================================================

-- -------------------------------------------------------------------------
-- A. TeamKit: each team must have at least 2 distinct colors.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ref.team_kit_min_two_colors() RETURNS trigger AS $$
DECLARE
  n int;
BEGIN
  SELECT count(DISTINCT color) INTO n FROM ref.team_kit WHERE team_id = NEW.team_id;
  IF n < 2 THEN
    RAISE EXCEPTION 'Team % must have at least 2 colors (found %)', NEW.team_id, n;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS team_kit_min_two_colors ON ref.team_kit;
CREATE TRIGGER team_kit_min_two_colors
  AFTER INSERT OR UPDATE ON ref.team_kit
  FOR EACH ROW EXECUTE FUNCTION ref.team_kit_min_two_colors();

-- -------------------------------------------------------------------------
-- B. MatchReferee: exactly 4 - 1 main + 2 linesmen + 1 table per fixture.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ref.match_referee_role_dist() RETURNS trigger AS $$
DECLARE
  cnt_main int; cnt_lines int; cnt_table int;
BEGIN
  SELECT
    count(*) FILTER (WHERE role = 'main'),
    count(*) FILTER (WHERE role = 'linesman'),
    count(*) FILTER (WHERE role = 'table')
  INTO cnt_main, cnt_lines, cnt_table
  FROM ref.match_referee
  WHERE fixture_id = COALESCE(NEW.fixture_id, OLD.fixture_id);

  IF cnt_main > 1 THEN RAISE EXCEPTION 'Fixture %: at most 1 main referee', COALESCE(NEW.fixture_id, OLD.fixture_id); END IF;
  IF cnt_lines > 2 THEN RAISE EXCEPTION 'Fixture %: at most 2 linesmen', COALESCE(NEW.fixture_id, OLD.fixture_id); END IF;
  IF cnt_table > 1 THEN RAISE EXCEPTION 'Fixture %: at most 1 table referee', COALESCE(NEW.fixture_id, OLD.fixture_id); END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS match_referee_role_dist ON ref.match_referee;
CREATE TRIGGER match_referee_role_dist
  AFTER INSERT OR UPDATE OR DELETE ON ref.match_referee
  FOR EACH ROW EXECUTE FUNCTION ref.match_referee_role_dist();

-- -------------------------------------------------------------------------
-- B2. Fixture: kickoff must fall within its round's date range.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ref.fixture_kickoff_in_round() RETURNS trigger AS $$
DECLARE
  r_start date; r_end date;
BEGIN
  SELECT start_date, end_date INTO r_start, r_end
  FROM ref.round WHERE round_id = NEW.round_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fixture: round_id % does not exist', NEW.round_id;
  END IF;
  IF NEW.kickoff::date < r_start OR NEW.kickoff::date > r_end THEN
    RAISE EXCEPTION 'Fixture %: kickoff % not within round % (% to %)',
      NEW.fixture_id, NEW.kickoff::date, NEW.round_id, r_start, r_end;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS fixture_kickoff_in_round ON ref.fixture;
CREATE TRIGGER fixture_kickoff_in_round
  BEFORE INSERT OR UPDATE OF kickoff, round_id ON ref.fixture
  FOR EACH ROW EXECUTE FUNCTION ref.fixture_kickoff_in_round();

-- -------------------------------------------------------------------------
-- C. MatchResult: played_at must not be in the future.
-- (CHECK cannot use now() reliably across revalidations on UPDATE.)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION match.match_result_played_at_past() RETURNS trigger AS $$
BEGIN
  IF NEW.played_at > now() THEN
    RAISE EXCEPTION 'MatchResult (%/fixture %): played_at cannot be in the future', NEW.station_id, NEW.fixture_id;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS match_result_played_at_past ON match.match_result;
CREATE TRIGGER match_result_played_at_past
  BEFORE INSERT OR UPDATE OF played_at ON match.match_result
  FOR EACH ROW EXECUTE FUNCTION match.match_result_played_at_past();

-- -------------------------------------------------------------------------
-- D. MatchSquad: at most 18 players per team per match.
-- Also: the player must be registered for the team on the kickoff date.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION match.match_squad_checks() RETURNS trigger AS $$
DECLARE
  cnt       int;
  kickoff   timestamptz;
  reg_found boolean;
BEGIN
  SELECT count(*) INTO cnt
  FROM match.match_squad
  WHERE station_id = NEW.station_id AND fixture_id = NEW.fixture_id AND team_id = NEW.team_id;

  IF cnt > 18 THEN
    RAISE EXCEPTION 'MatchSquad (station %/fixture %/team %): at most 18 players', NEW.station_id, NEW.fixture_id, NEW.team_id;
  END IF;

  -- Must correspond to a real MatchResult row.
  IF NOT EXISTS (SELECT 1 FROM match.match_result WHERE station_id = NEW.station_id AND fixture_id = NEW.fixture_id) THEN
    RAISE EXCEPTION 'MatchSquad (station %/fixture %): no MatchResult exists yet', NEW.station_id, NEW.fixture_id;
  END IF;

  -- Player must currently be registered for that team as of kickoff.
  SELECT f.kickoff INTO kickoff FROM ref.fixture f WHERE f.fixture_id = NEW.fixture_id;

  SELECT EXISTS (
    SELECT 1 FROM ref.registration r
    WHERE r.player_id = NEW.player_id
      AND r.team_id   = NEW.team_id
      AND NEW.player_id IS NOT NULL
      AND kickoff::date <@ r.period
  ) INTO reg_found;

  IF NOT reg_found THEN
    RAISE EXCEPTION 'MatchSquad (station %/fixture %/player %): player not registered for team % on kickoff %',
      NEW.station_id, NEW.fixture_id, NEW.player_id, NEW.team_id, kickoff;
  END IF;

  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS match_squad_checks ON match.match_squad;
CREATE TRIGGER match_squad_checks
  BEFORE INSERT OR UPDATE ON match.match_squad
  FOR EACH ROW EXECUTE FUNCTION match.match_squad_checks();

-- -------------------------------------------------------------------------
-- E. MatchEvent: player must be in the squad of that match.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION match.match_event_player_in_squad() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM match.match_squad
    WHERE station_id = NEW.station_id
      AND fixture_id = NEW.fixture_id
      AND player_id  = NEW.player_id
  ) THEN
    RAISE EXCEPTION 'MatchEvent (station %/fixture %/player %): player not in match squad',
      NEW.station_id, NEW.fixture_id, NEW.player_id;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS match_event_player_in_squad ON match.match_event;
CREATE TRIGGER match_event_player_in_squad
  BEFORE INSERT OR UPDATE OF player_id, fixture_id ON match.match_event
  FOR EACH ROW EXECUTE FUNCTION match.match_event_player_in_squad();

-- -------------------------------------------------------------------------
-- F. MatchEvent goal count must not exceed MatchResult home_goals+away_goals.
-- (Allows under-count for partial match; forbids over-count. Exact match
-- is validated at match-completion by the app calling verify_match().)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION match.match_event_goal_count_bounds() RETURNS trigger AS $$
DECLARE
  goals_in_result int;
  goals_in_events int;
  fid             int;
  sid             int;
BEGIN
  sid := COALESCE(NEW.station_id, OLD.station_id);
  fid := COALESCE(NEW.fixture_id, OLD.fixture_id);

  SELECT COALESCE(home_goals,0) + COALESCE(away_goals,0) INTO goals_in_result
  FROM match.match_result WHERE station_id = sid AND fixture_id = fid;

  -- If no result row yet, allow events (result inserted later).
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT count(*) INTO goals_in_events
  FROM match.match_event
  WHERE station_id = sid AND fixture_id = fid AND kind = 'goal';

  IF goals_in_events > goals_in_result THEN
    RAISE EXCEPTION 'MatchEvent (station %/fixture %): goal events (%) exceed MatchResult total goals (%)',
      sid, fid, goals_in_events, goals_in_result;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS match_event_goal_count_bounds ON match.match_event;
CREATE TRIGGER match_event_goal_count_bounds
  AFTER INSERT OR UPDATE OR DELETE ON match.match_event
  FOR EACH ROW EXECUTE FUNCTION match.match_event_goal_count_bounds();

-- Symmetric guard: when MatchResult goals are lowered below event count.
CREATE OR REPLACE FUNCTION match.match_result_goals_ge_events() RETURNS trigger AS $$
DECLARE
  goals_in_events int;
BEGIN
  SELECT count(*) INTO goals_in_events
  FROM match.match_event
  WHERE station_id = NEW.station_id AND fixture_id = NEW.fixture_id AND kind = 'goal';

  IF (NEW.home_goals + NEW.away_goals) < goals_in_events THEN
    RAISE EXCEPTION 'MatchResult (station %/fixture %): total goals (%) less than recorded goal events (%)',
      NEW.station_id, NEW.fixture_id, NEW.home_goals + NEW.away_goals, goals_in_events;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS match_result_goals_ge_events ON match.match_result;
CREATE TRIGGER match_result_goals_ge_events
  AFTER INSERT OR UPDATE OF home_goals, away_goals ON match.match_result
  FOR EACH ROW EXECUTE FUNCTION match.match_result_goals_ge_events();

-- -------------------------------------------------------------------------
-- G. Verify helper: app calls at match completion to enforce exact goals.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION match.verify_match_complete(p_station int, p_fixture int)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  goals_result int; goals_events int;
  yellow_in_events int; red_in_events int;
  -- team-level breakdown not enforced (team_id not in match_event by design)
BEGIN
  SELECT home_goals + away_goals INTO goals_result
  FROM match.match_result WHERE station_id = p_station AND fixture_id = p_fixture;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'verify_match_complete: no MatchResult for station %/fixture %', p_station, p_fixture;
  END IF;

  SELECT count(*) INTO goals_events
  FROM match.match_event
  WHERE station_id = p_station AND fixture_id = p_fixture AND kind = 'goal';

  IF goals_events <> goals_result THEN
    RAISE EXCEPTION 'verify_match_complete: goal events (%) != MatchResult total goals (%)', goals_events, goals_result;
  END IF;

  RETURN true;
END $$;

-- -------------------------------------------------------------------------
-- H. Registration: max 30 concurrent players per team.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ref.reg_max_30_per_team() RETURNS trigger AS $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM ref.registration
  WHERE team_id = NEW.team_id
    AND NEW.period && period;
  IF n > 30 THEN
    RAISE EXCEPTION 'Team % already has 30 registered players in period % - new limit reached',
      NEW.team_id, NEW.period;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reg_max_30_per_team ON ref.registration;
CREATE TRIGGER reg_max_30_per_team
  BEFORE INSERT OR UPDATE OF team_id, period ON ref.registration
  FOR EACH ROW EXECUTE FUNCTION ref.reg_max_30_per_team();
