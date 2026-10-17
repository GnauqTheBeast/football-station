-- Master databases publish the shared `ref` schema (teams, fixtures, ...)
-- to every station. Stations subscribe (see scripts/subscribe-master.sh);
-- stations never publish ref.* themselves, so changes are one-way
-- master -> station and cannot loop back.
CREATE PUBLICATION master_publication FOR TABLE ref.team, ref.match;
