# Thiết kế CSDL phân tán giải bóng đá

*Phân tích thực thể, quan hệ và phân bổ master/trạm · cập nhật 21/10/2026*

## 1. Tổng quan

Hệ thống gồm **15 thực thể**, chia theo chủ sở hữu dữ liệu (mỗi bảng chỉ có một nơi được ghi):

- **Master sở hữu (12 bảng)**: Station, Season, Round, Stadium, Team, TeamKit, Player, Referee, RolePay, Registration, Fixture, MatchReferee. Các bảng này được nhân bản xuống cả 6 trạm để mọi khóa ngoại ở trạm đều là khóa ngoại cục bộ.
- **Trạm sở hữu (3 bảng)**: MatchResult, MatchSquad, MatchEvent. Chúng được phân mảnh theo `station_id` của sân nhà và đẩy lên master.

Không có thực thể riêng cho bảng xếp hạng, top 10 vua phá lưới, lương trọng tài, thu nhập sân hay thống kê vòng đấu. Tất cả là view/truy vấn trên MatchResult, MatchEvent và MatchReferee.

&#91;embedded content: ERD · 15 thực thể, 3 bảng của trạm\]

Mũi tên đi từ phía một sang phía nhiều. Ba bảng viền xanh là dữ liệu trận đấu của trạm, mười hai bảng còn lại do master sở hữu.

## 2. Danh sách thực thể

| Thực thể | Chủ sở hữu | Thuộc tính | Ghi chú từ đề |
| --- | --- | --- | --- |
| Station | Master | station\_id (PK), name, region | Thêm cho bài toán phân tán |
| Season | Master | season\_id (PK), name, start\_date, end\_date | Dữ liệu một mùa giải |
| Round | Master | round\_id (PK), season\_id (FK), round\_no, start\_date, end\_date | 8 đội đá 2 lượt = 14 vòng |
| Stadium | Master | stadium\_id (PK), station\_id (FK), name, capacity | Một sân có thể là sân nhà của nhiều đội |
| Team | Master | team\_id (PK), home\_stadium\_id (FK), name, founded\_year | Đúng 1 sân nhà; số đội chẵn, tối thiểu 6 |
| TeamKit | Master | team\_id (PK, FK), color (PK), kind | Từ 2 màu áo trở lên (thuộc tính đa trị) |
| Player | Master | player\_id (PK), full\_name, birth\_date, nationality, position | Thông tin cá nhân, không gắn đội trực tiếp |
| Referee | Master | referee\_id (PK), full\_name, birth\_date, level | Cần ít nhất 16 người để phủ một vòng (4 trận × 4 vai) |
| RolePay | Master | role (PK), pay\_per\_match | Đơn giá 3tr / 2tr / 1tr là dữ liệu, không gõ cứng trong code |
| Registration | Master | reg\_id (PK), player\_id (FK), team\_id (FK), owner\_team\_id (FK), shirt\_no, period | Đội đang đá (team\_id) khác đội giữ hợp đồng (owner\_team\_id) nghĩa là đang cho mượn |
| Fixture | Master | fixture\_id (PK), round\_id (FK), home\_team (FK), away\_team (FK), stadium\_id (FK), kickoff | Lịch thi đấu đầy đủ của mùa giải |
| MatchReferee | Master | fixture\_id (PK, FK), referee\_id (PK, FK), role (FK) | Đúng 4 người: 1 chính, 2 biên, 1 bàn |
| MatchResult | Trạm | station\_id (PK), fixture\_id (PK, FK), played\_at, home\_goals, away\_goals, attendance, ticket\_price | Chỉ tồn tại khi trận đã diễn ra |
| MatchSquad | Trạm | station\_id (PK), fixture\_id (PK, FK), player\_id (PK, FK), team\_id (FK) | Tối đa 18 người mỗi đội mỗi trận |
| MatchEvent | Trạm | station\_id (PK), event\_id (PK), fixture\_id (FK), player\_id (FK), kind (goal/yellow/red), minute | Tổng khớp tỉ số và số thẻ của đội |

## 3. Quan hệ và bản số

