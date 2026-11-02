"use server";

import { query, getRole, getStationId } from "@/lib/db";
import { STATIONS } from "@/lib/station";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

function requireStation() {
  if (getRole() !== "station") throw new Error("Chỉ app station mới được nhập.");
  const id = getStationId();
  const meta = STATIONS.find((s) => s.id === id);
  if (!meta) throw new Error("STATION_ID chưa đúng (chỉ 1, 2, 4, 5, 6).");
  return meta;
}

// Tạo lịch: MaDoiNha khóa cứng = CLB của station.
export async function createMatch(formData: FormData) {
  const meta = requireStation();
  const matran = String(formData.get("matran") ?? "").trim().toUpperCase();
  const mavong = Number(formData.get("mavong"));
  const madoikhach = String(formData.get("madoikhach") ?? "").trim().toUpperCase();
  const ngaygio = String(formData.get("ngaygio") ?? "").trim();
  if (!matran || matran.length > 10) throw new Error("Mã trận tối đa 10 ký tự (vd T1X8K2P4Q9).");
  if (!Number.isInteger(mavong) || mavong < 1 || mavong > 10) throw new Error("Vòng phải 1-10.");
  if (!madoikhach || madoikhach === meta.club) throw new Error("Đội khách khác đội nhà.");
  if (!ngaygio) throw new Error("Chưa chọn ngày giờ.");
  await query(
    `INSERT INTO tran_dau_chuyen_mon
     (matran, mavong, madoinha, madoikhach, masan, ngaygio, trangthai)
     VALUES ($1,$2,$3,$4,$5,$6,'ChuaDienRa')`,
    [matran, mavong, meta.club, madoikhach, meta.san, ngaygio.replace("T", " ") + ":00"]
  );
  revalidatePath("/admin/new-match-result");
  redirect(`/admin/new-match-result?m=${matran}`);
}

// Thêm sự kiện: chỉ khi trận ChuaDienRa.
export async function addEvent(formData: FormData) {
  requireStation();
  const matran = String(formData.get("matran") ?? "").trim().toUpperCase();
  const macauthu = String(formData.get("macauthu") ?? "").trim().toUpperCase();
  const loai = String(formData.get("loai") ?? "");
  const phut = Number(formData.get("phut"));
  const ma = `S${Date.now().toString().slice(-9)}`.slice(0, 10);
  if (!["BanThang", "PhanLuoi", "TheVang", "TheDo"].includes(loai)) throw new Error("Loại sự kiện sai.");
  if (!Number.isInteger(phut) || phut < 1 || phut > 120) throw new Error("Phút phải 1-120.");
  if (!macauthu) throw new Error("Chưa nhập mã cầu thủ.");
  const st = await query<{ trangthai: string }>(`SELECT trangthai FROM tran_dau_chuyen_mon WHERE matran = $1`, [matran]);
  if (st.length === 0) throw new Error("Không tìm thấy trận.");
  if (st[0].trangthai === "DaKetThuc") throw new Error("Trận đã kết thúc - bị khóa, không thêm sự kiện.");
  await query(
    `INSERT INTO su_kien_tran_dau (masukien, matran, macauthu, loaisukien, phutghinhan)
     VALUES ($1,$2,$3,$4,$5)`,
    [ma, matran, macauthu, loai, phut]
  );
  revalidatePath("/admin/new-match-result");
}

export async function deleteEvent(formData: FormData) {
  requireStation();
  const ma = String(formData.get("masukien") ?? "");
  await query(`DELETE FROM su_kien_tran_dau WHERE masukien = $1`, [ma]);
  revalidatePath("/admin/new-match-result");
}

// Chốt trận: đối soát tổng bàn/thẻ với sự kiện, cấm chốt tương lai.
export async function finalizeMatch(formData: FormData) {
  requireStation();
  const matran = String(formData.get("matran") ?? "").trim().toUpperCase();
  const bn = Number(formData.get("banthangnha"));
  const bk = Number(formData.get("banthangkhach"));
  const tvn = Number(formData.get("thevangnha"));
  const tvk = Number(formData.get("thevangkhach"));
  const tdn = Number(formData.get("thedonha"));
  const tdk = Number(formData.get("thedokhach"));
  for (const v of [bn, bk, tvn, tvk, tdn, tdk]) {
    if (!Number.isInteger(v) || v < 0) throw new Error("Tỉ số/thẻ phải là số nguyên ≥ 0.");
  }
  const m = await query<{ ngaygio: string; trangthai: string }>(
    `SELECT ngaygio::text AS ngaygio, trangthai FROM tran_dau_chuyen_mon WHERE matran = $1`, [matran]);
  if (m.length === 0) throw new Error("Không tìm thấy trận.");
  if (m[0].trangthai === "DaKetThuc") throw new Error("Trận đã kết thúc rồi.");
  if (new Date(m[0].ngaygio) > new Date()) throw new Error("Không chốt trận có giờ đá trong tương lai.");
  const ev = await query<{ loai: string; c: string }>(
    `SELECT loaisukien AS loai, COUNT(*)::text AS c FROM su_kien_tran_dau WHERE matran = $1 GROUP BY loaisukien`, [matran]);
  const count = (l: string) => Number(ev.find((e) => e.loai === l)?.c ?? 0);
  const goals = count("BanThang") + count("PhanLuoi");
  if (goals !== bn + bk) throw new Error(`Bàn thắng sự kiện (${goals}) không khớp tỉ số ${bn}-${bk}.`);
  if (count("TheVang") !== tvn + tvk) throw new Error("Tổng thẻ vàng sự kiện không khớp.");
  if (count("TheDo") !== tdn + tdk) throw new Error("Tổng thẻ đỏ sự kiện không khớp.");
  await query(
    `UPDATE tran_dau_chuyen_mon SET banthangnha=$2, banthangkhach=$3, thevangnha=$4,
     thevangkhach=$5, thedonha=$6, thedokhach=$7, trangthai='DaKetThuc' WHERE matran=$1`,
    [matran, bn, bk, tvn, tvk, tdn, tdk]
  );
  revalidatePath("/admin/new-match-result");
  revalidatePath(`/fixtures/${matran}`);
}
