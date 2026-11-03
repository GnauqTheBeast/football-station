// src/lib/types.ts - Row types khớp schema FDW thật (vleague_master / station local).
// Master đọc vw_global_*, station đọc TRAN_DAU_CHUYEN_MON / SU_KIEN_TRAN_DAU local.

export interface GlobalMatch {
  matran: string;
  mavong: number;
  madoinha: string;
  madoikhach: string;
  masan: string;
  ngaygio: string;
  giave: string | null;
  sokhach: number | null;
  banthangnha: number;
  banthangkhach: number;
  thevangnha: number;
  thevangkhach: number;
  thedonha: number;
  thedokhach: number;
  trangthai: string;
}

export interface GlobalEvent {
  masukien: string;
  matran: string;
  macauthu: string;
  loaisukien: string;
  phutghinhan: number;
  hoten?: string;
  vitri?: string;
}

export interface StandingRow {
  vitri: number;
  madoi: string;
  sotrandadau: number;
  sotranthang: number;
  sotranhoa: number;
  sotranthua: number;
  tongbanthang: number;
  tongbanthua: number;
  hieuso: number;
  diemso: number;
  sotranthangsankhach: number;
  tongthedo: number;
  tongthevang: number;
}

export interface TopScorerRow {
  xephang: number;
  macauthu: string;
  hoten: string;
  sobanthang: number;
}

export interface DoanhThuSan {
  masan: string;
  sotran: number;
  tongkhach: number;
  tongtien: string;
}

export interface CauThu {
  macauthu: string;
  hoten: string;
  vitri: string;
}

export interface DoanhThuTran {
  matran: string;
  giave: string;
  sokhach: number;
}

export interface StationMeta {
  id: number;
  club: string;
  db: string;
  schema: string;
  server: string;
  san: string;
}

export interface StationHealth extends StationMeta {
  imported: boolean;
  tranCount: number | null;
}

export interface StationInfo {
  station_id: number;
  station_name: string;
  club: string;
  role: "master" | "station";
}
