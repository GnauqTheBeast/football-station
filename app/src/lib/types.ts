// src/lib/types.ts - Database row types matching DDL in db/common/*.
export interface Station {
  station_id: number;
  name: string;
  region: string;
}

export interface Stadium {
  stadium_id: number;
  station_id: number;
  name: string;
  capacity: number;
}

export interface Team {
  team_id: number;
  home_stadium_id: number;
  name: string;
  founded_year: number;
}

export interface Season {
  season_id: number;
  name: string;
  start_date: string;
  end_date: string;
}

export interface Round {
  round_id: number;
  season_id: number;
  round_no: number;
  start_date: string;
  end_date: string;
}

export interface Fixture {
  fixture_id: number;
  round_id: number;
  home_team: number;
  away_team: number;
  stadium_id: number;
  kickoff: string;
  // joined fields from home/away team + stadium (UI convenience)
  home_team_name?: string;
  away_team_name?: string;
  stadium_name?: string;
  round_no?: number;
  season_name?: string;
}

export interface MatchResult {
  station_id: number;
  fixture_id: number;
  played_at: string;
  home_goals: number;
  away_goals: number;
  attendance: number;
  ticket_price: string;
  home_team_name?: string;
  away_team_name?: string;
  stadium_name?: string;
}

export interface MatchEvent {
  station_id: number;
  event_id: number;
  fixture_id: number;
  player_id: number;
  kind: "goal" | "yellow" | "red";
  minute: number;
  player_name?: string;
}

export interface MatchSquadRow {
  station_id: number;
  fixture_id: number;
  player_id: number;
  team_id: number;
  shirt_no: number;
  player_name?: string;
}

export interface Player {
  player_id: number;
  full_name: string;
  birth_date: string;
  nationality: string;
  position: "GK" | "DF" | "MF" | "FW";
}

export interface Standing {
  team_id: number;
  name: string;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  gf: number;
  ga: number;
  gd: number;
  pts: number;
}

export interface TopScorer {
  player_id: number;
  full_name: string;
  team_name: string;
  goals: number;
}

export interface StationInfo {
  station_id: number;
  station_name: string;
  region: string;
  stadium_id: number;
  stadium_name: string;
  capacity: number;
  role: "master" | "station";
}
