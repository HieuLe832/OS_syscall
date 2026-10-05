# Project 0 – System Call: Phân công & câu hỏi còn thắc mắc

> Nguồn duy nhất từ trường: `docs/HCMUS_Lab0_System_Call.pdf` và `docs/HCMUS_Individual_Guide_Setup-lab.pdf`.
> Phần còn lại của repo là source xv6 clone từ MIT. Ta làm trên source này, nhưng **mọi yêu cầu đều theo file PDF của trường**.

## 1. Đề yêu cầu gì

Chỉ có **1 bài: `trace` (10 điểm)**. Cụ thể:

- Thêm system call `trace(int mask)`: process nào gọi nó thì bật trace cho chính process đó, theo các bit trong `mask`.
- Khi một syscall có bit tương ứng trong mask **sắp return**, kernel in ra một dòng gồm tên syscall và giá trị trả về.
- Viết chương trình user `trace`: `trace <mask> <lệnh> [tham số...]`. Chương trình gọi `trace(mask)` trước, sau đó `exec` lệnh cần chạy.

Output mẫu trong đề (phải khớp format này):

```
$ trace 32 grep hello README
syscall read -> 1023
syscall read -> 966
syscall read -> 70
syscall read -> 0
$ trace 2147483647 grep hello README
syscall trace -> 0
syscall exec -> 3
syscall open -> 3
syscall read -> 1023
syscall read -> 966
syscall read -> 70
syscall read -> 0
syscall close -> 0
$ grep hello README
$
```

**Chấm điểm:** demo phỏng vấn về **độ hiểu code** của từng người, nên ai cũng phải giải thích được toàn bộ luồng chạy, không chỉ phần mình làm.

**Đạo văn:** bài giống nhau thì **0 điểm cả phần thực hành**. Nhóm tự gõ code, tự đặt tên biến và tự viết comment. Được dùng AI hoặc tài liệu để hỏi cho hiểu, nhưng không copy nguyên xi.

## 2. Phân công

| Người | Phụ trách | File |
|---|---|---|
| **A** | User space | `user/trace.c`, `user/user.h`, `user/usys.pl`, `Makefile` |
| **B** | Kernel – lưu mask | `kernel/syscall.h`, `kernel/sysproc.c`, `kernel/proc.h`, `kernel/proc.c` |
| **C** | Kernel – in trace, test, nộp bài | `kernel/syscall.c`, report, patch, zip |

### A – User space
- [ ] **Tự viết** `user/trace.c`. Repo clone từ MIT đã có sẵn file này, nhưng đề trường ghi *"Write the user program user/trace.c"*, nên **không dùng file có sẵn**.
  - Kiểm tra tham số: đủ số lượng không, mask có phải là số không.
  - Gọi `trace(mask)`, sau đó `exec(argv[2], &argv[2])`, có xử lý lỗi.
- [ ] Thêm `int trace(int);` vào `user/user.h`.
- [ ] Thêm `entry("trace");` vào `user/usys.pl`.
- [ ] Thêm `$U/_trace\` vào `UPROGS` trong `Makefile`.
- **Khi demo phải giải thích được:** `usys.pl` sinh ra `usys.S`; stub nạp số syscall vào `a7` rồi gọi `ecall`; vì sao mask vẫn còn sau `exec`.

### B – Kernel: lưu mask
- [ ] Định nghĩa `#define SYS_trace 22` trong `kernel/syscall.h`.
- [ ] Thêm field mask vào `struct proc` trong `kernel/proc.h`.
- [ ] Viết `sys_trace()` trong `kernel/sysproc.c`: lấy tham số bằng `argint(0, ...)`, gán vào `myproc()`, trả về 0.
- [ ] Reset mask về 0 khi cấp phát hoặc giải phóng process (`allocproc` / `freeproc` trong `kernel/proc.c`).
- [ ] (Chờ trả lời câu hỏi Q2) Copy mask từ cha sang con trong `fork()`.
- **Khi demo phải giải thích được:** `argint` đọc tham số từ trapframe (`a0`...) như thế nào; vì sao mask phải nằm trong `struct proc` (trace theo từng process); điều gì xảy ra khi `exec`.

### C – Kernel: in trace + test + nộp bài
- [ ] Trong `kernel/syscall.c`: khai báo `extern uint64 sys_trace(void);`, thêm `[SYS_trace] sys_trace` vào bảng `syscalls[]`.
- [ ] Tạo mảng tên syscall, đánh index theo số syscall.
- [ ] Sửa `syscall()`: **sau khi** syscall chạy xong (đã có giá trị ở `p->trapframe->a0`), nếu bit `num` có trong mask thì in `syscall <tên> -> <giá trị>`.
- [ ] Test các mask: `32` (read), `2097152` (close), `32896` (exec + open), `2147483647` (tất cả), và chạy không có trace. Đối chiếu với output mẫu ở mục 1.
- [ ] Nộp bài (theo mục 2 trong đề):
  - `MSSV1_MSSV2_MSSV3_Report.pdf`: ngắn gọn, dàn ý xem mục 3.
  - `MSSV1_MSSV2_MSSV3.patch`: tạo bằng `git diff d5b09ff > MSSV1_MSSV2_MSSV3.patch` (xem mục 4).
  - Source xv6 sau khi `make clean`.
  - Nén tất cả thành `MSSV1_MSSV2_MSSV3.zip` (MSSV xếp tăng dần), nộp trên **Moodle**.
