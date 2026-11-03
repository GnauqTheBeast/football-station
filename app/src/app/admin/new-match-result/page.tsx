// src/app/admin/new-match-result/page.tsx - Nhập liệu kết quả trạm Station
import Link from "next/link";
import { getRole, querySafe, getStationId } from "@/lib/db";
import { getStationInfo, STATIONS } from "@/lib/station";
import { TeamBadge, getClubMeta } from "@/components/TeamBadge";
import type { GlobalMatch, GlobalEvent } from "@/lib/types";
import { createMatch, addEvent, deleteEvent, finalizeMatch } from "./actions";

export const dynamic = "force-dynamic";

const LOAI_LABEL: Record<string, { label: string; icon: string; color: string }> = {
  BanThang: { label: "Bàn thắng", icon: "⚽", color: "#10b981" },
  PhanLuoi: { label: "Phản lưới", icon: "🥅", color: "#3b82f6" },
  TheVang: { label: "Thẻ vàng", icon: "🟨", color: "#f59e0b" },
  TheDo: { label: "Thẻ đỏ", icon: "🟥", color: "#ef4444" },
};

export default async function NewMatchResultPage({
  searchParams,
}: {
  searchParams?: { m?: string; err?: string; ok?: string };
}) {
  const role = getRole();
  if (role !== "station") {
    return (
      <div className="page-container">
        <div className="topbar">
          <div>
            <h1>Nhập Liệu Kết Quả Trận Đấu</h1>
          </div>
        </div>
        <div className="card">
          <div className="empty-state">
            <span className="material-symbols-outlined empty-icon">lock</span>
            <h3>Trang này chỉ dành cho ứng dụng Station</h3>
            <p>Máy chủ Master chỉ đọc dữ liệu tổng hợp qua FDW, không ghi nhận tỉ số trực tiếp.</p>
            <Link className="btn secondary" href="/" style={{ marginTop: "1rem" }}>
              Về Trang Chủ Master
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const meta = STATIONS.find((s) => s.id === getStationId());
  if (!meta) {
    return (
      <div className="page-container">
        <div className="alert error">
          STATION_ID chưa hợp lệ trong biến môi trường (.env.station). Vui lòng cấu hình ID: 1, 2, 4, 5, 6.
        </div>
      </div>
    );
  }

  const info = await getStationInfo();
  const stationClub = getClubMeta(meta.club);

  const matches = (await querySafe<GlobalMatch>(
    `SELECT matran, mavong, madoinha, madoikhach, masan, ngaygio,
            NULL::text AS giave, NULL::int AS sokhach,
            banthangnha, banthangkhach, thevangnha, thevangkhach,
            thedonha, thedokhach, trangthai
     FROM tran_dau_chuyen_mon ORDER BY mavong, matran`
  )) ?? [];

  const selectedMatchId =
    searchParams?.m?.toUpperCase() ??
    matches.find((m) => m.trangthai !== "DaKetThuc")?.matran ??
    matches[0]?.matran;

  const currentMatch = matches.find((m) => m.matran === selectedMatchId);

  const events = currentMatch
    ? (await querySafe<GlobalEvent>(
        `SELECT masukien, matran, macauthu, loaisukien, phutghinhan
         FROM su_kien_tran_dau WHERE matran = $1 ORDER BY phutghinhan ASC`,
        [currentMatch.matran]
      )) ?? []
    : [];

  const isLocked = currentMatch?.trangthai === "DaKetThuc";
  const openCount = matches.filter((m) => m.trangthai !== "DaKetThuc").length;

  return (
    <div className="page-container">
      {/* Top Header */}
      <div className="topbar">
        <div>
          <div className="breadcrumb">
            <span>Trạm Cục Bộ</span>
            <span className="material-symbols-outlined">chevron_right</span>
            <span className="accent">{info.station_name}</span>
          </div>
          <h1>Biên Bản Trực Tuyến &amp; Nhập Liệu Trận Đấu</h1>
          <div className="sub">
            Đội nhà cố định: <strong>{meta.club}</strong> ({stationClub.name}) • Sân {meta.san} • {openCount} trận đang mở
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

      {/* 2-Column Work Flow */}
      <div className="grid grid-2">
        {/* CỘT TRÁI: BƯỚC 1 - TẠO LỊCH & CHỌN TRẬN ĐẤU */}
        <div className="space-y-4">
          {/* STEP 1: CREATE FIXTURE */}
          <div className="card">
            <div className="card-header-row">
              <div className="step-title">
                <span className="step-badge">1</span>
                <div>
                  <h3>Tạo Lịch Trận Đấu Mới</h3>
                  <p className="card-sub">Trạng thái mặc định: ChuaDienRa</p>
                </div>
              </div>
            </div>

            <form action={createMatch}>
              <div className="form-grid-2">
                <div className="form-row">
                  <label>Mã trận (≤10 ký tự)</label>
                  <input name="matran" required maxLength={10} placeholder="VD: TR31, M10_01" className="font-mono" />
                </div>
                <div className="form-row">
                  <label>Vòng đấu (1-26)</label>
                  <input name="mavong" type="number" min={1} max={26} required defaultValue={10} />
                </div>
              </div>

              <div className="form-row">
                <label>Đội khách (Đối thủ của {meta.club})</label>
                <input name="madoikhach" required maxLength={10} placeholder="VD: HAGL, CAHN, HPFC..." />
              </div>

              <div className="form-row">
                <label>Ngày giờ thi đấu (Quy định: cùng sân cách &ge; 4h)</label>
                <input name="ngaygio" type="datetime-local" required />
              </div>

              <button className="btn" type="submit">
                <span className="material-symbols-outlined">add_circle</span>
                Tạo Trận Đấu Mới
              </button>
            </form>
          </div>

          {/* FIXTURES SELECTOR LIST */}
          <div className="card">
            <div className="card-header-row">
              <h3>
                Danh Sách Trận Của Trạm
                <span className="count-pill">{matches.length} trận</span>
              </h3>
            </div>

            {matches.length === 0 ? (
              <p className="empty-state">Chưa có trận nào trong CSDL của trạm.</p>
            ) : (
              <div className="scroll" style={{ maxHeight: "360px" }}>
                <div className="match-rows-list">
                  {matches.map((m) => {
                    const isSelected = m.matran === currentMatch?.matran;
                    const finished = m.trangthai === "DaKetThuc";
                    return (
                      <Link
                        key={m.matran}
                        href={`/admin/new-match-result?m=${m.matran}`}
                        className={`mrow-card ${isSelected ? "selected" : ""}`}
                        style={isSelected ? { borderColor: "var(--accent)" } : undefined}
                      >
                        <div className="mrow-left">
                          <span className="font-mono bold">#{m.matran}</span>
                          <span className="text-muted text-xs">V{m.mavong}</span>
                        </div>

                        <div className="mrow-versus">
                          <TeamBadge code={m.madoinha} size={22} />
                          <span className="score-text">
                            {m.banthangnha} - {m.banthangkhach}
                          </span>
                          <TeamBadge code={m.madoikhach} size={22} />
                        </div>

                        <div className="mrow-right">
                          <span className={`status-dot-tag ${finished ? "done" : "todo"}`}>
                            {finished ? "ĐÃ CHỐT" : "ĐANG MỞ"}
                          </span>
                        </div>
                      </Link>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* CỘT PHẢI: BƯỚC 2 - NHẬP SỰ KIỆN & BƯỚC 3 - CHỐT KẾT QUẢ */}
        <div className="space-y-4">
          {!currentMatch ? (
            <div className="card">
              <div className="empty-state">
                <span className="material-symbols-outlined empty-icon">touch_app</span>
                <p>Vui lòng chọn 1 trận đấu bên trái để bắt đầu nhập sự kiện.</p>
              </div>
            </div>
          ) : (
            <>
              {/* STEP 2: LOG REAL-TIME EVENTS */}
              <div className="card">
                <div className="card-header-row">
                  <div className="step-title">
                    <span className="step-badge">2</span>
                    <div>
                      <h3>
                        Ghi Nhận Sự Kiện #{currentMatch.matran}
                      </h3>
                      <p className="card-sub">
                        {isLocked
                          ? "Trận đấu đã kết thúc (khóa sổ CSDL)"
                          : `Đang mở ghi nhận • ${events.length} sự kiện đã lưu`}
                      </p>
                    </div>
                  </div>
                  <div className="match-pill-header">
                    <TeamBadge code={currentMatch.madoinha} size={24} />
                    <strong>{currentMatch.madoinha}</strong> vs <strong>{currentMatch.madoikhach}</strong>
                    <TeamBadge code={currentMatch.madoikhach} size={24} />
                  </div>
                </div>

                {isLocked ? (
                  <div className="alert-box locked">
                    <span className="material-symbols-outlined">lock</span>
                    <span>Trận đã kết thúc - CSDL từ chối thêm/xóa sự kiện để bảo toàn dữ liệu.</span>
                  </div>
                ) : (
                  <form action={addEvent} className="event-input-form">
                    <input type="hidden" name="matran" value={currentMatch.matran} />
                    <div className="form-grid-2">
                      <div className="form-row">
                        <label>Mã cầu thủ (CT001 - CT120)</label>
                        <input name="macauthu" required maxLength={10} placeholder="VD: CT007, CT008..." className="font-mono" />
                      </div>
                      <div className="form-row">
                        <label>Phút diễn biến (1 - 120)</label>
                        <input name="phut" type="number" min={1} max={120} required defaultValue={45} />
                      </div>
                    </div>

                    <div className="form-row">
                      <label>Loại sự kiện thi đấu</label>
                      <select name="loai" defaultValue="BanThang">
                        <option value="BanThang">⚽ Bàn thắng (BanThang)</option>
                        <option value="PhanLuoi">🥅 Phản lưới nhà (PhanLuoi)</option>
                        <option value="TheVang">🟨 Thẻ vàng (TheVang)</option>
                        <option value="TheDo">🟥 Thẻ đỏ trực tiếp/gián tiếp (TheDo)</option>
                      </select>
                    </div>

                    <button className="btn" type="submit">
                      <span className="material-symbols-outlined">sports_soccer</span>
                      Ghi Nhận Sự Kiện
                    </button>
                  </form>
                )}

                {/* Event list */}
                <div className="events-timeline" style={{ marginTop: "1rem" }}>
                  {events.length === 0 ? (
                    <p className="text-muted text-sm italic">Chưa có sự kiện nào cho trận này.</p>
                  ) : (
                    events.map((e) => {
                      const loai = LOAI_LABEL[e.loaisukien] ?? { label: e.loaisukien, icon: "•", color: "#94a3b8" };
                      return (
                        <div key={e.masukien} className="timeline-item compact">
                          <span className="min-badge font-mono">{e.phutghinhan}&prime;</span>
                          <span className="event-icon">{loai.icon}</span>
                          <div className="event-detail">
                            <strong>{e.macauthu}</strong>
                            <span className="event-type-name">({loai.label})</span>
                          </div>
                          {!isLocked && (
                            <form action={deleteEvent}>
                              <input type="hidden" name="masukien" value={e.masukien} />
                              <button className="btn-delete-event" type="submit" title="Xóa sự kiện này">
                                &times;
                              </button>
                            </form>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
              </div>

              {/* STEP 3: FINALIZE MATCH (CHỐT KẾT QUẢ ĐÃ KẾT THÚC) */}
              {!isLocked && (
                <div className="card">
                  <div className="card-header-row">
                    <div className="step-title">
                      <span className="step-badge">3</span>
                      <div>
                        <h3>Chốt Kết Quả &amp; Khóa Sổ Trận Đấu</h3>
                        <p className="card-sub">
                          Ràng buộc CSDL: Tỉ số bàn thắng &amp; thẻ phạt phải khớp 100% với sự kiện
                        </p>
                      </div>
                    </div>
                  </div>

                  <form action={finalizeMatch}>
                    <input type="hidden" name="matran" value={currentMatch.matran} />
                    <div className="form-grid-2">
                      <div className="form-row">
                        <label>Bàn thắng {currentMatch.madoinha} (Chủ)</label>
                        <input name="banthangnha" type="number" min={0} required defaultValue={currentMatch.banthangnha} />
                      </div>
                      <div className="form-row">
                        <label>Bàn thắng {currentMatch.madoikhach} (Khách)</label>
                        <input name="banthangkhach" type="number" min={0} required defaultValue={currentMatch.banthangkhach} />
                      </div>
                      <div className="form-row">
                        <label>Thẻ vàng {currentMatch.madoinha}</label>
                        <input name="thevangnha" type="number" min={0} required defaultValue={currentMatch.thevangnha} />
                      </div>
                      <div className="form-row">
                        <label>Thẻ vàng {currentMatch.madoikhach}</label>
                        <input name="thevangkhach" type="number" min={0} required defaultValue={currentMatch.thevangkhach} />
                      </div>
                      <div className="form-row">
                        <label>Thẻ đỏ {currentMatch.madoinha}</label>
                        <input name="thedonha" type="number" min={0} required defaultValue={currentMatch.thedonha} />
                      </div>
                      <div className="form-row">
                        <label>Thẻ đỏ {currentMatch.madoikhach}</label>
                        <input name="thedokhach" type="number" min={0} required defaultValue={currentMatch.thedokhach} />
                      </div>
                    </div>

                    <button className="btn btn-finalize" type="submit">
                      <span className="material-symbols-outlined">lock</span>
                      Chốt Kết Quả Trận Đấu (DaKetThuc)
                    </button>
                    <p className="help-text">
                      * Trigger CSDL sẽ kiểm tra: Nếu tổng số bàn/thẻ không khớp danh sách sự kiện ở Bước 2, thao tác sẽ bị từ chối.
                    </p>
                  </form>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
