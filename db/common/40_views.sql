-- =========================================================================
-- 40_views.sql - Aggregate views (master-side reads). Computed from
-- replicated match data, so they live on the master by default. Defining
-- them on every node is harmless (on stations these views see only local
-- rows; on master they see rows from all 6 stations).
-- =========================================================================

-- Standings: P / W / D / L / GF / GA / GD / Pts (home + away aggregated).
-- standings is built from MatchResult joined to ref.fixture for team ids.
CREATE OR REPLACE VIEW ref.v_standings AS
WITH sides AS (
  SELECT mr.station_id, mr.fixture_id, f.home_team AS team_id, mr.home_goals AS gf, mr.away_goals AS ga
  FROM match.match_result mr
  JOIN ref.fixture f ON f.fixture_id = mr.fixture_id
  UNION ALL
  SELECT mr.station_id, mr.fixture_id, f.away_team AS team_id, mr.away_goals AS gf, mr.home_goals AS ga
  FROM match.match_result mr
  JOIN ref.fixture f ON f.fixture_id = mr.fixture_id
)
SELECT
  t.team_id,
  t.name,
  count(*)                                              AS played,
  count(*) FILTER (WHERE gf > ga)                       AS won,
  count(*) FILTER (WHERE gf = ga)                       AS drawn,
  count(*) FILTER (WHERE gf < ga)                       AS lost,
  sum(gf)::int                                          AS gf,
  sum(ga)::int                                          AS ga,
  (sum(gf) - sum(ga))::int                              AS gd,
  (3 * count(*) FILTER (WHERE gf > ga) + count(*) FILTER (WHERE gf = ga))::int AS pts
FROM sides s
JOIN ref.team t ON t.team_id = s.team_id
GROUP BY t.team_id, t.name
ORDER BY pts DESC, gd DESC, gf DESC;

-- Top 10 scorers across all stations.
CREATE OR REPLACE VIEW ref.v_top_scorers AS
SELECT
  p.player_id,
  p.full_name,
  t.name AS team_name,
  count(*) AS goals
FROM match.match_event e
JOIN ref.player p ON p.player_id = e.player_id
JOIN match.match_squad s ON s.station_id = e.station_id AND s.fixture_id = e.fixture_id AND s.player_id = e.player_id
JOIN ref.team   t ON t.team_id = s.team_id
WHERE e.kind = 'goal'
GROUP BY p.player_id, p.full_name, t.name
ORDER BY goals DESC
LIMIT 10;

-- Referee pay per season: matches worked × role pay.
CREATE OR REPLACE VIEW ref.v_referee_pay AS
SELECT
  r.referee_id,
  rf.full_name,
  s.name AS season_name,
  rp.role,
  rp.pay_per_match,
  count(*) AS matches_worked,
  (rp.pay_per_match * count(*))::numeric(12,2) AS total_pay
FROM ref.match_referee r
JOIN ref.fixture    f  ON f.fixture_id = r.fixture_id
JOIN ref.round      ro ON ro.round_id = f.round_id
JOIN ref.season     s  ON s.season_id = ro.season_id
JOIN ref.referee    rf ON rf.referee_id = r.referee_id
JOIN ref.role_pay   rp ON rp.role = r.role
GROUP BY r.referee_id, rf.full_name, s.name, rp.role, rp.pay_per_match
ORDER BY total_pay DESC;

-- Stadium revenue per season: attendance × ticket_price.
CREATE OR REPLACE VIEW ref.v_stadium_revenue AS
SELECT
  std.stadium_id,
  std.name AS stadium_name,
  s.name   AS season_name,
  count(*) AS matches_hosted,
  sum(mr.attendance)::int AS total_attendance,
  (sum(mr.attendance * mr.ticket_price))::numeric(14,2) AS total_revenue
FROM match.match_result mr
JOIN ref.fixture f  ON f.fixture_id = mr.fixture_id
JOIN ref.stadium std ON std.stadium_id = f.stadium_id
JOIN ref.round   ro ON ro.round_id = f.round_id
JOIN ref.season  s  ON s.season_id = ro.season_id
GROUP BY std.stadium_id, std.name, s.name
ORDER BY total_revenue DESC;

-- Per-round stats: goals and cards.
CREATE OR REPLACE VIEW ref.v_round_stats AS
SELECT
  s.name AS season_name,
  ro.round_no,
  count(DISTINCT mr.fixture_id) AS matches_played,
  sum(mr.home_goals + mr.away_goals)::int AS goals,
  count(*) FILTER (WHERE e.kind = 'yellow') AS yellow_cards,
  count(*) FILTER (WHERE e.kind = 'red')    AS red_cards
FROM ref.season s
JOIN ref.round     ro ON ro.season_id = s.season_id
JOIN ref.fixture   f  ON f.round_id = ro.round_id
JOIN match.match_result mr ON mr.fixture_id = f.fixture_id
LEFT JOIN match.match_event e ON e.station_id = mr.station_id AND e.fixture_id = mr.fixture_id
GROUP BY s.name, ro.round_no
ORDER BY s.name, ro.round_no;