- **Khi demo phải giải thích được:** bảng con trỏ hàm `syscalls[]`; vì sao giá trị trả về nằm ở `a0`; vì sao phải kiểm tra mask **sau** khi gọi syscall.

### Cả nhóm
- [ ] Đọc xv6 book: chương 2, mục 4.3 và 4.4.
- [ ] Đọc `kernel/syscall.c`, `kernel/sysproc.c`, `kernel/proc.h`, `kernel/proc.c`, `user/usys.pl`.
- [ ] Trước buổi demo: mỗi người giải thích lại phần của 2 người còn lại.

## 3. Báo cáo dự kiến (`MSSV1_MSSV2_MSSV3_Report.pdf`)

Đề yêu cầu báo cáo **ngắn gọn** (*"short and sweet"*) và **không chép source code** vào. Mục đích của báo cáo là cho thấy nhóm hiểu bài, nêu các vấn đề gặp phải, các cách đã thử mà không chạy được, và những khái niệm chưa hiểu rõ, để TA có cơ sở cho điểm một phần. Dự kiến khoảng 2–4 trang.

**C** tổng hợp và trình bày báo cáo. Mỗi người viết phần nội dung liên quan đến phần mình làm.

1. **Thông tin nhóm:** MSSV, họ tên, bảng phân công kèm mức đóng góp của từng người. Đề có nói sẽ đánh giá theo hiểu biết và đóng góp của từng cá nhân.
2. **Mức độ hoàn thành:** bảng liệt kê các yêu cầu (syscall `trace`, chương trình `user/trace.c`, output đúng format), mỗi yêu cầu ghi xong / chưa xong / xong một phần.
3. **Cách thực hiện**, mô tả bằng lời hoặc sơ đồ, không dán code:
   - Luồng một system call đi từ user space vào kernel: `trace.c` → stub trong `usys.S` (`a7`, `ecall`) → `syscall()` → `sys_trace()` → lưu mask vào `struct proc`.
   - Cách kernel in trace: kiểm tra bit `num` trong mask sau khi syscall chạy xong, lấy tên từ mảng tên, lấy giá trị trả về ở `a0`.
   - Danh sách file đã sửa, mỗi file một dòng nói sửa gì và vì sao.
4. **Lựa chọn thiết kế và giả định:**
   - Output không in pid, theo đúng đề HCMUS.
   - Cách xử lý process con khi `fork` (theo câu trả lời Q2).
   - Tự viết `user/trace.c` (theo câu trả lời Q1).
   - Các chi tiết khác: kiểu dữ liệu của mask, cách kiểm tra bit, reset mask khi giải phóng process.
5. **Kết quả kiểm thử:** ảnh chụp output của các lệnh `trace 32 ...`, `trace 2147483647 ...`, chạy `grep` không có trace, và các mask khác đã test ở phần việc của C. Đối chiếu với output mẫu trong đề.
6. **Khó khăn và các cách đã thử nhưng không thành công**, nếu có.
7. **Những khái niệm chưa hiểu rõ**, nếu có.
8. **Tài liệu tham khảo:** xv6 book (chương 2, mục 4.3, 4.4), file đề của trường.

## 4. Đã thống nhất

- **Source:** repo hiện tại chính là nhánh `syscall` của repo MIT (đã checkout, đổi tên thành `main`, push lên repo private). Riêng thư mục `docs/` là nhóm tự thêm. Không cần checkout thêm nhánh nào.
- **Format output:** làm theo đề HCMUS, tức là **không in pid**: `syscall <tên> -> <giá trị>`. Format có pid là của MIT, nhóm không theo.
- **File patch:** tạo bằng `git diff` so với commit cuối cùng không phải của nhóm, tức commit gốc của MIT `d5b09ff` ("syscall lab").

## 5. Câu hỏi còn thắc mắc (cần hỏi nhóm / TA)

**Q1. `trace.c` có sẵn trong source MIT: được dùng hay phải tự viết?**
Đề ghi "Write ... user/trace.c". Hiện nhóm đang theo hướng **tự viết** cho an toàn (nếu dùng file có sẵn thì ai clone về cũng giống y hệt).

**Q2. Process con có bị trace theo không?**
Đề ghi *"should enable tracing for the process that calls it, but should not affect other processes"*, nhưng không nói gì đến `fork`. Nếu một lệnh được trace mà tạo process con, thì con có kế thừa mask không?

**Q3. "Giống nhau" được xác định thế nào?**
Bài này ngắn và gần như chỉ có một cách làm chuẩn (mask trong `proc`, kiểm tra bit trong `syscall()`, mảng tên). TA so code hay chủ yếu dựa vào phỏng vấn? Đề **không** yêu cầu đưa ra nhiều cách làm. Report chỉ nhắc đến việc ghi lại "approaches you tried that didn't work" để được điểm một phần.
