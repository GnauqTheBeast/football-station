// src/app/revenue/page.tsx - Thống Kê Doanh Thu Sân & Vé (Mảnh dọc Master)
// Số liệu: TRAN_DAU_DOANH_THU JOIN lịch FDW. Tên sân: query SAN_VAN_DONG nếu có,
// chưa có dữ liệu thì hiện mã sân trung thực (không bịa sức chứa).
import { querySafe, getRole } from "@/lib/db";
import type { DoanhThuSan } from "@/lib/types";

export const dynamic = "force-dynamic";

interface SanRow {
  masan: string;
  tensan: string;
}

export default async function RevenuePage() {
  const role = getRole();
  const [rows, sanRows] =
    role === "master"
      ? await Promise.all([
          querySafe<DoanhThuSan>(
            `SELECT masan,
                    COUNT(*)::int AS sotran,
                    COALESCE(SUM(sokhach),0)::int AS tongkhach,
                    COALESCE(SUM(sokhach * giave),0)::text AS tongtien
             FROM vw_global_tran_dau WHERE trangthai = 'DaKetThuc'
             GROUP BY masan ORDER BY SUM(sokhach * giave) DESC NULLS LAST`
          ),
          querySafe<SanRow>(`SELECT masan, tensan FROM san_van_dong`),
        ])
      : [null, null];

  const sanMap = new Map((sanRows ?? []).map((s) => [s.masan, s.tensan]));

  const totalRev = rows?.reduce((s, r) => s + Number(r.tongtien), 0) ?? 0;
  const totalGuests = rows?.reduce((s, r) => s + Number(r.tongkhach), 0) ?? 0;
  const maxRev = rows && rows.length > 0 ? Number(rows[0].tongtien) || 1 : 1;
  const avgTicketPrice = totalGuests > 0 ? Math.round(totalRev / totalGuests) : 0;

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Hệ thống V-League 1</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">Doanh thu sân &amp; Vé</span>
          </div>
          <h1>Báo Cáo Doanh Thu Bán Vé &amp; Khán Giả</h1>
          <div className="sub">
            Mảnh dọc tài chính TRAN_DAU_DOANH_THU lưu độc quyền tại Master • JOIN với lịch thi đấu FDW
          </div>
        </div>
      </div>

      {/* KPI Broadcast Cards */}
      <div className="kpis">
        <div className="kpi">
          <div className="kpi-icon-wrap emerald">
            <span className="material-symbols-outlined">payments</span>
          </div>
          <div className="label">Tổng doanh thu vé</div>
          <div className="value emerald">{(totalRev / 1000000000).toFixed(2)} tỷ ₫</div>
          <div className="kpi-sub">{totalRev.toLocaleString("vi-VN")} ₫ toàn giải</div>
        </div>

        <div className="kpi">
          <div className="kpi-icon-wrap cyan">
            <span className="material-symbols-outlined">confirmation_number</span>
          </div>
          <div className="label">Tổng vé phát hành</div>
          <div className="value">{totalGuests.toLocaleString("vi-VN")}</div>
          <div className="kpi-sub">Khán giả tới sân trực tiếp</div>
        </div>

        <div className="kpi">
          <div className="kpi-icon-wrap purple">
            <span className="material-symbols-outlined">price_change</span>
          </div>
          <div className="label">Giá vé trung bình</div>
          <div className="value purple">{avgTicketPrice.toLocaleString("vi-VN")} ₫</div>
          <div className="kpi-sub">Định mức dao động 50k - 100k</div>
        </div>

        <div className="kpi">
          <div className="kpi-icon-wrap blue">
            <span className="material-symbols-outlined">stadium</span>
          </div>
          <div className="label">Sân đấu có doanh thu</div>
          <div className="value">{rows ? rows.length : "-"}</div>
          <div className="kpi-sub">Các sân đã tổ chức trận đấu</div>
        </div>
      </div>

      {/* Stadium Revenue Comparison Table */}
      <div className="card">
        <div className="card-header-row">
          <div>
            <h3>Bảng Thống Kê Doanh Thu Từng Sân Vận Động</h3>
            <p className="card-sub">
              Doanh thu = Số khán giả &times; Đơn giá vé tương ứng của từng trận đấu đã diễn ra
            </p>
          </div>
        </div>

        {role !== "master" ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">lock</span>
            <p>Báo cáo doanh thu tài chính chỉ có trên ứng dụng Master (phân mảnh dọc).</p>
          </div>
        ) : !rows ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">wifi_off</span>
            <p>Không đọc được dữ liệu doanh thu - kiểm tra kết nối Master hoặc chạy `make setup-fdw`.</p>
          </div>
        ) : rows.length === 0 ? (
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">stadium</span>
            <p>Chưa có trận đấu nào kết thúc để tính tổng doanh thu vé.</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="roster-table">
              <thead>
                <tr>
                  <th style={{ width: "60px" }}>#</th>
                  <th>SÂN VẬN ĐỘNG</th>
                  <th className="number">TRẬN ĐÃ ĐÁ</th>
                  <th className="number">KHÁN GIẢ</th>
                  <th>TỈ TRỌNG DOANH THU</th>
                  <th className="number">TỔNG DOANH THU (₫)</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => {
                  const rev = Number(r.tongtien);
                  const pct = Math.round((rev / maxRev) * 100);
                  const stadiumName = sanMap.get(r.masan) ?? `Sân ${r.masan}`;

                  return (
                    <tr key={r.masan} className="roster-row">
                      <td>
                        <span className={`rank-badge ${i === 0 ? "top-1" : "muted"}`}>
                          {i + 1}
                        </span>
                      </td>
                      <td>
                        <div className="table-team-cell">
                          <span className="stadium-avatar">
                            <span className="material-symbols-outlined">stadium</span>
                          </span>
                          <div>
                            <strong>{stadiumName}</strong>
                            <div className="font-mono text-muted text-xs">Mã: {r.masan}</div>
                          </div>
                        </div>
                      </td>
                      <td className="number font-mono">{r.sotran}</td>
                      <td className="number font-mono">
                        {Number(r.tongkhach).toLocaleString("vi-VN")}
                      </td>
                      <td style={{ minWidth: "160px" }}>
                        <div className="revenue-progress-track">
                          <div className="revenue-progress-fill" style={{ width: `${pct}%` }} />
                        </div>
                      </td>
                      <td className="number font-mono bold emerald">
                        <span className="revenue-pill">{rev.toLocaleString("vi-VN")} ₫</span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Database Architecture Architecture Note */}
      <div className="card criteria-card">
        <div className="criteria-header">
          <span className="material-symbols-outlined text-accent">architecture</span>
          <h4>Nguyên Lý Phân Mảnh Dọc Trong Đề Tài 13</h4>
        </div>
        <p className="text-sm text-slate-300 leading-relaxed">
          Bảng <code>TRAN_DAU_DOANH_THU(MaTran, GiaVe, SoKhach)</code> là mảnh dọc tài chính được lưu độc quyền tại
          Máy chủ Master (VFF). Các trạm Station khách (CLB) chỉ lưu mảnh ngang chuyên môn{" "}
          <code>TRAN_DAU_CHUYEN_MON</code> và <code>SU_KIEN_TRAN_DAU</code>. Master sử dụng <code>postgres_fdw</code>{" "}
          kết hợp phép <code>LEFT JOIN</code> để tái thiết View toàn cục <code>vw_global_tran_dau</code> phục vụ
          tính toán tài chính mà không làm lộ dữ liệu kinh doanh cho các CLB.
        </p>
      </div>
    </div>
  );
}
