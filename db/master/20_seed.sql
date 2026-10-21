-- =========================================================================
-- 20_seed.sql - Sample reference data seeded by master only. Stations
-- receive these rows via master_publication replication.
-- Idempotent where possible (ON CONFLICT DO NOTHING) so re-running init
-- doesn't double-insert.
-- =========================================================================

-- Pay rates per role (VND millions)
INSERT INTO ref.role_pay(role, pay_per_match) VALUES
  ('main',     3000000),
  ('linesman', 2000000),
  ('table',    1000000)
ON CONFLICT (role) DO NOTHING;

-- Two stations (one master is replicate-only, the other physically hosts home
-- matches). Station 1 is your friend's station (172.18.20.9), Station 2 is
-- a placeholder for a second station.
INSERT INTO ref.station(name, region) VALUES
  ('Station 1 - Hanoi', 'North'),
  ('Station 2 - HCMC',  'South')
ON CONFLICT DO NOTHING;

-- One season, 14 rounds (8 teams × 2 legs)
INSERT INTO ref.season(name, start_date, end_date) VALUES
  ('2026 Spring', DATE '2026-02-01', DATE '2026-06-30')
ON CONFLICT DO NOTHING;

INSERT INTO ref.round(season_id, round_no, start_date, end_date)
SELECT s.season_id, g.rn,
       DATE '2026-02-01' + (g.rn - 1) * 7,
       DATE '2026-02-01' + g.rn * 7 - 1
FROM ref.season s
CROSS JOIN generate_series(1, 14) AS g(rn)
WHERE NOT EXISTS (SELECT 1 FROM ref.round r WHERE r.season_id = s.season_id AND r.round_no = g.rn);

-- 4 stadiums for sample scale (design needs ≥6 even teams; for testing -
-- trigger-level "even/≥6 teams" is app-level).
INSERT INTO ref.stadium(station_id, name, capacity) VALUES
  (1, 'My Dinh', 40000),
  (1, 'Hang Day', 20000),
  (1, 'Thong Nhat', 15000),
  (2, 'San van dong Quan 7', 5000)
ON CONFLICT DO NOTHING;

-- 4 teams (each with one home stadium)
INSERT INTO ref.team(home_stadium_id, name, founded_year)
SELECT stadium_id, name || ' FC', 1960
FROM ref.stadium
ON CONFLICT DO NOTHING;

-- Each team has 2 colors
INSERT INTO ref.team_kit(team_id, color, kind)
SELECT t.team_id, c.color, c.kind
FROM ref.team t
CROSS JOIN (VALUES
  ('red',    'home'),
  ('white',  'away')
) AS c(color, kind)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.team_kit k WHERE k.team_id = t.team_id AND k.color = c.color
);

-- Sample players - 4 per team = 16 total
INSERT INTO ref.player(full_name, birth_date, nationality, position)
SELECT 'Player ' || g.id,
       DATE '1995-01-01' + (g.id % 365),
       'Vietnam',
       CASE g.id % 4 WHEN 0 THEN 'GK' WHEN 1 THEN 'DF' WHEN 2 THEN 'MF' ELSE 'FW' END
FROM generate_series(1, 16) AS g(id)
WHERE NOT EXISTS (SELECT 1 FROM ref.player WHERE full_name = 'Player ' || g.id);

-- Sample referees - exactly 16 (enough for one round)
INSERT INTO ref.referee(full_name, birth_date, level)
SELECT 'Referee ' || g.id,
       DATE '1980-01-01' + (g.id % 365),
       CASE g.id % 4 WHEN 0 THEN 'FIFA' WHEN 1 THEN 'elite' WHEN 2 THEN 'national' ELSE 'regional' END
FROM generate_series(1, 16) AS g(id)
WHERE NOT EXISTS (SELECT 1 FROM ref.referee WHERE full_name = 'Referee ' || g.id);

-- 4 sample fixtures in round 1 (2 home/away pairs)
-- Insert them using team_ids 1..4 - adjust to your actual teams.
INSERT INTO ref.fixture(round_id, home_team, away_team, stadium_id, kickoff)
SELECT r.round_id, ht.team_id, at.team_id, ht.home_stadium_id,
       timestamptz '2026-02-01 19:00:00+07' + (g.idx * interval '1 day')
FROM ref.round r, ref.team ht, ref.team at,
     (VALUES (0, 1, 2), (1, 3, 4)) AS g(idx, hid, aid)
WHERE r.round_no = 1
  AND ht.team_id = g.hid
  AND at.team_id = g.aid
  AND ht.team_id <> at.team_id
  AND NOT EXISTS (SELECT 1 FROM ref.fixture f WHERE f.round_id = r.round_id AND f.home_team = ht.team_id AND f.away_team = at.team_id);

-- Assign 4 referees per sample fixture (1 main, 2 linesmen, 1 table)
-- Uses referee_ids 1..16 round-robin.
INSERT INTO ref.match_referee(fixture_id, referee_id, role)
SELECT f.fixture_id, ref_id, role
FROM ref.fixture f
CROSS JOIN LATERAL (
  SELECT
    (1 + (f.fixture_id * 4 + 0) % 16) AS ref_id, 'main'     AS role
  UNION ALL SELECT
    (1 + (f.fixture_id * 4 + 1) % 16), 'linesman'
  UNION ALL SELECT
    (1 + (f.fixture_id * 4 + 2) % 16), 'linesman'
  UNION ALL SELECT
    (1 + (f.fixture_id * 4 + 3) % 16), 'table'
) AS a
WHERE NOT EXISTS (
  SELECT 1 FROM ref.match_referee mr WHERE mr.fixture_id = f.fixture_id AND mr.referee_id = a.ref_id
);
