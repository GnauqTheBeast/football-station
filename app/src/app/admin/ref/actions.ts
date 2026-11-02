"use server";

import { query, getRole } from "@/lib/db";
import { revalidatePath } from "next/cache";

function requireMaster() {
  if (getRole() !== "master") throw new Error("Chỉ role=master mới được sửa.");
}

export async function saveDoanhThu(formData: FormData) {
  requireMaster();
  const matran = String(formData.get("matran") ?? "").trim().toUpperCase();
  const giave = Number(formData.get("giave"));
  const sokhach = Number(formData.get("sokhach"));
  if (!matran || !Number.isFinite(giave) || !Number.isFinite(sokhach) || giave < 0 || sokhach < 0) {
    throw new Error("Mã trận / giá vé / số khách không hợp lệ.");
  }
  await query(
    `INSERT INTO tran_dau_doanh_thu (matran, giave, sokhach) VALUES ($1, $2, $3)
     ON CONFLICT (matran) DO UPDATE SET giave = EXCLUDED.giave, sokhach = EXCLUDED.sokhach`,
    [matran, giave, sokhach]
  );
  revalidatePath("/admin/ref");
  revalidatePath("/revenue");
}

export async function addCauThu(formData: FormData) {
  requireMaster();
  const macauthu = String(formData.get("macauthu") ?? "").trim().toUpperCase();
  const hoten = String(formData.get("hoten") ?? "").trim();
  const vitri = String(formData.get("vitri") ?? "TienDao").trim();
  if (!macauthu || !hoten || macauthu.length > 10) throw new Error("Mã/tên cầu thủ không hợp lệ.");
  if (!["ThuMon", "HauVe", "TienVe", "TienDao"].includes(vitri)) throw new Error("Vị trí sai.");
  await query(`INSERT INTO cau_thu (macauthu, hoten, vitri) VALUES ($1, $2, $3)`, [macauthu, hoten, vitri]);
  revalidatePath("/admin/ref");
}
