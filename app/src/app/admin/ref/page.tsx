// src/app/admin/ref/page.tsx - Quản trị Master (Mảnh dọc tài chính & Danh mục cầu thủ)
import Link from "next/link";
import { getRole, querySafe } from "@/lib/db";
import { STATIONS } from "@/lib/station";
import type { DoanhThuTran, CauThu } from "@/lib/types";
import { saveDoanhThu, addCauThu } from "./actions";

export const dynamic = "force-dynamic";

const VI_TRI: Record<string, string> = {
  ThuMon: "Thủ môn (GK)",
  HauVe: "Hậu vệ (DF)",
  TienVe: "Tiền vệ (MF)",
  TienDao: "Tiền đạo (FW)",
};

export default async function RefAdminPage({
  searchParams,
}: {
  searchParams?: { err?: string; ok?: string };
}) {
  const role = getRole();
  if (role !== "master") {
    return (
      <div className="page-container">
        <div className="topbar">
          <div>
            <h1>Quản Trị Master</h1>
          </div>
        </div>
        <div className="card">
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">lock</span>
            <h3>Trang này chỉ dành cho máy chủ Master</h3>
            <p>Trạm Station không được phép thao tác trên các bảng độc quyền của Master.</p>
            <Link className="btn secondary" href="/" style={{ marginTop: "1rem" }}>
              Về Trang Chủ
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const [dt, ct] = await Promise.all([
    querySafe<DoanhThuTran>(
      `SELECT matran, giave::text AS giave, sokhach FROM tran_dau_doanh_thu ORDER BY matran ASC`
    ),
    querySafe<CauThu>(
      `SELECT macauthu, hoten, vitri FROM cau_thu ORDER BY macauthu ASC`
    ),
  ]);

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Quản Trị Hệ Thống</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">VFF Master</span>
          </div>
          <h1>Bảng Điều Khiển Quản Trị Trung Tâm</h1>
          <div className="sub">
            Quản trị mảnh dọc tài chính TRAN_DAU_DOANH_THU &amp; Danh mục cầu thủ CAU_THU gốc
          </div>
        </div>
      </div>

      {/* Notifications */}
      {searchParams?.err && (
        <div className="alert error">
          <span className="material-symbols-outlined">error</span>
          <span>{searchParams.err}</span>
        </div>
      )}
      {searchParams?.ok && (
        <div className="alert success">
          <span className="material-symbols-outlined">check_circle</span>
          <span>{searchParams.ok}</span>
        </div>
      )}

      {/* 2-Column Administrative Forms */}
      <div className="grid grid-2">
        {/* DOANH THU VÉ FORM & TABLE */}
        <div className="card">
          <div className="card-header-row">
            <div>
              <h3>
                <span className="material-symbols-outlined text-accent">payments</span>
                Mảnh Dọc Doanh Thu Vé &amp; Khán Giả
              </h3>
              <p className="card-sub">{dt?.length ?? 0} trận đã có thông tin tài chính</p>
            </div>
          </div>

          <form action={saveDoanhThu}>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Mã trận đấu (VD: TR01, TR31)</label>
                <input name="matran" required maxLength={10} placeholder="TR31" className="font-mono" />
              </div>
              <div className="form-row">
                <label>Đơn giá vé (₫)</label>
                <input name="giave" type="number" min={0} step={1000} required defaultValue={80000} />
              </div>
            </div>

            <div className="form-row">
              <label>Số lượng khán giả tới sân</label>
              <input name="sokhach" type="number" min={0} required defaultValue={15000} />
            </div>

            <button className="btn" type="submit">
              <span className="material-symbols-outlined">save</span>
              Lưu Doanh Thu (Thêm/Sửa)
            </button>
          </form>

          <div className="scroll" style={{ marginTop: "1rem", maxHeight: "320px" }}>
            <table className="roster-table compact">
              <thead>
                <tr>
                  <th>MÃ TRẬN</th>
                  <th className="number">GIÁ VÉ</th>
                  <th className="number">KHÁN GIẢ</th>
                  <th className="number">DOANH THU (₫)</th>
                </tr>
              </thead>
              <tbody>
                {(dt ?? []).map((r) => {
                  const rev = Number(r.giave) * Number(r.sokhach);
                  return (
                    <tr key={r.matran}>
                      <td className="font-mono bold">#{r.matran}</td>
                      <td className="number font-mono">{Number(r.giave).toLocaleString("vi-VN")} ₫</td>
                      <td className="number font-mono">{Number(r.sokhach).toLocaleString("vi-VN")}</td>
                      <td className="number font-mono emerald bold">{rev.toLocaleString("vi-VN")} ₫</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* CẦU THỦ GỐC FORM & TABLE */}
        <div className="card">
          <div className="card-header-row">
            <div>
              <h3>
                <span className="material-symbols-outlined text-accent">badge</span>
                Danh Mục Cầu Thủ Tra Cứu Toàn Giải
              </h3>
              <p className="card-sub">{ct?.length ?? 0} cầu thủ trong bảng CAU_THU master</p>
            </div>
          </div>

          <form action={addCauThu}>
            <div className="form-grid-2">
              <div className="form-row">
                <label>Mã cầu thủ (≤10 ký tự)</label>
                <input name="macauthu" required maxLength={10} placeholder="CT101" className="font-mono" />
              </div>
              <div className="form-row">
                <label>Vị trí thi đấu</label>
                <select name="vitri" defaultValue="TienDao">
                  <option value="ThuMon">Thủ môn (ThuMon)</option>
                  <option value="HauVe">Hậu vệ (HauVe)</option>
                  <option value="TienVe">Tiền vệ (TienVe)</option>
                  <option value="TienDao">Tiền đạo (TienDao)</option>
                </select>
              </div>
            </div>

            <div className="form-row">
              <label>Họ và tên cầu thủ</label>
              <input name="hoten" required placeholder="VD: Nguyễn Tiến Linh..." />
            </div>

            <button className="btn" type="submit">
              <span className="material-symbols-outlined">person_add</span>
              Thêm Cầu Thủ Vào Danh Mục
            </button>
          </form>

          <div className="scroll" style={{ marginTop: "1rem", maxHeight: "320px" }}>
            <table className="roster-table compact">
              <thead>
                <tr>
                  <th>MÃ</th>
                  <th>HỌ TÊN CẦU THỦ</th>
                  <th>VỊ TRÍ</th>
                </tr>
              </thead>
              <tbody>
                {(ct ?? []).map((c) => (
                  <tr key={c.macauthu}>
                    <td className="font-mono text-muted">#{c.macauthu}</td>
                    <td>
                      <strong>{c.hoten}</strong>
                    </td>
                    <td>
                      <span className="pos-badge-sm">{VI_TRI[c.vitri] ?? c.vitri}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* FDW CONFIGURATION SUMMARY CARD */}
      <div className="card" style={{ marginTop: "1.2rem" }}>
        <div className="card-header-row">
          <div>
            <h3>Cấu Hình Phân Tán postgres_fdw ({STATIONS.length} Trạm Ngoại Lai)</h3>
            <p className="card-sub">
              Liên kết giữa Master và {STATIONS.length} trạm Station qua ZeroTier VPN mesh (Template 20_fdw_setup.sql)
            </p>
          </div>
        </div>

        <div className="table-responsive">
          <table className="roster-table compact">
            <thead>
              <tr>
                <th>TRẠM</th>
                <th>CÂU LẠC BỘ</th>
                <th>DATABASE NGOẠI LAI</th>
                <th>FOREIGN SERVER</th>
                <th>SCHEMA ĐÍCH</th>
                <th>SÂN NHÀ</th>
              </tr>
            </thead>
            <tbody>
              {STATIONS.map((s) => (
                <tr key={s.id}>
                  <td>
                    <span className="step-badge" style={{ width: "22px", height: "22px", fontSize: "0.72rem" }}>
                      S{s.id}
                    </span>
                  </td>
                  <td>
                    <strong>{s.club}</strong>
                  </td>
                  <td className="font-mono text-muted">{s.db}</td>
                  <td className="font-mono text-accent">{s.server}</td>
                  <td className="font-mono">{s.schema}</td>
                  <td>{s.san}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