| Quan hệ | Bản số | Ý nghĩa |
| --- | --- | --- |
| Season – Round | 1 – N | Một mùa giải có nhiều vòng đấu |
| Station – Stadium | 1 – N | Một trạm quản lý nhiều sân |
| Stadium – Team | 1 – N | Một sân là sân nhà của một hoặc nhiều đội |
| Team – TeamKit | 1 – N (tối thiểu 2) | Mỗi đội có từ 2 màu áo trở lên |
| Player – Registration | 1 – N | Cầu thủ có nhiều đăng ký theo thời gian |
| Team – Registration (team\_id) | 1 – N | Đội mà cầu thủ đang thi đấu |
| Team – Registration (owner\_team\_id) | 1 – N | Đội giữ hợp đồng của cầu thủ |
| Round – Fixture | 1 – N | Mỗi vòng gồm các cặp đấu |
| Team – Fixture (home\_team) | 1 – N | Đội chủ nhà |
| Team – Fixture (away\_team) | 1 – N | Đội khách |
| Stadium – Fixture | 1 – N | Sân diễn ra trận đấu |
| Fixture – MatchResult | 1 – 0..1 | Kết quả chỉ có khi trận đã diễn ra |
| Fixture – MatchReferee | 1 – N (đúng 4) | Phân công trọng tài |
| Referee – MatchReferee | 1 – N | Trọng tài điều khiển nhiều trận (tối đa 1 trận mỗi vòng) |
| RolePay – MatchReferee | 1 – N | Vai trò quyết định đơn giá |
| MatchResult – MatchSquad | 1 – N | Danh sách đăng ký thi đấu của trận |
| Player – MatchSquad | 1 – N | Cầu thủ được đăng ký ở nhiều trận |
| MatchResult – MatchEvent | 1 – N | Bàn thắng và thẻ phạt trong trận |
| Player – MatchEvent | 1 – N | Cầu thủ ghi bàn hoặc bị thẻ |

## 4. Quyết định thiết kế

- **Gộp hợp đồng và cho mượn vào Registration.** Nhờ đó "mỗi cầu thủ chỉ đá cho một đội tại một thời điểm" thành một ràng buộc loại trừ duy nhất trên `(player_id, period)`. Cầu thủ mượn xuất hiện trong danh sách đăng ký của trận ở trạm khác mà không cần đọc chéo giữa các trạm, vì Registration và Player có bản sao ở mọi trạm.
- **Lịch thi đấu và phân công trọng tài do master sở hữu.** Việc mỗi cặp đá đúng 2 lượt, mỗi đội đá 1 trận mỗi vòng và trọng tài tối đa 1 trận mỗi vòng được kiểm tra ở một nơi duy nhất, nên không còn ràng buộc xuyên trạm cho phần lịch.
- **Khóa ghép `(station_id, ...)` ở ba bảng của trạm.** Sáu trạm dùng chung cấu trúc bảng mà khi gộp lên master không trùng khóa. Ba bảng nối với nhau bằng khóa ngoại ghép `(station_id, fixture_id)`, nên mọi dòng của một trận luôn nằm cùng một trạm.
- **MatchResult chỉ tồn tại khi trận đã diễn ra.** Trận chưa đá chỉ có dòng trong Fixture. Giá vé và số khán giả là thuộc tính của MatchResult; chỉ tách thành thực thể riêng nếu muốn có nhiều hạng vé.
- **Fixture chỉ giữ `stadium_id`.** Trạm của trận suy ra từ `Stadium.station_id`; khi viết DDL sẽ thêm cột sinh hoặc trigger để khớp.

## 5. Ràng buộc gắn với từng thực thể

| Thực thể | Ràng buộc |
| --- | --- |
| Registration | Số áo từ 1 đến 35; số áo không trùng trong đội tại cùng thời điểm; cầu thủ chỉ ở một đội tại một thời điểm; mỗi đội tối đa 30 cầu thủ |
| Team | Mỗi đội đúng 1 sân nhà; tổng số đội là số chẵn, tối thiểu 6 (dự kiến 8) |
| TeamKit | Mỗi đội có ít nhất 2 màu áo |
| Fixture | Mỗi cặp đúng 2 lượt (nhà và khách); mỗi đội đá đúng 1 trận mỗi vòng; đội nhà khác đội khách |
| MatchReferee | Đúng 4 trọng tài mỗi trận theo vai 1 chính, 2 biên, 1 bàn; mỗi trọng tài tối đa 1 trận mỗi vòng |
| MatchResult | Ngày diễn ra không vượt quá hiện tại; tổng bàn thắng và thẻ của cầu thủ khớp tỉ số và số thẻ của đội |
| MatchSquad | Tối đa 18 người mỗi đội mỗi trận; cầu thủ phải đang đăng ký cho đội đó vào ngày đá |
| MatchEvent | Cầu thủ phải nằm trong danh sách đăng ký của trận |

## 6. Phân bổ phân tán

| Nhóm dữ liệu | Bảng | Hướng nhân bản |
| --- | --- | --- |
| Master sở hữu | Station, Season, Round, Stadium, Team, TeamKit, Player, Referee, RolePay, Registration, Fixture, MatchReferee | Master xuống toàn bộ 6 trạm (schema `ref`) |
| Trạm sở hữu | MatchResult, MatchSquad, MatchEvent | Từng trạm lên master (phân mảnh theo `station_id`) |
| Tính toán trên master | Bảng xếp hạng, top 10, lương trọng tài, thu nhập sân, thống kê vòng | View trên các bảng đã nhân bản lên master |

Ứng dụng ở trạm ghi dữ liệu của master (CRUD cầu thủ, đội, trọng tài) qua một kết nối thứ hai tới master; ở trạm chỉ có bản sao chỉ đọc.
