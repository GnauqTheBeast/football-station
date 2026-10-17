CREATE SCHEMA IF NOT EXISTS demo;
CREATE TABLE IF NOT EXISTS demo.message (
  station_id int NOT NULL,
  local_id bigint GENERATED ALWAYS AS IDENTITY,
  author text NOT NULL,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (station_id, local_id)
);
